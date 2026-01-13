import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/model/recipe_collection_model.dart';

class FirestoreService {
  //* Reference for firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;



  /// Helper method to safely parse recipe ID
  int _parseRecipeId(dynamic value, String fallbackDocId) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    
    //* Try to parse document ID as last resort
    final docIdParsed = int.tryParse(fallbackDocId);
    return docIdParsed ?? 0;
  }

  // ============================================================================
  // RECIPE OPERATIONS
  // ============================================================================

  /// Saves a single recipe to Firestore
  Future<void> saveRecipe(Recipe recipe) async {
    try {
      CollectionReference recipes = _db.collection('recipes');
      String recipeId = recipe.id.toString();

      //* Ensure the data being saved has int ID
      final dataToSave = recipe.toMap();
      dataToSave['id'] = recipe.id; // Explicitly set as int


      await recipes.doc(recipeId).set(dataToSave, SetOptions(merge: true));

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

       //* Ensure the data being saved has int ID
      final dataToSave = recipe.toMap();
      dataToSave['id'] = recipe.id; // Explicitly set as int

      await recipes.doc(recipeId).set(dataToSave, SetOptions(merge: true));


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
        print(
          "✅ Batch saved ${chunk.length} recipes (${i + 1}-$end of ${recipeList.length})",
        );
      }
    } catch (e) {
      print("❌ Error in batch save: $e");
    }
  }

  /// Retrieves a single recipe by ID
 Future<Map<String, dynamic>?> getRecipe(String recipeId) async {
  try {
    DocumentSnapshot doc = await _db
        .collection('recipes')
        .doc(recipeId)
        .get();

    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      //* Ensure ID is properly formatted as int
      data['id'] = _parseRecipeId(data['id'], doc.id);
      
      return data;
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
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          //* Ensure ID is int
          data['id'] = _parseRecipeId(data['id'], doc.id);
          
          //* Skip recipes with invalid IDs
          if (data['id'] == 0) {
            print('⚠️ Skipping recipe with invalid ID: ${doc.id}');
            continue;
          }
          
          recipes.add(data);
        } catch (e) {
          print('⚠️ Error processing recipe ${doc.id}: $e');
          continue;
        }
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
      final countSnapshot = await _db.collection('recipes').count().get();
      final totalRecipes = countSnapshot.count ?? 0;

      if (totalRecipes == 0) {
        print("⚠️ No recipes in Firestore");
        return [];
      }

      QuerySnapshot querySnapshot = await _db
          .collection('recipes')
          .limit(limit * 3)
          .get();

      List<Recipe> recipes = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          //* Ensure ID is int
          data['id'] = _parseRecipeId(data['id'], doc.id);
          
          if (data['id'] != 0) {
            recipes.add(Recipe.fromJson(data));
          }
        } catch (e) {
          print('⚠️ Error parsing recipe ${doc.id}: $e');
          continue;
        }
      }

      recipes.shuffle();
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

      QuerySnapshot querySnapshot = await _db.collection('recipes').get();

      List<Recipe> allRecipes = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          //* Ensure ID is int
          data['id'] = _parseRecipeId(data['id'], doc.id);
          
          if (data['id'] != 0) {
            allRecipes.add(Recipe.fromJson(data));
          }
        } catch (e) {
          print('⚠️ Error parsing recipe ${doc.id}: $e');
          continue;
        }
      }

      final searchTerms = query.toLowerCase().split(' ');

      List<Recipe> matchingRecipes = allRecipes.where((recipe) {
        final titleLower = recipe.title.toLowerCase();
        final summaryLower = (recipe.summary ?? '').toLowerCase();

        return searchTerms.any(
          (term) => titleLower.contains(term) || summaryLower.contains(term),
        );
      }).toList();

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
      QuerySnapshot querySnapshot = await _db
          .collection('recipes')
          .limit(limit * 3)
          .get();

      List<Recipe> recipes = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          //* Ensure ID is int
          data['id'] = _parseRecipeId(data['id'], doc.id);
          
          if (data['id'] != 0) {
            recipes.add(Recipe.fromJson(data));
          }
        } catch (e) {
          print('⚠️ Error parsing recipe ${doc.id}: $e');
          continue;
        }
      }

      recipes.shuffle();
      return recipes.take(limit).toList();
    } catch (e) {
      print("❌ Error getting random recipes: $e");
      return [];
    }
  }
  /// NEW: Get recipes by category keywords
  Future<List<Recipe>> getRecipesByCategory(
    String category, {
    int limit = 10,
  }) async {
    try {
      final categoryKeywords = _getCategoryKeywords(category);

      QuerySnapshot querySnapshot = await _db.collection('recipes').get();

      List<Recipe> allRecipes = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          //* Ensure ID is int
          data['id'] = _parseRecipeId(data['id'], doc.id);
          
          if (data['id'] != 0) {
            allRecipes.add(Recipe.fromJson(data));
          }
        } catch (e) {
          print('⚠️ Error parsing recipe ${doc.id}: $e');
          continue;
        }
      }

      List<Recipe> categoryRecipes = allRecipes.where((recipe) {
        final titleLower = recipe.title.toLowerCase();
        final summaryLower = (recipe.summary ?? '').toLowerCase();

        return categoryKeywords.any(
          (keyword) =>
              titleLower.contains(keyword) || summaryLower.contains(keyword),
        );
      }).toList();

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
      DocumentSnapshot doc = await _db
          .collection('recipes')
          .doc(recipeId)
          .get();
      return doc.exists;
    } catch (e) {
      print("❌ Error checking recipe existence: $e");
      return false;
    }
  }

  /// Updates specific fields of a recipe
  Future<void> updateRecipe(
    String recipeId,
    Map<String, dynamic> updates,
  ) async {
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
  Future<List<Recipe>> getRecentlyViewedRecipes(
    String userId, {
    int limit = 10,
  }) async {
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

      // Sync with "All Favorites" collection
      await syncFavoritesWithDefaultCollection(userId, recipe, true);
    } catch (e) {
      print("❌ Error adding to favorites: $e");
      rethrow;
    }
  }

  /// Removes a recipe from user's favorites
  Future<void> removeFromFavorites(String userId, int recipeId) async {
    try {
      // Get recipe data before deleting
      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(recipeId.toString())
          .get();

      await _db
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(recipeId.toString())
          .delete();

      print("💔 Removed from favorites: $recipeId");

      // Sync with "All Favorites" collection
      if (doc.exists) {
        final recipe = Recipe.fromJson(doc.data() as Map<String, dynamic>);
        await syncFavoritesWithDefaultCollection(userId, recipe, false);
      }
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
  Future<void> saveUserProfile(
    String userId, {
    required String name,
    required String email,
  }) async {
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
    String userId,
    Map<String, dynamic> updates,
  ) async {
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

  // ============================================================================
  // COLLECTION OPERATIONS
  // ============================================================================

  /// Creates a new recipe collection
  Future<RecipeCollection> createCollection(
    String userId, {
    required String name,
    String? description,
    required String icon,
    required String color,
    bool isPinned = false,
    String coverImageType = 'grid',
    String? customCoverUrl,
  }) async {
    try {
      // Get current max sortOrder
      final collections = await getCollections(userId);
      final maxSortOrder = collections.isEmpty
          ? 0
          : collections.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);

      final collectionRef = _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc();

      final now = DateTime.now();
      final collectionData = {
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
        'coverImageType': coverImageType,
        'customCoverUrl': customCoverUrl,
        'isPinned': isPinned,
        'isDefault': false,
        'sortOrder': maxSortOrder + 1,
        'recipeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'shareToken': null,
        'isPublic': false,
      };

      await collectionRef.set(collectionData);

      print("✅ Collection created: $name");

      // Return collection with generated ID
      return RecipeCollection.fromJson({...collectionData, 'createdAt': now, 'updatedAt': now}, collectionRef.id);
    } catch (e) {
      print("❌ Error creating collection: $e");
      rethrow;
    }
  }

  /// Gets all collections for a user (ordered by pinned, then sortOrder)
  Future<List<RecipeCollection>> getCollections(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .get();

      List<RecipeCollection> collections = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        collections.add(RecipeCollection.fromJson(data, doc.id));
      }

      // Sort: pinned first, then by sortOrder
      collections.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });

      print("✅ Retrieved ${collections.length} collections");
      return collections;
    } catch (e) {
      print("❌ Error getting collections: $e");
      return [];
    }
  }

  /// Updates collection metadata
  Future<void> updateCollection(String userId, RecipeCollection collection) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collection.id)
          .update({
        'name': collection.name,
        'description': collection.description,
        'icon': collection.icon,
        'color': collection.color,
        'coverImageType': collection.coverImageType,
        'customCoverUrl': collection.customCoverUrl,
        'isPinned': collection.isPinned,
        'sortOrder': collection.sortOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Collection updated: ${collection.name}");
    } catch (e) {
      print("❌ Error updating collection: $e");
      rethrow;
    }
  }

  /// Deletes a collection and all its recipes
  Future<void> deleteCollection(String userId, String collectionId) async {
    try {
      // Delete all recipes in the collection first (using batch)
      final recipesSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('collectionRecipes')
          .doc(collectionId)
          .collection('recipes')
          .get();

      final batch = _db.batch();

      for (var doc in recipesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the collection document
      batch.delete(_db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionId));

      await batch.commit();

      print("✅ Collection deleted with ${recipesSnapshot.docs.length} recipes");
    } catch (e) {
      print("❌ Error deleting collection: $e");
      rethrow;
    }
  }

  /// Adds a recipe to a collection
  Future<void> addRecipeToCollection(
    String userId,
    String collectionId,
    Recipe recipe,
  ) async {
    try {
      // Add recipe to collection's recipes subcollection
      await _db
          .collection('users')
          .doc(userId)
          .collection('collectionRecipes')
          .doc(collectionId)
          .collection('recipes')
          .doc(recipe.id.toString())
          .set({
        ...recipe.toMap(),
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Increment recipe count
      await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionId)
          .update({
        'recipeCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Added recipe ${recipe.title} to collection");
    } catch (e) {
      print("❌ Error adding recipe to collection: $e");
      rethrow;
    }
  }

  /// Removes a recipe from a collection
  Future<void> removeRecipeFromCollection(
    String userId,
    String collectionId,
    int recipeId,
  ) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('collectionRecipes')
          .doc(collectionId)
          .collection('recipes')
          .doc(recipeId.toString())
          .delete();

      // Decrement recipe count
      await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionId)
          .update({
        'recipeCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Removed recipe $recipeId from collection");
    } catch (e) {
      print("❌ Error removing recipe from collection: $e");
      rethrow;
    }
  }

  /// Gets all recipes in a collection
  Future<List<Recipe>> getCollectionRecipes(
    String userId,
    String collectionId,
  ) async {
    try {
      QuerySnapshot querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('collectionRecipes')
          .doc(collectionId)
          .collection('recipes')
          .orderBy('addedAt', descending: true)
          .get();

      List<Recipe> recipes = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        recipes.add(Recipe.fromJson(data));
      }

      print("✅ Retrieved ${recipes.length} recipes from collection");
      return recipes;
    } catch (e) {
      print("❌ Error getting collection recipes: $e");
      return [];
    }
  }

  /// Checks if a recipe is in a collection
  Future<bool> isRecipeInCollection(
    String userId,
    String collectionId,
    int recipeId,
  ) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(userId)
          .collection('collectionRecipes')
          .doc(collectionId)
          .collection('recipes')
          .doc(recipeId.toString())
          .get();

      return doc.exists;
    } catch (e) {
      print("❌ Error checking recipe in collection: $e");
      return false;
    }
  }

  /// Reorders collections by updating sortOrder
  Future<void> reorderCollections(
    String userId,
    List<String> collectionIdsInOrder,
  ) async {
    try {
      final batch = _db.batch();

      for (int i = 0; i < collectionIdsInOrder.length; i++) {
        final collectionRef = _db
            .collection('users')
            .doc(userId)
            .collection('collections')
            .doc(collectionIdsInOrder[i]);

        batch.update(collectionRef, {
          'sortOrder': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      print("✅ Reordered ${collectionIdsInOrder.length} collections");
    } catch (e) {
      print("❌ Error reordering collections: $e");
      rethrow;
    }
  }

  /// Duplicates a collection
  Future<RecipeCollection> duplicateCollection(
    String userId,
    String collectionId,
    String newName,
  ) async {
    try {
      // Get original collection
      final originalDoc = await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionId)
          .get();

      if (!originalDoc.exists) {
        throw Exception('Collection not found');
      }

      final originalData = originalDoc.data() as Map<String, dynamic>;

      // Create new collection
      final newCollection = await createCollection(
        userId,
        name: newName,
        description: originalData['description'],
        icon: originalData['icon'] ?? 'bookmark',
        color: originalData['color'] ?? '#FF4757',
        isPinned: false,
      );

      // Copy all recipes
      final recipesSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('collectionRecipes')
          .doc(collectionId)
          .collection('recipes')
          .get();

      final batch = _db.batch();
      for (var doc in recipesSnapshot.docs) {
        final recipeRef = _db
            .collection('users')
            .doc(userId)
            .collection('collectionRecipes')
            .doc(newCollection.id)
            .collection('recipes')
            .doc(doc.id);

        batch.set(recipeRef, doc.data());
      }

      await batch.commit();

      // Update recipe count
      await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(newCollection.id)
          .update({'recipeCount': recipesSnapshot.docs.length});

      print("✅ Duplicated collection with ${recipesSnapshot.docs.length} recipes");
      return newCollection;
    } catch (e) {
      print("❌ Error duplicating collection: $e");
      rethrow;
    }
  }

  /// Creates a shareable link for a collection
  Future<String> createShareLink(String userId, String collectionId) async {
    try {
      // Generate unique token
      final shareToken = DateTime.now().millisecondsSinceEpoch.toString();

      // Get collection data
      final collectionDoc = await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionId)
          .get();

      if (!collectionDoc.exists) {
        throw Exception('Collection not found');
      }

      final collectionData = collectionDoc.data() as Map<String, dynamic>;

      // Get all recipes in collection
      final recipesSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('collectionRecipes')
          .doc(collectionId)
          .collection('recipes')
          .get();

      final recipes = recipesSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      // Create shared collection document
      await _db.collection('sharedCollections').doc(shareToken).set({
        'collectionId': collectionId,
        'userId': userId,
        'name': collectionData['name'],
        'description': collectionData['description'],
        'icon': collectionData['icon'],
        'color': collectionData['color'],
        'coverImageType': collectionData['coverImageType'],
        'recipes': recipes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update collection with share token
      await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionId)
          .update({
        'shareToken': shareToken,
        'isPublic': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Share link created: $shareToken");
      return shareToken;
    } catch (e) {
      print("❌ Error creating share link: $e");
      rethrow;
    }
  }

  /// Gets a shared collection by token
  Future<Map<String, dynamic>?> getSharedCollection(String shareToken) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('sharedCollections')
          .doc(shareToken)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("❌ Error getting shared collection: $e");
      return null;
    }
  }

  /// Revokes a share link
  Future<void> revokeShareLink(String userId, String collectionId) async {
    try {
      // Get collection to find share token
      final collectionDoc = await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionId)
          .get();

      if (!collectionDoc.exists) {
        throw Exception('Collection not found');
      }

      final collectionData = collectionDoc.data() as Map<String, dynamic>;
      final shareToken = collectionData['shareToken'];

      if (shareToken != null) {
        // Delete shared collection
        await _db.collection('sharedCollections').doc(shareToken).delete();
      }

      // Update collection
      await _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collectionId)
          .update({
        'shareToken': null,
        'isPublic': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Share link revoked");
    } catch (e) {
      print("❌ Error revoking share link: $e");
      rethrow;
    }
  }

  // ============================================================================
  // MIGRATION & SYNC
  // ============================================================================

  /// Migrates existing favorites to "All Favorites" collection (one-time)
  Future<void> migrateExistingFavorites(String userId) async {
    try {
      // Check if default collection already exists
      final collections = await getCollections(userId);
      if (collections.any((c) => c.isDefault)) {
        print('⏭️ Default collection already exists, skipping migration');
        return;
      }

      // Get all favorites
      final favorites = await getFavoriteRecipes(userId);

      if (favorites.isEmpty) {
        print('⏭️ No favorites to migrate');
        return;
      }

      // Create "All Favorites" collection
      final collectionRef = _db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc();

      await collectionRef.set({
        'name': 'All Favorites',
        'description': 'Your favorited recipes',
        'icon': 'favorite',
        'color': '#FF4757',
        'coverImageType': 'grid',
        'customCoverUrl': null,
        'isPinned': true,
        'isDefault': true,
        'sortOrder': 0,
        'recipeCount': favorites.length,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'shareToken': null,
        'isPublic': false,
      });

      // Batch add all favorites to collection
      final batch = _db.batch();
      for (final recipe in favorites) {
        final recipeRef = _db
            .collection('users')
            .doc(userId)
            .collection('collectionRecipes')
            .doc(collectionRef.id)
            .collection('recipes')
            .doc(recipe.id.toString());

        batch.set(recipeRef, {
          ...recipe.toMap(),
          'addedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      print('✅ Migrated ${favorites.length} favorites to default collection');
    } catch (e) {
      print('❌ Migration error: $e');
      // Don't throw - migration failure shouldn't block app
    }
  }

  /// Syncs favorites with "All Favorites" collection
  Future<void> syncFavoritesWithDefaultCollection(
    String userId,
    Recipe recipe,
    bool isAdding,
  ) async {
    try {
      // Get default collection
      final collections = await getCollections(userId);
      final defaultCollection = collections.where((c) => c.isDefault).firstOrNull;

      if (defaultCollection == null) {
        // No default collection yet, skip sync
        return;
      }

      if (isAdding) {
        await addRecipeToCollection(userId, defaultCollection.id, recipe);
      } else {
        await removeRecipeFromCollection(userId, defaultCollection.id, recipe.id);
      }
    } catch (e) {
      print('⚠️ Error syncing with default collection: $e');
      // Don't throw - sync failure shouldn't block favorites operation
    }
  }
}
