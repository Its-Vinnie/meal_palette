import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/recipe_model.dart';

/// Service for interacting with Spoonacular API
/// Handles all recipe-related API calls
class SpoonacularService {
  //* API Configuration
  static const String _apiKey = '6f1a19d26a0246b4a35e1448ec4cb369';
  static const String _baseUrl = 'https://api.spoonacular.com';

  // ============================================================================
  // RECIPE SEARCH
  // ============================================================================

  /// Search recipes by query
  static Future<List<Recipe>> searchRecipes(
    String query, {
    int number = 10,
    String? diet,
    String? cuisine,
    String? type,
    int? maxReadyTime,
    List<String>? intolerances,
  }) async {
    try {
      var urlString = '$_baseUrl/recipes/complexSearch?apiKey=$_apiKey&query=$query&number=$number&addRecipeInformation=true';

      // Add diet filter (vegetarian, vegan, glutenFree, ketogenic, paleo, etc.)
      if (diet != null && diet.isNotEmpty) {
        urlString += '&diet=$diet';
      }

      // Add cuisine filter (african, american, british, cajun, caribbean, chinese, etc.)
      if (cuisine != null && cuisine.isNotEmpty) {
        urlString += '&cuisine=$cuisine';
      }

      // Add meal type filter (main course, side dish, dessert, appetizer, breakfast, etc.)
      if (type != null && type.isNotEmpty) {
        urlString += '&type=$type';
      }

      // Add max cooking time filter (in minutes)
      if (maxReadyTime != null) {
        urlString += '&maxReadyTime=$maxReadyTime';
      }

      // Add intolerances filter (gluten, dairy, egg, etc.)
      if (intolerances != null && intolerances.isNotEmpty) {
        urlString += '&intolerances=${intolerances.join(',')}';
      }

      final url = Uri.parse(urlString);
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search recipes: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error searching recipes: $e');
      rethrow;
    }
  }

  // ============================================================================
  // INGREDIENT-BASED RECIPE SEARCH
  // ============================================================================

