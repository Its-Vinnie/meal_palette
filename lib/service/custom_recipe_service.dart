import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:meal_palette/model/custom_recipe_model.dart';
import 'package:uuid/uuid.dart';

/// Service for managing user's custom recipes
class CustomRecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Create a new custom recipe
  Future<String> createRecipe(String userId, CustomRecipe recipe) async {
    try {
      final recipeId = recipe.id.isEmpty ? _uuid.v4() : recipe.id;
      final recipeWithId = recipe.copyWith(id: recipeId);

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('customRecipes')
          .doc(recipeId)
          .set(recipeWithId.toJson());

      print('✅ Created custom recipe: ${recipe.title}');
      return recipeId;
    } catch (e) {
      print('❌ Error creating recipe: $e');
      rethrow;
    }
  }

  /// Update an existing custom recipe
  Future<void> updateRecipe(String userId, CustomRecipe recipe) async {
    try {
      final updatedRecipe = recipe.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('customRecipes')
          .doc(recipe.id)
          .update(updatedRecipe.toJson());

      print('✅ Updated custom recipe: ${recipe.title}');
    } catch (e) {
      print('❌ Error updating recipe: $e');
      rethrow;
    }
  }

  /// Delete a custom recipe
  Future<void> deleteRecipe(String userId, String recipeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('customRecipes')
          .doc(recipeId)
          .delete();

      print('✅ Deleted custom recipe: $recipeId');
    } catch (e) {
      print('❌ Error deleting recipe: $e');
      rethrow;
    }
  }

  // ============================================================================
  // RETRIEVAL
  // ============================================================================

  /// Get all custom recipes for a user
  Future<List<CustomRecipe>> getUserRecipes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('customRecipes')
          .orderBy('createdAt', descending: true)
          .get();

      final recipes = snapshot.docs
          .map((doc) => CustomRecipe.fromJson(doc.data()))
          .toList();

      print('✅ Loaded ${recipes.length} custom recipes');
      return recipes;
    } catch (e) {
      print('❌ Error getting recipes: $e');
      return [];
    }
  }

  /// Get a single custom recipe by ID
  Future<CustomRecipe?> getRecipe(String userId, String recipeId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('customRecipes')
          .doc(recipeId)
          .get();

      if (!doc.exists) return null;

      return CustomRecipe.fromJson(doc.data()!);
    } catch (e) {
      print('❌ Error getting recipe: $e');
      return null;
    }
  }

  /// Stream of user's custom recipes (real-time updates)
  Stream<List<CustomRecipe>> userRecipesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('customRecipes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CustomRecipe.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get recipes by category
  Future<List<CustomRecipe>> getRecipesByCategory(
    String userId,
    String category,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('customRecipes')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CustomRecipe.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error getting recipes by category: $e');
      return [];
    }
  }

  /// Get recipes by tag
  Future<List<CustomRecipe>> getRecipesByTag(
    String userId,
    String tag,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('customRecipes')
          .where('tags', arrayContains: tag)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CustomRecipe.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error getting recipes by tag: $e');
      return [];
    }
  }

  /// Search recipes by title
  Future<List<CustomRecipe>> searchRecipes(
    String userId,
    String query,
  ) async {
    try {
      final allRecipes = await getUserRecipes(userId);

      // Client-side filtering (Firestore doesn't support case-insensitive search)
      final lowerQuery = query.toLowerCase();
      return allRecipes.where((recipe) {
        return recipe.title.toLowerCase().contains(lowerQuery) ||
            (recipe.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      print('❌ Error searching recipes: $e');
      return [];
    }
  }

  // ============================================================================
  // IMAGE UPLOAD
  // ============================================================================

  /// Upload recipe image to Firebase Storage
  Future<String> uploadRecipeImage(String userId, File imageFile) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref().child('users/$userId/recipes/$fileName');

      print('📤 Uploading recipe image...');

      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('✅ Image uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      rethrow;
    }
  }

  /// Delete recipe image from Firebase Storage
  Future<void> deleteRecipeImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Deleted recipe image');
    } catch (e) {
      print('❌ Error deleting image: $e');
      // Don't rethrow - image deletion failure shouldn't block recipe deletion
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get count of user's custom recipes
  Future<int> getRecipeCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('customRecipes')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting recipe count: $e');
      return 0;
    }
  }

  /// Check if user has any custom recipes
  Future<bool> hasRecipes(String userId) async {
    try {
      final count = await getRecipeCount(userId);
      return count > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get recipes grouped by category
  Future<Map<String, List<CustomRecipe>>> getRecipesGroupedByCategory(
    String userId,
  ) async {
    try {
      final recipes = await getUserRecipes(userId);
      final Map<String, List<CustomRecipe>> grouped = {};

      for (var recipe in recipes) {
        final category = recipe.category ?? 'other';
        if (!grouped.containsKey(category)) {
          grouped[category] = [];
        }
        grouped[category]!.add(recipe);
      }

      return grouped;
    } catch (e) {
      print('❌ Error grouping recipes: $e');
      return {};
    }
  }
}

/// Global singleton instance
final customRecipeService = CustomRecipeService();
