import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/ingredient_model.dart';
import 'package:meal_palette/model/instruction_step_model.dart';

/// Represents a user-created custom recipe
class CustomRecipe {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? imageUrl;
  final List<Ingredient> ingredients;
  final List<InstructionStep> instructions;
  final int? servings;
  final int? prepTime; // in minutes
  final int? cookTime; // in minutes
  final String? category; // 'breakfast', 'lunch', 'dinner', 'dessert', etc.
  final List<String> tags; // 'quick', 'easy', 'healthy', etc.
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublic; // For future sharing feature
  final String source; // 'manual', 'url', 'ocr'
  final String? sourceUrl; // If imported from URL
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final bool dairyFree;

  CustomRecipe({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.imageUrl,
    required this.ingredients,
    required this.instructions,
    this.servings,
    this.prepTime,
    this.cookTime,
    this.category,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.isPublic = false,
    this.source = 'manual',
    this.sourceUrl,
    this.vegetarian = false,
    this.vegan = false,
    this.glutenFree = false,
    this.dairyFree = false,
  });

  /// Total cooking time (prep + cook)
  int? get totalTime {
    if (prepTime == null && cookTime == null) return null;
    return (prepTime ?? 0) + (cookTime ?? 0);
  }

  /// Create CustomRecipe from JSON (Firestore)
  factory CustomRecipe.fromJson(Map<String, dynamic> json) {
    return CustomRecipe(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: (json['instructions'] as List<dynamic>?)
              ?.map((e) => InstructionStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      servings: json['servings'] as int?,
      prepTime: json['prepTime'] as int?,
      cookTime: json['cookTime'] as int?,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(json['updatedAt'] as String))
          : null,
      isPublic: json['isPublic'] as bool? ?? false,
      source: json['source'] as String? ?? 'manual',
      sourceUrl: json['sourceUrl'] as String?,
      vegetarian: json['vegetarian'] as bool? ?? false,
      vegan: json['vegan'] as bool? ?? false,
      glutenFree: json['glutenFree'] as bool? ?? false,
      dairyFree: json['dairyFree'] as bool? ?? false,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'instructions': instructions.map((e) => e.toMap()).toList(),
      'servings': servings,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'category': category,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isPublic': isPublic,
      'source': source,
      'sourceUrl': sourceUrl,
      'vegetarian': vegetarian,
      'vegan': vegan,
      'glutenFree': glutenFree,
      'dairyFree': dairyFree,
    };
  }

  /// Create from RecipeDetail (for saving extracted recipes)
  factory CustomRecipe.fromRecipeDetail({
    required String id,
    required String userId,
    required RecipeDetail recipe,
    String source = 'url',
    String? sourceUrl,
  }) {
    return CustomRecipe(
      id: id,
      userId: userId,
      title: recipe.title,
      description: recipe.summary,
      imageUrl: recipe.image,
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
      servings: recipe.servings,
      prepTime: null,
      cookTime: recipe.readyInMinutes,
      category: null,
      tags: [],
      createdAt: DateTime.now(),
      isPublic: false,
      source: source,
      sourceUrl: sourceUrl,
      vegetarian: recipe.vegetarian,
      vegan: recipe.vegan,
      glutenFree: recipe.glutenFree,
      dairyFree: recipe.dairyFree,
    );
  }

  /// Create a copy with updated fields
  CustomRecipe copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? imageUrl,
    List<Ingredient>? ingredients,
    List<InstructionStep>? instructions,
    int? servings,
    int? prepTime,
    int? cookTime,
    String? category,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? source,
    String? sourceUrl,
    bool? vegetarian,
    bool? vegan,
    bool? glutenFree,
    bool? dairyFree,
  }) {
    return CustomRecipe(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      servings: servings ?? this.servings,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      vegetarian: vegetarian ?? this.vegetarian,
      vegan: vegan ?? this.vegan,
      glutenFree: glutenFree ?? this.glutenFree,
      dairyFree: dairyFree ?? this.dairyFree,
    );
  }
}

/// Recipe categories
class RecipeCategories {
  static const String breakfast = 'breakfast';
  static const String lunch = 'lunch';
  static const String dinner = 'dinner';
  static const String dessert = 'dessert';
  static const String snack = 'snack';
  static const String appetizer = 'appetizer';
  static const String salad = 'salad';
  static const String soup = 'soup';
  static const String beverage = 'beverage';
  static const String other = 'other';

  static const List<String> all = [
    breakfast,
    lunch,
    dinner,
    dessert,
    snack,
    appetizer,
    salad,
    soup,
    beverage,
    other,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case breakfast:
        return 'Breakfast';
      case lunch:
        return 'Lunch';
      case dinner:
        return 'Dinner';
      case dessert:
        return 'Dessert';
      case snack:
        return 'Snack';
      case appetizer:
        return 'Appetizer';
      case salad:
        return 'Salad';
      case soup:
        return 'Soup';
      case beverage:
        return 'Beverage';
      case other:
        return 'Other';
      default:
        return category;
    }
  }

  static String getIcon(String category) {
    switch (category) {
      case breakfast:
        return '🍳';
      case lunch:
        return '🥗';
      case dinner:
        return '🍽️';
      case dessert:
        return '🍰';
      case snack:
        return '🍿';
      case appetizer:
        return '🥙';
      case salad:
        return '🥗';
      case soup:
        return '🍲';
      case beverage:
        return '☕';
      case other:
        return '🍴';
      default:
        return '🍴';
    }
  }
}

/// Common recipe tags
class RecipeTags {
  static const String quick = 'quick';
  static const String easy = 'easy';
  static const String healthy = 'healthy';
  static const String comfortFood = 'comfort-food';
  static const String kidFriendly = 'kid-friendly';
  static const String onePot = 'one-pot';
  static const String mealPrep = 'meal-prep';
  static const String budget = 'budget';
  static const String gourmet = 'gourmet';
  static const String seasonal = 'seasonal';

  static const List<String> all = [
    quick,
    easy,
    healthy,
    comfortFood,
    kidFriendly,
    onePot,
    mealPrep,
    budget,
    gourmet,
    seasonal,
  ];

  static String getDisplayName(String tag) {
    switch (tag) {
      case quick:
        return 'Quick';
      case easy:
        return 'Easy';
      case healthy:
        return 'Healthy';
      case comfortFood:
        return 'Comfort Food';
      case kidFriendly:
        return 'Kid-Friendly';
      case onePot:
        return 'One Pot';
      case mealPrep:
        return 'Meal Prep';
      case budget:
        return 'Budget-Friendly';
      case gourmet:
        return 'Gourmet';
      case seasonal:
        return 'Seasonal';
      default:
        return tag;
    }
  }
}
