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