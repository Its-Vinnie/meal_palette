import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/recipe_model.dart';

class FirestoreService {
  //* Reference for firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================================
  // RECIPE OPERATIONS
  // ============================================================================

  /// Saves a single recipe to Firestore
  Future<void> saveRecipe(Recipe recipe) async {
    try {
      CollectionReference recipes = _db.collection('recipes');
      String recipeId = recipe.id.toString();

      await recipes.doc(recipeId).set(
            recipe.toMap(),
            SetOptions(merge: true),
          );

      print("✅ Recipe saved successfully: ${recipe.title}");
    } catch (e) {
      print("❌ Error saving recipe: $e");
    }
  }

  /// Saves detailed recipe information to Firestore
  Future<void> saveDetailedRecipe(RecipeDetail recipe) async {
    try {
      CollectionReference recipes = _db.collection('recipes');
      String recipeId = recipe.id.toString();

      await recipes.doc(recipeId).set(recipe.toMap(), SetOptions(merge: true));

      print("✅ Detailed recipe saved: ${recipe.title}");
    } catch (e) {
      print("❌ Error saving detailed recipe: $e");
    }
  }

  /// Saves multiple recipes in a batch operation
  Future<void> saveRecipesBatch(List<Recipe> recipeList) async {
    if (recipeList.isEmpty) return;

    try {
      const int batchSize = 500;
      
      for (int i = 0; i < recipeList.length; i += batchSize) {
        WriteBatch batch = _db.batch();
        
        int end = (i + batchSize < recipeList.length) 
            ? i + batchSize 
            : recipeList.length;
        
        List<Recipe> chunk = recipeList.sublist(i, end);

        for (Recipe recipe in chunk) {
          String recipeId = recipe.id.toString();
          DocumentReference docRef = _db.collection('recipes').doc(recipeId);
          batch.set(docRef, recipe.toMap(), SetOptions(merge: true));
        }

        await batch.commit();
        print("✅ Batch saved ${chunk.length} recipes (${i + 1}-$end of ${recipeList.length})");
      }
    } catch (e) {
      print("❌ Error in batch save: $e");
    }
  }

