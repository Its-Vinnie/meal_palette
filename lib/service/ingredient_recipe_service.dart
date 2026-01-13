import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_palette/model/ingredient_generation_model.dart';

/// Service for managing ingredient-based recipe generations
/// Handles saving/retrieving generation history
class IngredientRecipeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================================
  // INGREDIENT GENERATION HISTORY
  // ============================================================================

  /// Save an ingredient generation to user's history
  Future<void> saveIngredientGeneration(
    String userId,
    List<String> ingredients,
  ) async {
    try {
      final generation = IngredientGeneration(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        ingredients: ingredients,
        createdAt: DateTime.now(),
      );

      await _db
          .collection('users')
          .doc(userId)
          .collection('ingredientGenerations')
          .doc(generation.id)
          .set(generation.toJson());

      print('✅ Saved ingredient generation to history');
    } catch (e) {
      print('❌ Error saving ingredient generation: $e');
      rethrow;
    }
  }

  /// Get user's ingredient generation history
  Future<List<IngredientGeneration>> getGenerationHistory(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('ingredientGenerations')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => IngredientGeneration.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error getting generation history: $e');
      return [];
    }
  }

  /// Stream of generation history for real-time updates
  Stream<List<IngredientGeneration>> generationHistoryStream(
    String userId,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('ingredientGenerations')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => IngredientGeneration.fromJson(doc.data()))
              .toList();
        });
  }

  /// Delete a generation from history
  Future<void> deleteGeneration(String userId, String generationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('ingredientGenerations')
          .doc(generationId)
          .delete();

      print('✅ Deleted generation from history');
    } catch (e) {
      print('❌ Error deleting generation: $e');
      rethrow;
    }
  }

  /// Clear all generation history
  Future<void> clearAllHistory(String userId) async {
    try {
      final batch = _db.batch();
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('ingredientGenerations')
          .get();

      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ Cleared all generation history');
    } catch (e) {
      print('❌ Error clearing history: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SAVED MEAL PLANS
  // ============================================================================

  /// Save a meal plan (collection of recipes) for later
  Future<void> saveMealPlan({
    required String userId,
    required String name,
    required List<int> recipeIds,
    required List<String> ingredients,
  }) async {
    try {
      final mealPlanId = DateTime.now().millisecondsSinceEpoch.toString();

      await _db
          .collection('users')
          .doc(userId)
          .collection('mealPlans')
          .doc(mealPlanId)
          .set({
            'id': mealPlanId,
            'name': name,
            'recipeIds': recipeIds,
            'ingredients': ingredients,
            'createdAt': FieldValue.serverTimestamp(),
          });

      print('✅ Saved meal plan: $name');
    } catch (e) {
      print('❌ Error saving meal plan: $e');
      rethrow;
    }
  }

  /// Get user's saved meal plans
  Future<List<Map<String, dynamic>>> getMealPlans(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('mealPlans')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('❌ Error getting meal plans: $e');
      return [];
    }
  }

  /// Delete a meal plan
  Future<void> deleteMealPlan(String userId, String mealPlanId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('mealPlans')
          .doc(mealPlanId)
          .delete();

      print('✅ Deleted meal plan');
    } catch (e) {
      print('❌ Error deleting meal plan: $e');
      rethrow;
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get total number of generations for user
  Future<int> getTotalGenerations(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('ingredientGenerations')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting generation count: $e');
      return 0;
    }
  }

  /// Get most frequently used ingredients
  Future<Map<String, int>> getMostUsedIngredients(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final generations = await getGenerationHistory(userId, limit: 100);
      
      final Map<String, int> ingredientCounts = {};
      
      for (var generation in generations) {
        for (var ingredient in generation.ingredients) {
          final normalized = ingredient.toLowerCase().trim();
          ingredientCounts[normalized] = 
              (ingredientCounts[normalized] ?? 0) + 1;
        }
      }

      // Sort by count and return top N
      final sorted = ingredientCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return Map.fromEntries(sorted.take(limit));
    } catch (e) {
      print('❌ Error getting ingredient stats: $e');
      return {};
    }
  }
}