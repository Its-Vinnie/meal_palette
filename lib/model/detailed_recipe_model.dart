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

  /// Creates RecipeDetail from JSON data (API/Firestore)
  /// Handles both API response format and Firestore format
   factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    //* Safe ID parsing
    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    // Parse ingredients
    List<Ingredient> ingredients = [];
    if (json['extendedIngredients'] != null) {
      ingredients = (json['extendedIngredients'] as List)
          .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (json['ingredients'] != null) {
      ingredients = (json['ingredients'] as List)
          .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    // Parse instructions
    List<InstructionStep> instructions = [];
    if (json['analyzedInstructions'] != null &&
        (json['analyzedInstructions'] as List).isNotEmpty) {
      final steps = json['analyzedInstructions'][0]['steps'] as List;
      instructions = steps
          .map((s) => InstructionStep.fromJson(s as Map<String, dynamic>))
          .toList();
    } else if (json['instructions'] != null) {
      instructions = (json['instructions'] as List)
          .map((s) => InstructionStep.fromJson(s as Map<String, dynamic>))
          .toList();
    }

     return RecipeDetail(
      id: parseId(json['id']),
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

  /// Converts RecipeDetail to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Always store as int
      'title': title,
      'image': image,
      'readyInMinutes': readyInMinutes,
      'servings': servings,
      'summary': summary,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions.map((i) => i.toMap()).toList(),
      'vegetarian': vegetarian,
      'vegan': vegan,
      'glutenFree': glutenFree,
      'dairyFree': dairyFree,
    };
  }
  /// Converts to JSON (alias for toMap for consistency)
  Map<String, dynamic> toJson() => toMap();

  /// Creates a copy with updated fields
  /// Useful for state management and updates
  RecipeDetail copyWith({
    int? id,
    String? title,
    String? image,
    int? readyInMinutes,
    int? servings,
    String? summary,
    List<Ingredient>? ingredients,
    List<InstructionStep>? instructions,
    bool? vegetarian,
    bool? vegan,
    bool? glutenFree,
    bool? dairyFree,
  }) {
    return RecipeDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      image: image ?? this.image,
      readyInMinutes: readyInMinutes ?? this.readyInMinutes,
      servings: servings ?? this.servings,
      summary: summary ?? this.summary,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      vegetarian: vegetarian ?? this.vegetarian,
      vegan: vegan ?? this.vegan,
      glutenFree: glutenFree ?? this.glutenFree,
      dairyFree: dairyFree ?? this.dairyFree,
    );
  }

  @override
  String toString() {
    return 'RecipeDetail(id: $id, title: $title, ingredients: ${ingredients.length}, instructions: ${instructions.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RecipeDetail && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}