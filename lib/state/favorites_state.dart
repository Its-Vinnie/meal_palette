import 'package:flutter/foundation.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';

/// State management for favorites using ValueNotifier
/// This allows widgets to reactively update when favorites change
class FavoritesState extends ChangeNotifier {
  //* Singleton pattern - ensures only one instance exists
  static final FavoritesState _instance = FavoritesState._internal();
  factory FavoritesState() => _instance;
  FavoritesState._internal();

  //* Firestore service for database operations
  final FirestoreService _firestoreService = FirestoreService();

  //* Set to store favorite recipe IDs for quick lookup
  final Set<int> _favoriteIds = {};

  //* List to store full favorite recipes
  final List<Recipe> _favoriteRecipes = [];

  //* Loading state
  bool _isLoading = false;

  //* Current user ID (in production, get from Firebase Auth)
  String _currentUserId = 'default_user'; // TODO: Replace with actual auth

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
  String get currentUserId => _currentUserId;

  /// Checks if a recipe is favorited
  bool isFavorite(int recipeId) => _favoriteIds.contains(recipeId);

  /// Returns count of favorites
  int get favoriteCount => _favoriteIds.length;

  // ============================================================================
  // METHODS
  // ============================================================================

  /// Sets the current user ID (call this after authentication)
  void setUserId(String userId) {
    _currentUserId = userId;
    loadFavorites(); // Reload favorites for new user
  }

  /// Loads all favorites from Firestore
  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      //* Fetch favorites from Firestore
      final favorites =
          await _firestoreService.getFavoriteRecipes(_currentUserId);

      //* Clear existing data
      _favoriteRecipes.clear();
      _favoriteIds.clear();

      //* Populate with new data
      _favoriteRecipes.addAll(favorites);
      _favoriteIds.addAll(favorites.map((r) => r.id));

      print("✅ Loaded ${_favoriteRecipes.length} favorites");
    } catch (e) {
      print("❌ Error loading favorites: $e");
    } finally {
      _isLoading = false;
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
    try {
      //* Optimistically update UI
      _favoriteIds.add(recipe.id);
      _favoriteRecipes.insert(0, recipe); // Add to beginning
      notifyListeners();

      //* Save to Firestore
      await _firestoreService.addToFavorites(_currentUserId, recipe);

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
    try {
      //* Store recipe for potential revert
      final removedRecipe =
          _favoriteRecipes.firstWhere((r) => r.id == recipeId);

      //* Optimistically update UI
      _favoriteIds.remove(recipeId);
      _favoriteRecipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();

      //* Remove from Firestore
      await _firestoreService.removeFromFavorites(_currentUserId, recipeId);

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
    try {
      return await _firestoreService.isFavorite(_currentUserId, recipeId);
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