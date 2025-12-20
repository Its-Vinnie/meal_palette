import 'package:meal_palette/model/ingredient_model.dart';
import 'package:meal_palette/model/instruction_step_model.dart';

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
