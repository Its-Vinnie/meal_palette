import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/model/recipe_collection_model.dart';

/// State management for recipe collections using ChangeNotifier
/// This allows widgets to reactively update when collections change
class CollectionsState extends ChangeNotifier {
  //* Singleton pattern - ensures only one instance exists
  static final CollectionsState _instance = CollectionsState._internal();
  factory CollectionsState() => _instance;

  CollectionsState._internal() {
    //* Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUserId = user.uid;
        // Schedule collections loading for next frame to avoid setState during build
        Future.microtask(() => loadCollections());
      } else {
        _currentUserId = null;
        clearCollections(); // Clear collections when logged out
      }
    });
  }

  //* Firestore service for database operations
  final FirestoreService _firestoreService = FirestoreService();

  //* List to store all collections
  final List<RecipeCollection> _collections = [];

  //* Map to cache recipes for each collection (collectionId -> List<Recipe>)
  final Map<String, List<Recipe>> _collectionRecipesCache = {};

  //* Loading state
  bool _isLoading = false;

  //* Current user ID from Firebase Auth
  String? _currentUserId;

  // ============================================================================
  // GETTERS
  // ============================================================================

  /// Returns unmodifiable list of collections
  List<RecipeCollection> get collections => List.unmodifiable(_collections);

  /// Returns only pinned collections
  List<RecipeCollection> get pinnedCollections =>
      _collections.where((c) => c.isPinned).toList();

  /// Returns the default "All Favorites" collection
  RecipeCollection? get defaultCollection =>
      _collections.where((c) => c.isDefault).firstOrNull;

  /// Returns loading state
  bool get isLoading => _isLoading;

  /// Returns current user ID
  String get currentUserId => _currentUserId ?? '';

  /// Returns count of collections
  int get collectionCount => _collections.length;

  // ============================================================================
  // COLLECTION CRUD METHODS
  // ============================================================================

  /// Loads all collections from Firestore for current user
  Future<void> loadCollections() async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in, cannot load collections');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      //* Fetch collections from Firestore
      final collections = await _firestoreService.getCollections(_currentUserId!);

      //* Clear existing and update
      _collections.clear();
      _collections.addAll(collections);

      print('✅ Loaded ${collections.length} collections');

      //* Pre-fetch recipes for cover images (non-blocking)
      _prefetchCollectionRecipes();
    } catch (e) {
      print('❌ Error loading collections: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pre-fetches first 4 recipes for each collection (for cover images)
  Future<void> _prefetchCollectionRecipes() async {
    if (_currentUserId == null || _collections.isEmpty) return;

    // Fetch recipes for each collection in background
    for (final collection in _collections) {
      // Skip if already cached
      if (_collectionRecipesCache.containsKey(collection.id)) continue;

      // Fetch recipes (this will auto-cache them)
      getCollectionRecipes(collection.id).then((_) {
        // Notify listeners when recipes are loaded so UI can update
        notifyListeners();
      }).catchError((e) {
        print('⚠️ Error pre-fetching recipes for ${collection.name}: $e');
      });
    }
  }

  /// Creates a new collection
  Future<bool> createCollection({
    required String name,
    String? description,
    required String icon,
    required String color,
    bool isPinned = false,
    String coverImageType = 'grid',
    String? customCoverUrl,
  }) async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in, cannot create collection');
      return false;
    }

    try {
      // Optimistically add to local state
      final newCollection = await _firestoreService.createCollection(
        _currentUserId!,
        name: name,
        description: description,
        icon: icon,
        color: color,
        isPinned: isPinned,
        coverImageType: coverImageType,
        customCoverUrl: customCoverUrl,
      );

      _collections.add(newCollection);
      _sortCollections();
      notifyListeners();

      print('✅ Collection created: $name');
      return true;
    } catch (e) {
      print('❌ Error creating collection: $e');
      // Reload to ensure consistency
      await loadCollections();
      return false;
    }
  }

  /// Updates an existing collection
  Future<bool> updateCollection(RecipeCollection collection) async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in, cannot update collection');
      return false;
    }

    // Store old collection for rollback
    final index = _collections.indexWhere((c) => c.id == collection.id);
    if (index == -1) {
      print('⚠️ Collection not found in local state');
      return false;
    }

    final oldCollection = _collections[index];

    try {
      // Optimistically update local state
      _collections[index] = collection.copyWith(updatedAt: DateTime.now());
      _sortCollections();
      notifyListeners();

      // Save to Firestore
      await _firestoreService.updateCollection(_currentUserId!, collection);

      print('✅ Collection updated: ${collection.name}');
      return true;
    } catch (e) {
      print('❌ Error updating collection: $e');
      // Revert on error
      _collections[index] = oldCollection;
      notifyListeners();
      return false;
    }
  }

  /// Deletes a collection
  Future<bool> deleteCollection(String collectionId) async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in, cannot delete collection');
      return false;
    }

    // Find collection
    final collection = _collections.where((c) => c.id == collectionId).firstOrNull;
    if (collection == null) {
      print('⚠️ Collection not found');
      return false;
    }

    // Prevent deleting default collection
    if (collection.isDefault) {
      print('⚠️ Cannot delete default collection');
      return false;
    }

    // Store for rollback
    final index = _collections.indexOf(collection);

    try {
      // Optimistically remove from local state
      _collections.removeAt(index);
      _collectionRecipesCache.remove(collectionId);
      notifyListeners();

      // Delete from Firestore
      await _firestoreService.deleteCollection(_currentUserId!, collectionId);

      print('✅ Collection deleted');
      return true;
    } catch (e) {
      print('❌ Error deleting collection: $e');
      // Revert on error
      _collections.insert(index, collection);
      notifyListeners();
      return false;
    }
  }

  // ============================================================================
  // RECIPE MANAGEMENT METHODS
  // ============================================================================

  /// Adds a recipe to a collection
  Future<bool> addRecipeToCollection(String collectionId, Recipe recipe) async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in');
      return false;
    }

    // Find collection
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) {
      print('⚠️ Collection not found');
      return false;
    }

    try {
      // Optimistically update local state
      final updatedCollection = _collections[index].copyWith(
        recipeCount: _collections[index].recipeCount + 1,
        updatedAt: DateTime.now(),
      );
      _collections[index] = updatedCollection;

      // Update cache if exists
      _collectionRecipesCache[collectionId]?.insert(0, recipe);
      notifyListeners();

      // Save to Firestore
      await _firestoreService.addRecipeToCollection(
        _currentUserId!,
        collectionId,
        recipe,
      );

      print('✅ Recipe added to collection');
      return true;
    } catch (e) {
      print('❌ Error adding recipe to collection: $e');
      // Reload to ensure consistency
      await loadCollections();
      return false;
    }
  }

  /// Removes a recipe from a collection
  Future<bool> removeRecipeFromCollection(
    String collectionId,
    int recipeId,
  ) async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in');
      return false;
    }

    // Find collection
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) {
      print('⚠️ Collection not found');
      return false;
    }

    try {
      // Optimistically update local state
      final updatedCollection = _collections[index].copyWith(
        recipeCount: _collections[index].recipeCount - 1,
        updatedAt: DateTime.now(),
      );
      _collections[index] = updatedCollection;

      // Update cache if exists
      _collectionRecipesCache[collectionId]?.removeWhere((r) => r.id == recipeId);
      notifyListeners();

      // Save to Firestore
      await _firestoreService.removeRecipeFromCollection(
        _currentUserId!,
        collectionId,
        recipeId,
      );

      print('✅ Recipe removed from collection');
      return true;
    } catch (e) {
      print('❌ Error removing recipe from collection: $e');
      // Reload to ensure consistency
      await loadCollections();
      return false;
    }
  }

  /// Gets all recipes in a collection
  Future<List<Recipe>> getCollectionRecipes(String collectionId) async {
    if (_currentUserId == null) {
      print('⚠️ No user logged in');
      return [];
    }

    // Return cached if available
    if (_collectionRecipesCache.containsKey(collectionId)) {
      return _collectionRecipesCache[collectionId]!;
    }

    try {
      final recipes = await _firestoreService.getCollectionRecipes(
        _currentUserId!,
        collectionId,
      );

      // Cache the results
      _collectionRecipesCache[collectionId] = recipes;

      return recipes;
    } catch (e) {
      print('❌ Error getting collection recipes: $e');
      return [];
    }
  }

  /// Gets first 4 recipe images for a collection (for cover display)
  List<String> getCollectionCoverImages(String collectionId) {
    // Use cached recipes if available
    if (_collectionRecipesCache.containsKey(collectionId)) {
      final recipes = _collectionRecipesCache[collectionId]!;
      return recipes
          .where((recipe) => recipe.image != null && recipe.image!.isNotEmpty)
          .take(4)
          .map((recipe) => recipe.image!)
          .toList();
    }
    return [];
  }

  /// Returns which collections contain a specific recipe
  List<RecipeCollection> getCollectionsForRecipe(int recipeId) {
    // This requires checking Firestore for each collection
    // For now, return empty list. UI will need to call isRecipeInCollection for each
    return [];
  }

  // ============================================================================
  // ADVANCED OPERATIONS
  // ============================================================================

  /// Toggles pin status of a collection
  Future<bool> togglePin(String collectionId) async {
    final collection = _collections.where((c) => c.id == collectionId).firstOrNull;
    if (collection == null) return false;

    return await updateCollection(
      collection.copyWith(isPinned: !collection.isPinned),
    );
  }

  /// Reorders collections (after drag-and-drop)
  Future<bool> reorderCollections(int oldIndex, int newIndex) async {
    if (_currentUserId == null) return false;

    try {
      // Update local state
      final collection = _collections.removeAt(oldIndex);
      _collections.insert(newIndex, collection);

      // Update sortOrder for all collections
      for (int i = 0; i < _collections.length; i++) {
        _collections[i] = _collections[i].copyWith(sortOrder: i);
      }

      notifyListeners();

      // Save to Firestore
      final collectionIds = _collections.map((c) => c.id).toList();
      await _firestoreService.reorderCollections(_currentUserId!, collectionIds);

      print('✅ Collections reordered');
      return true;
    } catch (e) {
      print('❌ Error reordering collections: $e');
      await loadCollections();
      return false;
    }
  }

  /// Duplicates a collection
  Future<RecipeCollection?> duplicateCollection(
    String collectionId,
    String newName,
  ) async {
    if (_currentUserId == null) return null;

    try {
      final newCollection = await _firestoreService.duplicateCollection(
        _currentUserId!,
        collectionId,
        newName,
      );

      _collections.add(newCollection);
      _sortCollections();
      notifyListeners();

      print('✅ Collection duplicated');
      return newCollection;
    } catch (e) {
      print('❌ Error duplicating collection: $e');
      return null;
    }
  }

  /// Creates a shareable link for a collection
  Future<String?> shareCollection(String collectionId) async {
    if (_currentUserId == null) return null;

    try {
      final shareToken = await _firestoreService.createShareLink(
        _currentUserId!,
        collectionId,
      );

      // Update local collection
      final index = _collections.indexWhere((c) => c.id == collectionId);
      if (index != -1) {
        _collections[index] = _collections[index].copyWith(
          shareToken: shareToken,
          isPublic: true,
        );
        notifyListeners();
      }

      return shareToken;
    } catch (e) {
      print('❌ Error sharing collection: $e');
      return null;
    }
  }

  /// Revokes a share link
  Future<bool> revokeShare(String collectionId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestoreService.revokeShareLink(_currentUserId!, collectionId);

      // Update local collection
      final index = _collections.indexWhere((c) => c.id == collectionId);
      if (index != -1) {
        _collections[index] = _collections[index].copyWith(
          shareToken: null,
          isPublic: false,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      print('❌ Error revoking share: $e');
      return false;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Clears all collections (called on logout)
  void clearCollections() {
    _collections.clear();
    _collectionRecipesCache.clear();
    _isLoading = false;
    notifyListeners();
  }

  /// Sorts collections (pinned first, then by sortOrder)
  void _sortCollections() {
    _collections.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
  }
}

/// Global instance of CollectionsState
final collectionsState = CollectionsState();
