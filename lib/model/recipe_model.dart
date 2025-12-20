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
