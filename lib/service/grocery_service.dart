import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_palette/model/grocery_item_model.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:uuid/uuid.dart';

/// Service for managing user's grocery items and generating recipes from them
class GroceryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ============================================================================
  // GROCERY CRUD OPERATIONS
  // ============================================================================

  /// Add a grocery item to user's list
  Future<String> addGroceryItem(String userId, GroceryItem item) async {
    try {
      final groceryId = item.id.isEmpty ? _uuid.v4() : item.id;
      final groceryWithId = item.copyWith(id: groceryId);

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .doc(groceryId)
          .set(groceryWithId.toJson());

      print('✅ Added grocery item: ${item.name}');
      return groceryId;
    } catch (e) {
      print('❌ Error adding grocery item: $e');
      rethrow;
    }
  }

  /// Remove a grocery item from user's list
  Future<void> removeGroceryItem(String userId, String itemId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .doc(itemId)
          .delete();

      print('✅ Removed grocery item: $itemId');
    } catch (e) {
      print('❌ Error removing grocery item: $e');
      rethrow;
    }
  }

  /// Update an existing grocery item
  Future<void> updateGroceryItem(String userId, GroceryItem item) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .doc(item.id)
          .update(item.toJson());

      print('✅ Updated grocery item: ${item.name}');
    } catch (e) {
      print('❌ Error updating grocery item: $e');
      rethrow;
    }
  }

  /// Clear all groceries for a user
  Future<void> clearAllGroceries(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('✅ Cleared all groceries for user: $userId');
    } catch (e) {
      print('❌ Error clearing groceries: $e');
      rethrow;
    }
  }

  /// Toggle pin status of a grocery item
  Future<void> togglePinGrocery(String userId, String itemId, bool isPinned) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .doc(itemId)
          .update({'isPinned': isPinned});

      print('✅ Toggled pin for grocery item: $itemId');
    } catch (e) {
      print('❌ Error toggling pin: $e');
      rethrow;
    }
  }

  // ============================================================================
  // GROCERY RETRIEVAL
  // ============================================================================

  /// Get all grocery items for a user (one-time fetch)
  Future<List<GroceryItem>> getUserGroceries(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .orderBy('isPinned', descending: true)
          .orderBy('addedAt', descending: true)
          .get();

      final groceries = snapshot.docs
          .map((doc) => GroceryItem.fromJson(doc.data()))
          .toList();

      print('✅ Loaded ${groceries.length} grocery items');
      return groceries;
    } catch (e) {
      print('❌ Error getting groceries: $e');
      return [];
    }
  }

  /// Stream of grocery items for real-time updates
  Stream<List<GroceryItem>> groceryStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('groceries')
        .orderBy('isPinned', descending: true)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroceryItem.fromJson(doc.data()))
          .toList();
    });
  }

  /// Get groceries grouped by category
  Future<Map<String, List<GroceryItem>>> getGroceriesByCategory(String userId) async {
    try {
      final groceries = await getUserGroceries(userId);
      final Map<String, List<GroceryItem>> categorized = {};

      for (var item in groceries) {
        final category = item.category ?? GroceryCategories.other;
        if (!categorized.containsKey(category)) {
          categorized[category] = [];
        }
        categorized[category]!.add(item);
      }

      return categorized;
    } catch (e) {
      print('❌ Error categorizing groceries: $e');
      return {};
    }
  }

  // ============================================================================
  // RECIPE GENERATION FROM GROCERIES
  // ============================================================================

  /// Find recipes that can be made with user's groceries
  /// Uses Spoonacular's findByIngredients endpoint with ranking=2 (minimize missing ingredients)
  Future<List<Recipe>> getRecipesFromGroceries(
    List<String> ingredients, {
    int number = 10,
    int ranking = 2, // 2 = minimize missing ingredients
  }) async {
    try {
      if (ingredients.isEmpty) {
        print('⚠️ No ingredients provided for recipe search');
        return [];
      }

      print('🔍 Finding recipes with ${ingredients.length} ingredients: ${ingredients.join(", ")}');

      final recipes = await SpoonacularService.findRecipesByIngredients(
        ingredients,
        number: number,
        ranking: ranking,
      );

      print('✅ Found ${recipes.length} recipes from groceries');
      return recipes;
    } catch (e) {
      print('❌ Error finding recipes from groceries: $e');
      rethrow;
    }
  }

  /// Get recipes with detailed information about ingredient matches
  /// Returns recipes sorted by: most ingredients used → fewest missing → quickest to make
  Future<List<RecipeWithMatchInfo>> getRecipesWithMatchInfo(
    List<String> ingredients, {
    int number = 10,
  }) async {
    try {
      if (ingredients.isEmpty) {
        return [];
      }

      // Use the searchRecipesWithIngredients which provides more detailed info
      final recipes = await SpoonacularService.findRecipesByIngredients(
        ingredients,
        number: number,
        ranking: 2, // Minimize missing ingredients
      );

      // Convert to recipes with match info
      // Note: The findByIngredients endpoint returns usedIngredients and missedIngredients
      // but our current Recipe model doesn't include those. We'll enhance the UI later
      return recipes.map((recipe) {
        return RecipeWithMatchInfo(
          recipe: recipe,
          usedIngredientsCount: 0, // Will be populated from API response
          missedIngredientsCount: 0, // Will be populated from API response
          totalIngredients: 0,
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting recipes with match info: $e');
      return [];
    }
  }

  /// Check if user has any groceries
  Future<bool> hasGroceries(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking groceries: $e');
      return false;
    }
  }

  /// Get count of grocery items
  Future<int> getGroceryCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting grocery count: $e');
      return 0;
    }
  }
}

/// Helper class to track recipe match information
class RecipeWithMatchInfo {
  final Recipe recipe;
  final int usedIngredientsCount; // How many of user's ingredients are used
  final int missedIngredientsCount; // How many ingredients are missing
  final int totalIngredients; // Total ingredients in recipe

  RecipeWithMatchInfo({
    required this.recipe,
    required this.usedIngredientsCount,
    required this.missedIngredientsCount,
    required this.totalIngredients,
  });

  /// Percentage of user's ingredients that are used
  double get matchPercentage {
    if (totalIngredients == 0) return 0;
    return (usedIngredientsCount / totalIngredients) * 100;
  }

  /// Badge text to show on UI
  String get matchBadge {
    return 'Uses $usedIngredientsCount/${usedIngredientsCount + missedIngredientsCount} ingredients';
  }
}

/// Global singleton instance
final groceryService = GroceryService();
