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
  /// Takes a Recipe model and converts it to a map before saving
  /// Uses merge: true to avoid overwriting existing detailed data
  Future<void> saveRecipe(Recipe recipe) async {
    try {
      //* Getting reference to the recipes collection
      CollectionReference recipes = _db.collection('recipes');

      //* Using recipe id as the document name for easy retrieval
      String recipeId = recipe.id.toString();

      //* Converting recipe to map and saving to Firestore
      //* Using merge: true to preserve any detailed data that might exist
      await recipes.doc(recipeId).set(
            recipe.toMap(),
            SetOptions(merge: true),
          );

      print("✅ Recipe saved successfully: ${recipe.title}");
    } catch (e) {
      print("❌ Error saving recipe: $e");
      // Don't rethrow - we don't want to break the app if saving fails
    }
  }

  /// Saves detailed recipe information to Firestore
  /// Used when user views recipe details
  Future<void> saveDetailedRecipe(RecipeDetail recipe) async {
    try {
      CollectionReference recipes = _db.collection('recipes');
      String recipeId = recipe.id.toString();

      //* Converting detailed recipe to map
      //* merge: true ensures we don't lose any existing data
      await recipes.doc(recipeId).set(recipe.toMap(), SetOptions(merge: true));

      print("✅ Detailed recipe saved: ${recipe.title}");
    } catch (e) {
      print("❌ Error saving detailed recipe: $e");
      // Don't rethrow - silent failure for background saves
    }
  }

  /// Saves multiple recipes in a batch operation
  /// More efficient than saving one by one
  /// Perfect for saving search results and home feed recipes
  Future<void> saveRecipesBatch(List<Recipe> recipeList) async {
    if (recipeList.isEmpty) return;

    try {
      //* Firestore batch can handle up to 500 operations
      //* Split into chunks if needed
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
      // Don't rethrow - silent failure for background saves
    }
  }

  /// Retrieves a single recipe by ID
  /// Returns null if recipe doesn't exist
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
  /// Returns empty list if no recipes found
  /// Useful for offline mode or recommendations
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

  /// Gets recipes with pagination for better performance
  /// Use this when building recommendation feeds
  Future<List<Recipe>> getRecipesPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db.collection('recipes').limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      QuerySnapshot querySnapshot = await query.get();

      List<Recipe> recipes = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Recipe.fromJson(data);
      }).toList();

      return recipes;
    } catch (e) {
      print("❌ Error getting paginated recipes: $e");
      return [];
    }
  }

  /// Searches recipes in Firestore by title
  /// Useful for offline search or quick results
  Future<List<Recipe>> searchRecipesInFirestore(String query) async {
    try {
      //* Simple search - Firestore doesn't support full-text search
      //* For production, consider using Algolia or ElasticSearch
      QuerySnapshot querySnapshot = await _db
          .collection('recipes')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      List<Recipe> recipes = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Recipe.fromJson(data);
      }).toList();

      print("🔍 Found ${recipes.length} recipes in Firestore");
      return recipes;
    } catch (e) {
      print("❌ Error searching in Firestore: $e");
      return [];
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
  /// Useful for building personalized recommendations
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
      // Silent failure - analytics shouldn't break the app
    }
  }

  /// Gets user's recently viewed recipes
  /// Perfect for "Continue Cooking" or "Recently Viewed" sections
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

      //* Get recipe IDs from view history
      List<int> recipeIds = viewHistory.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['recipeId'] as int)
          .toList();

      //* Fetch actual recipes
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
  /// userId should come from Firebase Auth in production
  Future<void> addToFavorites(String userId, Recipe recipe) async {
    try {
      //* Reference to user's favorites subcollection
      DocumentReference favoriteRef = _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(recipe.id.toString());

      //* Save recipe data with timestamp
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
  /// Returns them ordered by most recently favorited
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
  /// Useful for keeping the favorites screen updated
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