  /// Find recipes by ingredients (NEW)
  /// This is the main method for ingredient-based generation
  static Future<List<Recipe>> findRecipesByIngredients(
    List<String> ingredients, {
    int number = 10,
    int ranking = 1, // 1 = maximize used ingredients, 2 = minimize missing ingredients
    bool ignorePantry = true,
  }) async {
    try {
      // Join ingredients with comma
      final ingredientString = ingredients.join(',');

      final url = Uri.parse(
        '$_baseUrl/recipes/findByIngredients?apiKey=$_apiKey&ingredients=$ingredientString&number=$number&ranking=$ranking&ignorePantry=$ignorePantry',
      );

      print('🔍 Searching recipes with ingredients: $ingredientString');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);

        // Convert to Recipe objects
        // Note: This endpoint returns slightly different format
        return results.map((json) {
          return Recipe(
            id: json['id'],
            title: json['title'] ?? 'Unknown Recipe',
            image: json['image'],
            readyInMinutes: null, // Not provided by this endpoint
            servings: null, // Not provided by this endpoint
            summary: null, // Not provided by this endpoint
          );
        }).toList();
      } else if (response.statusCode == 402) {
        throw Exception('API quota exceeded. Please try again tomorrow.');
      } else {
        throw Exception(
          'Failed to find recipes by ingredients: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error finding recipes by ingredients: $e');
      rethrow;
    }
  }

  /// Search recipes with ingredient filters (Alternative method)
  static Future<List<Recipe>> searchRecipesWithIngredients(
    List<String> includeIngredients, {
    List<String>? excludeIngredients,
    int number = 10,
    String? diet, // vegetarian, vegan, etc.
    String? intolerances, // gluten, dairy, etc.
  }) async {
    try {
      var url = '$_baseUrl/recipes/complexSearch?apiKey=$_apiKey&number=$number';
      
      // Add include ingredients
      if (includeIngredients.isNotEmpty) {
        url += '&includeIngredients=${includeIngredients.join(',')}';
      }
      
      // Add exclude ingredients
      if (excludeIngredients != null && excludeIngredients.isNotEmpty) {
        url += '&excludeIngredients=${excludeIngredients.join(',')}';
      }
      
      // Add diet filter
      if (diet != null) {
        url += '&diet=$diet';
      }
      
      // Add intolerances
      if (intolerances != null) {
        url += '&intolerances=$intolerances';
      }

      url += '&addRecipeInformation=true';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        return results.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search recipes: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error searching recipes with ingredients: $e');
      rethrow;
    }
  }

  // ============================================================================
  // RECIPE DETAILS
  // ============================================================================

  /// Get detailed recipe information by ID
  static Future<RecipeDetail> getRecipeDetails(int recipeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/recipes/$recipeId/information?apiKey=$_apiKey&includeNutrition=false',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return RecipeDetail.fromJson(data);
      } else if (response.statusCode == 402) {
        throw Exception('API quota exceeded');
      } else {
        throw Exception(
          'Failed to get recipe details: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error getting recipe details: $e');
      rethrow;
    }
  }

  // ============================================================================
  // BULK OPERATIONS
  // ============================================================================

  /// Get bulk recipe information (up to 100 recipes at once)
  static Future<List<RecipeDetail>> getBulkRecipeInformation(
    List<int> recipeIds,
  ) async {
    try {
      final idsString = recipeIds.join(',');
      
      final url = Uri.parse(
        '$_baseUrl/recipes/informationBulk?apiKey=$_apiKey&ids=$idsString',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        return results.map((json) => RecipeDetail.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get bulk recipes: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting bulk recipes: $e');
      rethrow;
    }
  }

  // ============================================================================
  // RANDOM RECIPES
  // ============================================================================

  /// Get random recipes with user preference filtering
  /// The /random endpoint uses 'tags' parameter with comma-separated values
  static Future<List<Recipe>> getRandomRecipes({
    int number = 10,
    String? tags,
    String? diet,
    String? cuisine,
    String? type,
    int? maxReadyTime,
    List<String>? intolerances,
    List<String>? mealTypes,
  }) async {
    try {
      // Request more recipes to account for client-side filtering
      final requestNumber = maxReadyTime != null ? number * 2 : number;
      var url = '$_baseUrl/recipes/random?apiKey=$_apiKey&number=$requestNumber';

      // Combine all tags into a single comma-separated string
      // The Spoonacular random endpoint supports: diet, cuisine, meal type
      final tagsList = <String>[];

      if (tags != null && tags.isNotEmpty) {
        tagsList.add(tags);
      }

      // Add diet filter (vegetarian, vegan, etc.)
      if (diet != null && diet.isNotEmpty) {
        tagsList.add(diet);
      }

      // Add cuisine filter (italian, mexican, etc.)
      if (cuisine != null && cuisine.isNotEmpty) {
        tagsList.add(cuisine);
      }

      // Add meal type filter (breakfast, lunch, dinner, etc.)
      if (type != null && type.isNotEmpty) {
        tagsList.add(type);
      }

      // Add additional meal types from preferences
      if (mealTypes != null && mealTypes.isNotEmpty) {
        // Only add first meal type to avoid over-filtering
        final primaryMealType = mealTypes.first;
        if (!tagsList.contains(primaryMealType)) {
          tagsList.add(primaryMealType);
        }
      }

      // Add all tags as single comma-separated parameter
      if (tagsList.isNotEmpty) {
        url += '&tags=${tagsList.join(',')}';
      }

      print('Fetching random recipes with tags: ${tagsList.join(', ')}');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['recipes'] ?? [];

        // Filter by maxReadyTime if specified
        var recipes = results.map((json) {
          return Recipe(
            id: json['id'],
            title: json['title'] ?? 'Unknown Recipe',
            image: json['image'],
            readyInMinutes: json['readyInMinutes'],
            servings: json['servings'],
            summary: json['summary'],
          );
        }).toList();

        // Client-side filter for max ready time
        if (maxReadyTime != null) {
          recipes = recipes.where((recipe) {
            return recipe.readyInMinutes == null ||
                   recipe.readyInMinutes! <= maxReadyTime;
          }).toList();
        }

        // Client-side filter for intolerances (not supported by random endpoint)
        // We'll need to filter out recipes that might contain these ingredients
        // This is a best-effort approach since we don't have full ingredient data

        // Limit to requested number
        if (recipes.length > number) {
          recipes = recipes.take(number).toList();
        }

        print('Got ${recipes.length} recipes after filtering');
        return recipes;
      } else if (response.statusCode == 402) {
        throw Exception('API quota exceeded');
      } else {
        throw Exception('Failed to get random recipes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting random recipes: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SIMILAR RECIPES
  // ============================================================================

  /// Get similar recipes to a given recipe
  static Future<List<Recipe>> getSimilarRecipes(int recipeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/recipes/$recipeId/similar?apiKey=$_apiKey&number=10',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        
        return results.map((json) {
          return Recipe(
            id: json['id'],
            title: json['title'] ?? 'Unknown Recipe',
            image: null,
            readyInMinutes: json['readyInMinutes'],
            servings: json['servings'],
            summary: null,
          );
        }).toList();
      } else {
        throw Exception('Failed to get similar recipes: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting similar recipes: $e');
      rethrow;
    }
  }

  // ============================================================================
  // AUTOCOMPLETE
  // ============================================================================

  /// Autocomplete recipe search (for search suggestions)
  static Future<List<String>> autocompleteRecipeSearch(
    String query, {
    int number = 10,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/recipes/autocomplete?apiKey=$_apiKey&query=$query&number=$number',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        return results.map((json) => json['title'] as String).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error in autocomplete: $e');
      return [];
    }
  }

  /// Autocomplete ingredient search
  static Future<List<String>> autocompleteIngredientSearch(
    String query, {
    int number = 10,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/food/ingredients/autocomplete?apiKey=$_apiKey&query=$query&number=$number&metaInformation=false',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        return results.map((json) => json['name'] as String).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error in ingredient autocomplete: $e');
      return [];
    }
  }

  // ============================================================================
  // MEAL PLANNING
  // ============================================================================

  /// Generate a meal plan based on dietary requirements
  static Future<Map<String, dynamic>> generateMealPlan({
    required String timeFrame, // day, week
    int? targetCalories,
    String? diet,
    String? exclude,
  }) async {
    try {
      var url = '$_baseUrl/mealplanner/generate?apiKey=$_apiKey&timeFrame=$timeFrame';
      
      if (targetCalories != null) {
        url += '&targetCalories=$targetCalories';
      }
      
      if (diet != null) {
        url += '&diet=$diet';
      }
      
      if (exclude != null) {
        url += '&exclude=$exclude';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to generate meal plan: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error generating meal plan: $e');
      rethrow;
    }
  }
}