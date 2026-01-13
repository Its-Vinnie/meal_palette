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

  /// Creates a Recipe object from JSON data
  /// UPDATED: Safe ID parsing
  factory Recipe.fromJson(Map<String, dynamic> json) {
    //* Safe ID parsing - handles both int and String
    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    return Recipe(
      id: parseId(json['id']),
      title: json['title'] ?? 'Unknown Recipe',
      image: json['image'],
      readyInMinutes: json['readyInMinutes'],
      servings: json['servings'],
      summary: json['summary'],
    );
  }

  /// Converts Recipe object to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Always store as int
      'title': title,
      'image': image,
      'readyInMinutes': readyInMinutes,
      'servings': servings,
      'summary': summary,
    };
  }

  /// Creates a copy of the Recipe with updated fields
  /// Useful for state management
  Recipe copyWith({
    int? id,
    String? title,
    String? image,
    int? readyInMinutes,
    int? servings,
    String? summary,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      image: image ?? this.image,
      readyInMinutes: readyInMinutes ?? this.readyInMinutes,
      servings: servings ?? this.servings,
      summary: summary ?? this.summary,
    );
  }
}