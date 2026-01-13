import 'package:flutter/foundation.dart';
import 'package:meal_palette/model/custom_recipe_model.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/service/custom_recipe_service.dart';
import 'dart:async';

/// State management for custom recipes using ChangeNotifier pattern
class CustomRecipesState extends ChangeNotifier {
  static final CustomRecipesState _instance = CustomRecipesState._internal();

  factory CustomRecipesState() {
    return _instance;
  }

  CustomRecipesState._internal() {
    _initAuthListener();
  }

  final CustomRecipeService _recipeService = customRecipeService;
  final AuthService _authService = authService;

  List<CustomRecipe> _recipes = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<CustomRecipe>>? _recipeStreamSubscription;

  // ============================================================================
  // GETTERS
  // ============================================================================

  List<CustomRecipe> get recipes => List.unmodifiable(_recipes);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get recipeCount => _recipes.length;
  bool get hasRecipes => _recipes.isNotEmpty;

  /// Get recipes by category
  List<CustomRecipe> getRecipesByCategory(String category) {
    return _recipes.where((recipe) => recipe.category == category).toList();
  }

  /// Search recipes by title or description
  List<CustomRecipe> searchRecipes(String query) {
    final lowerQuery = query.toLowerCase();
    return _recipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowerQuery) ||
          (recipe.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Get recipes grouped by category
  Map<String, List<CustomRecipe>> get recipesByCategory {
    final Map<String, List<CustomRecipe>> grouped = {};
    for (var recipe in _recipes) {
      final category = recipe.category ?? 'other';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(recipe);
    }
    return grouped;
  }

  // ============================================================================
  // AUTH LISTENER
  // ============================================================================

  void _initAuthListener() {
    _authService.authStateChanges.listen((user) {
      if (user != null) {
        loadRecipes(user.uid);
      } else {
        _clearState();
      }
    });
  }

  void _clearState() {
    _recipes = [];
    _error = null;
    _isLoading = false;
    _recipeStreamSubscription?.cancel();
    _recipeStreamSubscription = null;
    notifyListeners();
  }

  // ============================================================================
  // LOAD RECIPES
  // ============================================================================

  /// Load user's custom recipes (one-time fetch)
  Future<void> loadRecipes(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final recipes = await _recipeService.getUserRecipes(userId);

      _recipes = recipes;
      _isLoading = false;
      notifyListeners();

      print('✅ Loaded ${_recipes.length} custom recipes');
    } catch (e) {
      _error = 'Failed to load recipes: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Error loading recipes: $e');
    }
  }

  /// Start real-time listening to recipe changes
  void startRealtimeUpdates(String userId) {
    _recipeStreamSubscription?.cancel();

    _recipeStreamSubscription = _recipeService.userRecipesStream(userId).listen(
      (recipes) {
        _recipes = recipes;
        _error = null;
        notifyListeners();
        print('✅ Real-time update: ${_recipes.length} recipes');
      },
      onError: (error) {
        _error = 'Real-time update error: $error';
        notifyListeners();
        print('❌ Stream error: $error');
      },
    );
  }

  /// Stop real-time listening
  void stopRealtimeUpdates() {
    _recipeStreamSubscription?.cancel();
    _recipeStreamSubscription = null;
  }

  // ============================================================================
  // CREATE RECIPE
  // ============================================================================

  Future<String?> createRecipe(String userId, CustomRecipe recipe) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final recipeId = await _recipeService.createRecipe(userId, recipe);

      // Optimistic UI update
      _recipes.insert(0, recipe.copyWith(id: recipeId));
      _isLoading = false;
      notifyListeners();

      print('✅ Created recipe: ${recipe.title}');
      return recipeId;
    } catch (e) {
      _error = 'Failed to create recipe: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Error creating recipe: $e');
      return null;
    }
  }

  // ============================================================================
  // UPDATE RECIPE
  // ============================================================================

  Future<bool> updateRecipe(String userId, CustomRecipe recipe) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _recipeService.updateRecipe(userId, recipe);

      // Update local state
      final index = _recipes.indexWhere((r) => r.id == recipe.id);
      if (index != -1) {
        _recipes[index] = recipe;
      }

      _isLoading = false;
      notifyListeners();

      print('✅ Updated recipe: ${recipe.title}');
      return true;
    } catch (e) {
      _error = 'Failed to update recipe: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Error updating recipe: $e');
      return false;
    }
  }

  // ============================================================================
  // DELETE RECIPE
  // ============================================================================

  Future<bool> deleteRecipe(String userId, String recipeId) async {
    try {
      _isLoading = true;
      _error = null;

      // Find recipe to delete
      final recipeToDelete = _recipes.firstWhere(
        (r) => r.id == recipeId,
        orElse: () => throw Exception('Recipe not found'),
      );

      // Optimistic UI update
      _recipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();

      // Delete from Firestore
      await _recipeService.deleteRecipe(userId, recipeId);

      // Delete image if exists
      if (recipeToDelete.imageUrl != null && recipeToDelete.imageUrl!.isNotEmpty) {
        try {
          await _recipeService.deleteRecipeImage(recipeToDelete.imageUrl!);
        } catch (e) {
          print('⚠️ Failed to delete recipe image: $e');
        }
      }

      _isLoading = false;
      notifyListeners();

      print('✅ Deleted recipe: $recipeId');
      return true;
    } catch (e) {
      _error = 'Failed to delete recipe: $e';
      _isLoading = false;

      // Reload to ensure state is correct
      if (_authService.currentUser != null) {
        await loadRecipes(_authService.currentUser!.uid);
      }

      print('❌ Error deleting recipe: $e');
      return false;
    }
  }

  // ============================================================================
  // IMAGE UPLOAD
  // ============================================================================

  Future<String?> uploadRecipeImage(String userId, dynamic imageFile) async {
    try {
      final imageUrl = await _recipeService.uploadRecipeImage(userId, imageFile);
      print('✅ Uploaded recipe image: $imageUrl');
      return imageUrl;
    } catch (e) {
      _error = 'Failed to upload image: $e';
      notifyListeners();
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get count of recipes by category
  Map<String, int> get recipeCategoryCounts {
    final Map<String, int> counts = {};
    for (var recipe in _recipes) {
      final category = recipe.category ?? 'other';
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  /// Get most recent recipes
  List<CustomRecipe> getRecentRecipes({int limit = 5}) {
    final sorted = List<CustomRecipe>.from(_recipes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============================================================================
  // DISPOSAL
  // ============================================================================

  @override
  void dispose() {
    _recipeStreamSubscription?.cancel();
    super.dispose();
  }
}

/// Global singleton instance
final customRecipesState = CustomRecipesState();
