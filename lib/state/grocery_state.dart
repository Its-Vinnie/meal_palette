import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:meal_palette/model/grocery_item_model.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/service/grocery_service.dart';
import 'package:meal_palette/service/recipe_cache_service.dart';

/// State management for user's grocery list and generated recipes
class GroceryState extends ChangeNotifier {
  //* Singleton pattern
  static final GroceryState _instance = GroceryState._internal();
  factory GroceryState() => _instance;
  GroceryState._internal();

  //* Services
  final GroceryService _groceryService = groceryService;
  final RecipeCacheService _recipeCacheService = RecipeCacheService();

  //* State variables
  List<GroceryItem> _groceries = [];
  List<Recipe> _generatedRecipes = [];
  bool _isLoadingGroceries = false;
  bool _isLoadingRecipes = false;
  String? _errorMessage;
  StreamSubscription<List<GroceryItem>>? _grocerySubscription;

  //* Getters
  List<GroceryItem> get groceries => _groceries;
  List<Recipe> get generatedRecipes => _generatedRecipes;
  bool get isLoadingGroceries => _isLoadingGroceries;
  bool get isLoadingRecipes => _isLoadingRecipes;
  String? get errorMessage => _errorMessage;
  bool get hasGroceries => _groceries.isNotEmpty;
  int get groceryCount => _groceries.length;

  /// Get groceries grouped by category
  Map<String, List<GroceryItem>> get groceriesByCategory {
    final Map<String, List<GroceryItem>> categorized = {};

    for (var item in _groceries) {
      final category = item.category ?? GroceryCategories.other;
      if (!categorized.containsKey(category)) {
        categorized[category] = [];
      }
      categorized[category]!.add(item);
    }

    return categorized;
  }

  /// Get list of ingredient names for API calls
  List<String> get ingredientNames {
    return _groceries.map((item) => item.name).toList();
  }

  // ============================================================================
  // LOAD GROCERIES
  // ============================================================================

  /// Load groceries for a user (one-time fetch)
  Future<void> loadGroceries(String userId) async {
    _isLoadingGroceries = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _groceries = await _groceryService.getUserGroceries(userId);
      _isLoadingGroceries = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load groceries';
      _isLoadingGroceries = false;
      notifyListeners();
      print('❌ Error loading groceries: $e');
    }
  }

  /// Start listening to real-time grocery updates
  void startListening(String userId) {
    _grocerySubscription?.cancel();
    _grocerySubscription = _groceryService.groceryStream(userId).listen(
      (groceries) {
        _groceries = groceries;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Failed to sync groceries';
        notifyListeners();
        print('❌ Grocery stream error: $error');
      },
    );
  }

  /// Stop listening to grocery updates
  void stopListening() {
    _grocerySubscription?.cancel();
    _grocerySubscription = null;
  }

  // ============================================================================
  // GROCERY CRUD OPERATIONS
  // ============================================================================

  /// Add a new grocery item
  Future<bool> addGrocery(String userId, GroceryItem item) async {
    try {
      await _groceryService.addGroceryItem(userId, item);

      // If not using real-time listener, manually reload
      if (_grocerySubscription == null) {
        await loadGroceries(userId);
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to add grocery item';
      notifyListeners();
      print('❌ Error adding grocery: $e');
      return false;
    }
  }

  /// Remove a grocery item
  Future<bool> removeGrocery(String userId, String itemId) async {
    try {
      await _groceryService.removeGroceryItem(userId, itemId);

      // If not using real-time listener, manually reload
      if (_grocerySubscription == null) {
        await loadGroceries(userId);
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to remove grocery item';
      notifyListeners();
      print('❌ Error removing grocery: $e');
      return false;
    }
  }

  /// Update an existing grocery item
  Future<bool> updateGrocery(String userId, GroceryItem item) async {
    try {
      await _groceryService.updateGroceryItem(userId, item);

      // If not using real-time listener, manually reload
      if (_grocerySubscription == null) {
        await loadGroceries(userId);
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to update grocery item';
      notifyListeners();
      print('❌ Error updating grocery: $e');
      return false;
    }
  }

  /// Clear all groceries
  Future<bool> clearAllGroceries(String userId) async {
    try {
      await _groceryService.clearAllGroceries(userId);

      // Clear local state
      _groceries = [];
      _generatedRecipes = [];
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Failed to clear groceries';
      notifyListeners();
      print('❌ Error clearing groceries: $e');
      return false;
    }
  }

  /// Toggle pin status of a grocery item
  Future<bool> togglePin(String userId, String itemId) async {
    try {
      final item = _groceries.firstWhere((g) => g.id == itemId);
      await _groceryService.togglePinGrocery(userId, itemId, !item.isPinned);

      // If not using real-time listener, manually update local state
      if (_grocerySubscription == null) {
        final index = _groceries.indexWhere((g) => g.id == itemId);
        if (index != -1) {
          _groceries[index] = item.copyWith(isPinned: !item.isPinned);
          notifyListeners();
        }
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to pin grocery item';
      notifyListeners();
      print('❌ Error toggling pin: $e');
      return false;
    }
  }

  // ============================================================================
  // RECIPE GENERATION
  // ============================================================================

  /// Generate recipes from current groceries
  Future<void> generateRecipes({int number = 10}) async {
    if (_groceries.isEmpty) {
      _generatedRecipes = [];
      notifyListeners();
      return;
    }

    _isLoadingRecipes = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ingredients = ingredientNames;
      _generatedRecipes = await _groceryService.getRecipesFromGroceries(
        ingredients,
        number: number,
      );

      // Cache the generated recipes to Firestore for offline access
      if (_generatedRecipes.isNotEmpty) {
        _recipeCacheService.cacheRecipes(_generatedRecipes);
        print('✅ Cached ${_generatedRecipes.length} grocery-based recipes');
      }

      _isLoadingRecipes = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to generate recipes';
      _isLoadingRecipes = false;
      notifyListeners();
      print('❌ Error generating recipes: $e');
    }
  }

  /// Clear generated recipes
  void clearGeneratedRecipes() {
    _generatedRecipes = [];
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _grocerySubscription?.cancel();
    super.dispose();
  }
}

/// Global singleton instance
final groceryState = GroceryState();
