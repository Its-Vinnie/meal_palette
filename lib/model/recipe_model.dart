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
  /// Used when receiving data from API or Firestore
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

  /// Converts Recipe object to Map for Firestore storage
  /// This is crucial for saving to Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
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