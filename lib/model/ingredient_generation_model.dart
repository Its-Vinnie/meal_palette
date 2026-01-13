/// Model for storing ingredient-based recipe generation history
class IngredientGeneration {
  final String id;
  final String userId;
  final List<String> ingredients;
  final DateTime createdAt;
  final int recipeCount; // Number of recipes generated

  IngredientGeneration({
    required this.id,
    required this.userId,
    required this.ingredients,
    required this.createdAt,
    this.recipeCount = 0,
  });

  /// Creates IngredientGeneration from Firestore data
  factory IngredientGeneration.fromJson(Map<String, dynamic> json) {
    return IngredientGeneration(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      recipeCount: json['recipeCount'] ?? 0,
    );
  }

  /// Converts to Map for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'ingredients': ingredients,
      'createdAt': createdAt.toIso8601String(),
      'recipeCount': recipeCount,
    };
  }

  /// Returns formatted date string
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
    }
  }

  /// Returns comma-separated ingredients (max 3 shown)
  String get ingredientsSummary {
    if (ingredients.isEmpty) return 'No ingredients';
    if (ingredients.length <= 3) {
      return ingredients.join(', ');
    }
    return '${ingredients.take(3).join(', ')}... +${ingredients.length - 3} more';
  }

  @override
  String toString() {
    return 'IngredientGeneration(id: $id, ingredients: ${ingredients.length}, date: $formattedDate)';
  }
}