  /// Retrieves a single recipe by ID
  Future<Map<String, dynamic>?> getRecipe(String recipeId) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('recipes').doc(recipeId).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        print("⚠️ Recipe not found: $recipeId");
        return null;
      }
    } catch (e) {
      print("❌ Error retrieving recipe: $e");
      rethrow;
    }
  }

  /// Gets all recipes from Firestore
  Future<List<Map<String, dynamic>>> getAllRecipes() async {
    try {
      QuerySnapshot querySnapshot = await _db.collection('recipes').get();

      List<Map<String, dynamic>> recipes = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        recipes.add(data);
      }

      print("✅ Retrieved ${recipes.length} recipes from Firestore");
      return recipes;
    } catch (e) {
      print("❌ Error getting all recipes: $e");
      return [];
    }
  }

  /// Gets recipes with pagination - IMPROVED for random selection
  Future<List<Recipe>> getRecipesPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      //* Get total count first
      final countSnapshot = await _db.collection('recipes').count().get();
      final totalRecipes = countSnapshot.count ?? 0;

      if (totalRecipes == 0) {
        print("⚠️ No recipes in Firestore");
        return [];
      }

      //* Get all recipes and shuffle for random selection
      QuerySnapshot querySnapshot = await _db
          .collection('recipes')
          .limit(limit * 3) // Get more to shuffle from
          .get();

      List<Recipe> recipes = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Recipe.fromJson(data);
      }).toList();

      //* Shuffle for random selection
      recipes.shuffle();

      //* Return limited amount
      return recipes.take(limit).toList();
    } catch (e) {
      print("❌ Error getting paginated recipes: $e");
      return [];
    }
  }

  /// IMPROVED: Searches recipes in Firestore by title with better matching
  Future<List<Recipe>> searchRecipesInFirestore(String query) async {
    try {
      if (query.isEmpty) {
        return await getRecipesPaginated(limit: 20);
      }

      //* Get all recipes for client-side filtering (better search)
      QuerySnapshot querySnapshot = await _db
          .collection('recipes')
          .get();

      List<Recipe> allRecipes = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Recipe.fromJson(data);
      }).toList();

      //* Convert query to lowercase for case-insensitive search
      final searchTerms = query.toLowerCase().split(' ');

      //* Filter recipes based on search terms
      List<Recipe> matchingRecipes = allRecipes.where((recipe) {
        final titleLower = recipe.title.toLowerCase();
        final summaryLower = (recipe.summary ?? '').toLowerCase();
        
        //* Check if any search term matches title or summary
        return searchTerms.any((term) => 
          titleLower.contains(term) || summaryLower.contains(term)
        );
      }).toList();

      //* Sort by relevance (title matches first)
      matchingRecipes.sort((a, b) {
        final aTitle = a.title.toLowerCase();
        final bTitle = b.title.toLowerCase();
        final firstTerm = searchTerms.first;
        
        final aStartsWith = aTitle.startsWith(firstTerm);
        final bStartsWith = bTitle.startsWith(firstTerm);
        
        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        return 0;
      });

      print("🔍 Found ${matchingRecipes.length} recipes in Firestore for: $query");
      return matchingRecipes;
    } catch (e) {
      print("❌ Error searching in Firestore: $e");
      return [];
    }
  }

  /// NEW: Get random recipes from Firestore (for trending/discovery)
  Future<List<Recipe>> getRandomRecipes({int limit = 10}) async {
    try {
      //* Get a larger batch and shuffle
      QuerySnapshot querySnapshot = await _db
          .collection('recipes')
          .limit(limit * 3)
          .get();

      List<Recipe> recipes = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Recipe.fromJson(data);
      }).toList();

      //* Shuffle and return limited amount
      recipes.shuffle();
      return recipes.take(limit).toList();
    } catch (e) {
      print("❌ Error getting random recipes: $e");
      return [];
    }
  }

  /// NEW: Get recipes by category keywords
  Future<List<Recipe>> getRecipesByCategory(String category, {int limit = 10}) async {
    try {
      //* Define category keywords
      final categoryKeywords = _getCategoryKeywords(category);
      
      //* Get all recipes and filter by keywords
      QuerySnapshot querySnapshot = await _db
          .collection('recipes')
          .get();

      List<Recipe> allRecipes = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Recipe.fromJson(data);
      }).toList();

      //* Filter by category keywords
      List<Recipe> categoryRecipes = allRecipes.where((recipe) {
        final titleLower = recipe.title.toLowerCase();
        final summaryLower = (recipe.summary ?? '').toLowerCase();
        
        return categoryKeywords.any((keyword) =>
          titleLower.contains(keyword) || summaryLower.contains(keyword)
        );
      }).toList();

      //* Shuffle for variety
      categoryRecipes.shuffle();

      print("✅ Found ${categoryRecipes.length} recipes for category: $category");
      return categoryRecipes.take(limit).toList();
    } catch (e) {
      print("❌ Error getting recipes by category: $e");
      return [];
    }
  }

  /// Helper: Get keywords for category
  List<String> _getCategoryKeywords(String category) {
    switch (category.toLowerCase()) {
      case 'western':
        return ['burger', 'steak', 'american', 'bbq', 'grilled'];
      case 'bread':
        return ['bread', 'baked', 'roll', 'bagel', 'toast'];
      case 'soup':
        return ['soup', 'broth', 'stew', 'chowder'];
      case 'dessert':
        return ['dessert', 'cake', 'sweet', 'chocolate', 'cookie', 'pie'];
      case 'coffee':
        return ['coffee', 'latte', 'espresso', 'cappuccino', 'drink'];
      default:
        return [category.toLowerCase()];
    }
  }

  /// Checks if a recipe exists in Firestore
  Future<bool> recipeExists(String recipeId) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('recipes').doc(recipeId).get();
      return doc.exists;
    } catch (e) {
      print("❌ Error checking recipe existence: $e");
      return false;
    }
  }

  /// Updates specific fields of a recipe
  Future<void> updateRecipe(
      String recipeId, Map<String, dynamic> updates) async {
    try {
      await _db.collection('recipes').doc(recipeId).update(updates);
      print("✅ Recipe updated successfully");
    } catch (e) {
      print("❌ Error updating recipe: $e");
      rethrow;
    }
  }

  /// Deletes a recipe from Firestore
  Future<void> deleteRecipe(String recipeId) async {
    try {
      await _db.collection('recipes').doc(recipeId).delete();
      print("✅ Recipe deleted successfully");
    } catch (e) {
      print("❌ Error deleting recipe: $e");
      rethrow;
    }
  }

  // ============================================================================
  // RECIPE ANALYTICS & TRACKING
  // ============================================================================

  /// Tracks when a user views a recipe
  Future<void> trackRecipeView(String userId, int recipeId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('viewHistory')
          .doc(recipeId.toString())
          .set({
        'recipeId': recipeId,
        'viewedAt': FieldValue.serverTimestamp(),
        'viewCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      print("📊 Tracked view for recipe: $recipeId");
    } catch (e) {
      print("❌ Error tracking recipe view: $e");
    }
  }

  /// Gets user's recently viewed recipes
  Future<List<Recipe>> getRecentlyViewedRecipes(String userId,
      {int limit = 10}) async {
    try {
      QuerySnapshot viewHistory = await _db
          .collection('users')
          .doc(userId)
          .collection('viewHistory')
          .orderBy('viewedAt', descending: true)
          .limit(limit)
          .get();

      List<int> recipeIds = viewHistory.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['recipeId'] as int)
          .toList();

      List<Recipe> recipes = [];
      for (int recipeId in recipeIds) {
        final recipeData = await getRecipe(recipeId.toString());
        if (recipeData != null) {
          recipes.add(Recipe.fromJson(recipeData));
        }
      }

      return recipes;
    } catch (e) {
      print("❌ Error getting recently viewed recipes: $e");
      return [];
    }
  }

  // ============================================================================
  // FAVORITES OPERATIONS
  // ============================================================================

  /// Adds a recipe to user's favorites
  Future<void> addToFavorites(String userId, Recipe recipe) async {
    try {
      DocumentReference favoriteRef = _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(recipe.id.toString());

      await favoriteRef.set({
        ...recipe.toMap(),
        'favoritedAt': FieldValue.serverTimestamp(),
      });

      print("❤️ Added to favorites: ${recipe.title}");
    } catch (e) {
      print("❌ Error adding to favorites: $e");
      rethrow;
    }
  }

  /// Removes a recipe from user's favorites
  Future<void> removeFromFavorites(String userId, int recipeId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(recipeId.toString())
          .delete();

      print("💔 Removed from favorites: $recipeId");
    } catch (e) {
      print("❌ Error removing from favorites: $e");
      rethrow;
    }
  }

  /// Checks if a recipe is in user's favorites
  Future<bool> isFavorite(String userId, int recipeId) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(recipeId.toString())
          .get();

      return doc.exists;
    } catch (e) {
      print("❌ Error checking favorite status: $e");
      return false;
    }
  }

  /// Gets all favorite recipes for a user
  Future<List<Recipe>> getFavoriteRecipes(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('favoritedAt', descending: true)
          .get();

      List<Recipe> favorites = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        favorites.add(Recipe.fromJson(data));
      }

      print("❤️ Retrieved ${favorites.length} favorite recipes");
      return favorites;
    } catch (e) {
      print("❌ Error getting favorites: $e");
      return [];
    }
  }

  /// Stream of favorite recipes for real-time updates
  Stream<List<Recipe>> favoritesStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('favoritedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Recipe.fromJson(doc.data());
      }).toList();
    });
  }

  // ============================================================================
  // USER PROFILE OPERATIONS
  // ============================================================================

  /// Creates or updates user profile
  Future<void> saveUserProfile(String userId,
      {required String name, required String email}) async {
    try {
      await _db.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("✅ User profile saved");
    } catch (e) {
      print("❌ Error saving user profile: $e");
      rethrow;
    }
  }

  /// Gets user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("❌ Error getting user profile: $e");
      return null;
    }
  }

  /// Updates user profile fields
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('users').doc(userId).update(updates);
      print("✅ User profile updated");
    } catch (e) {
      print("❌ Error updating user profile: $e");
      rethrow;
    }
  }

  // ============================================================================
  // DATABASE STATISTICS
  // ============================================================================

  /// Gets the total count of recipes in Firestore
  Future<int> getRecipeCount() async {
    try {
      AggregateQuerySnapshot snapshot = await _db
          .collection('recipes')
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      print("❌ Error getting recipe count: $e");
      return 0;
    }
  }
}