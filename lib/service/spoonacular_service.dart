import 'dart:convert';
import 'package:http/http.dart' as http;

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

// Recipe Model (Basic)
class Recipe {
  final int id;
  final String title;
  final String? image;
  final int? readyInMinutes;
  final int? servings;
  final String? summary;

  Recipe({
    required this.id,
    required this.title,
    this.image,
    this.readyInMinutes,
    this.servings,
    this.summary,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown Recipe',
      image: json['image'],
      readyInMinutes: json['readyInMinutes'],
      servings: json['servings'],
      summary: json['summary'],
    );
  }
}

// Detailed Recipe Model
class RecipeDetail {
  final int id;
  final String title;
  final String? image;
  final int readyInMinutes;
  final int servings;
  final String summary;
  final List<Ingredient> ingredients;
  final List<InstructionStep> instructions;
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final bool dairyFree;

  RecipeDetail({
    required this.id,
    required this.title,
    this.image,
    required this.readyInMinutes,
    required this.servings,
    required this.summary,
    required this.ingredients,
    required this.instructions,
    required this.vegetarian,
    required this.vegan,
    required this.glutenFree,
    required this.dairyFree,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    // Parse ingredients
    List<Ingredient> ingredients = [];
    if (json['extendedIngredients'] != null) {
      ingredients = (json['extendedIngredients'] as List)
          .map((i) => Ingredient.fromJson(i))
          .toList();
    }

    // Parse instructions
    List<InstructionStep> instructions = [];
    if (json['analyzedInstructions'] != null && 
        (json['analyzedInstructions'] as List).isNotEmpty) {
      final steps = json['analyzedInstructions'][0]['steps'] as List;
      instructions = steps.map((s) => InstructionStep.fromJson(s)).toList();
    }

    return RecipeDetail(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown Recipe',
      image: json['image'],
      readyInMinutes: json['readyInMinutes'] ?? 0,
      servings: json['servings'] ?? 0,
      summary: json['summary'] ?? '',
      ingredients: ingredients,
      instructions: instructions,
      vegetarian: json['vegetarian'] ?? false,
      vegan: json['vegan'] ?? false,
      glutenFree: json['glutenFree'] ?? false,
      dairyFree: json['dairyFree'] ?? false,
    );
  }
}

// Ingredient Model
class Ingredient {
  final int id;
  final String name;
  final String original;
  final double amount;
  final String unit;

  Ingredient({
    required this.id,
    required this.name,
    required this.original,
    required this.amount,
    required this.unit,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      original: json['original'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
    );
  }
}

// Instruction Step Model
class InstructionStep {
  final int number;
  final String step;

  InstructionStep({
    required this.number,
    required this.step,
  });

  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    return InstructionStep(
      number: json['number'] ?? 0,
      step: json['step'] ?? '',
    );
  }
}
