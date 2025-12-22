import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';

/// State management for favorites using ChangeNotifier
/// This allows widgets to reactively update when favorites change
/// Now uses real Firebase Auth user ID
class FavoritesState extends ChangeNotifier {
  //* Singleton pattern - ensures only one instance exists
  static final FavoritesState _instance = FavoritesState._internal();
  factory FavoritesState() => _instance;
  FavoritesState._internal() {
    //* Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUserId = user.uid;
        // Schedule favorites loading for next frame to avoid setState during build
        Future.microtask(() => loadFavorites());
      } else {
        _currentUserId = null;
        clearFavorites(); // Clear favorites when logged out
      }
    });
  }

  //* Firestore service for database operations
  final FirestoreService _firestoreService = FirestoreService();

  //* Set to store favorite recipe IDs for quick lookup
  final Set<int> _favoriteIds = {};

  //* List to store full favorite recipes
  final List<Recipe> _favoriteRecipes = [];

  //* Loading state
  bool _isLoading = false;

  //* Current user ID from Firebase Auth
  String? _currentUserId;

  // ============================================================================
  // GETTERS
  // ============================================================================

  /// Returns unmodifiable set of favorite IDs
  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);

  /// Returns unmodifiable list of favorite recipes
  List<Recipe> get favoriteRecipes => List.unmodifiable(_favoriteRecipes);

  /// Returns loading state
  bool get isLoading => _isLoading;

  /// Returns current user ID
  String get currentUserId => _currentUserId ?? '';

  /// Checks if a recipe is favorited
  bool isFavorite(int recipeId) => _favoriteIds.contains(recipeId);

  /// Returns count of favorites
  int get favoriteCount => _favoriteIds.length;

  // ============================================================================
  // METHODS
  // ============================================================================

  /// Loads all favorites from Firestore for current user
  Future<void> loadFavorites() async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in, cannot load favorites');
      return;
    }

    // Set loading state without notifying during potential build phase
    _isLoading = true;
    
    try {
      //* Fetch favorites from Firestore
      final favorites =
          await _firestoreService.getFavoriteRecipes(_currentUserId!);

      //* Clear existing data
      _favoriteRecipes.clear();
      _favoriteIds.clear();

      //* Populate with new data
      _favoriteRecipes.addAll(favorites);
      _favoriteIds.addAll(favorites.map((r) => r.id));

      print("✅ Loaded ${_favoriteRecipes.length} favorites for user: $_currentUserId");
    } catch (e) {
      print("❌ Error loading favorites: $e");
    } finally {
      _isLoading = false;
      // Only notify listeners after async operations complete
      notifyListeners();
    }
  }

  /// Toggles favorite status of a recipe
  /// Returns true if added, false if removed
  Future<bool> toggleFavorite(Recipe recipe) async {
    if (_favoriteIds.contains(recipe.id)) {
      return await removeFavorite(recipe.id);
    } else {
      return await addFavorite(recipe);
    }
  }

  /// Adds a recipe to favorites
  Future<bool> addFavorite(Recipe recipe) async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in, cannot add favorite');
      return false;
    }

    try {
      //* Optimistically update UI
      _favoriteIds.add(recipe.id);
      _favoriteRecipes.insert(0, recipe); // Add to beginning
      notifyListeners();

      //* Save to Firestore
      await _firestoreService.addToFavorites(_currentUserId!, recipe);

      print("❤️ Added to favorites: ${recipe.title}");
      return true;
    } catch (e) {
      //* Revert on error
      _favoriteIds.remove(recipe.id);
      _favoriteRecipes.removeWhere((r) => r.id == recipe.id);
      notifyListeners();

      print("❌ Error adding favorite: $e");
      return false;
    }
  }

  /// Removes a recipe from favorites
  Future<bool> removeFavorite(int recipeId) async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in, cannot remove favorite');
      return true;
    }

    try {
      //* Store recipe for potential revert
      final removedRecipe =
          _favoriteRecipes.firstWhere((r) => r.id == recipeId);

      //* Optimistically update UI
      _favoriteIds.remove(recipeId);
      _favoriteRecipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();

      //* Remove from Firestore
      await _firestoreService.removeFromFavorites(_currentUserId!, recipeId);

      print("💔 Removed from favorites: $recipeId");
      return false;
    } catch (e) {
      //* Revert on error (if we have the recipe)
      loadFavorites(); // Reload to ensure consistency
      print("❌ Error removing favorite: $e");
      return true;
    }
  }

  /// Checks if recipe is favorite from Firestore (for verification)
  Future<bool> checkIsFavorite(int recipeId) async {
    if (_currentUserId == null) return false;

    try {
      return await _firestoreService.isFavorite(_currentUserId!, recipeId);
    } catch (e) {
      print("❌ Error checking favorite status: $e");
      return false;
    }
  }

  /// Clears all favorites (useful for logout)
  void clearFavorites() {
    _favoriteIds.clear();
    _favoriteRecipes.clear();
    notifyListeners();
  }
}