import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/recipe_model.dart';

class SpoonacularService {
  // IMPORTANT: Replace with your actual API key
  static const String _apiKey = '6f1a19d26a0246b4a35e1448ec4cb369';
  static const String _baseUrl = 'https://api.spoonacular.com';

  // Search Recipes
  static Future<List<Recipe>> searchRecipes({
    required String query,
    int number = 10,
    String? cuisine,
    String? diet,
  }) async {
    final url = Uri.parse('$_baseUrl/recipes/complexSearch').replace(
      queryParameters: {
        'apiKey': _apiKey,
        'query': query,
        'number': number.toString(),
        'addRecipeInformation': 'true',
        'fillIngredients': 'true',
        if (cuisine != null) 'cuisine': cuisine,
        if (diet != null) 'diet': diet,
      },
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        return results.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching recipes: $e');
    }
  }

  // Get Recipe Details
  static Future<RecipeDetail> getRecipeDetails(int recipeId) async {
    final url = Uri.parse('$_baseUrl/recipes/$recipeId/information').replace(
      queryParameters: {
        'apiKey': _apiKey,
        'includeNutrition': 'true',
      },
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return RecipeDetail.fromJson(data);
      } else {
        throw Exception('Failed to load recipe details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting recipe details: $e');
    }
  }

  // Get Random Recipes
  static Future<List<Recipe>> getRandomRecipes({int number = 10}) async {
    final url = Uri.parse('$_baseUrl/recipes/random').replace(
      queryParameters: {
        'apiKey': _apiKey,
        'number': number.toString(),
      },
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recipes = data['recipes'] as List;
        return recipes.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load random recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting random recipes: $e');
    }
  }

  // Get Similar Recipes
  static Future<List<Recipe>> getSimilarRecipes(int recipeId, {int number = 5}) async {
    final url = Uri.parse('$_baseUrl/recipes/$recipeId/similar').replace(
      queryParameters: {
        'apiKey': _apiKey,
        'number': number.toString(),
      },
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load similar recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting similar recipes: $e');
    }
  }

  // Search by Ingredients
  static Future<List<Recipe>> searchByIngredients({
    required List<String> ingredients,
    int number = 10,
  }) async {
    final url = Uri.parse('$_baseUrl/recipes/findByIngredients').replace(
      queryParameters: {
        'apiKey': _apiKey,
        'ingredients': ingredients.join(','),
        'number': number.toString(),
        'ranking': '2', // Maximize used ingredients
      },
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search by ingredients: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching by ingredients: $e');
    }
  }
}

