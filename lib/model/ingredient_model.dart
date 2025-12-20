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

  /// Creates Ingredient from JSON data (API/Firestore)
  /// Safely handles type conversions for amount field
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      original: json['original'] ?? '',
      amount: _parseAmount(json['amount']),
      unit: json['unit'] ?? '',
    );
  }

  /// Safely parses amount to double from various types
  static double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  /// Converts Ingredient to Map for Firestore storage
  /// This method is CRITICAL for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'original': original,
      'amount': amount,
      'unit': unit,
    };
  }

  /// Converts to JSON (alias for toMap for consistency)
  Map<String, dynamic> toJson() => toMap();

  /// Creates a copy with updated fields
  /// Useful for modifications without changing the original object
  Ingredient copyWith({
    int? id,
    String? name,
    String? original,
    double? amount,
    String? unit,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      original: original ?? this.original,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
    );
  }

  /// Returns a formatted string of the ingredient
  /// Example: "2.5 cups of flour"
  String get formattedAmount {
    if (amount == 0 || unit.isEmpty) {
      return name;
    }
    return '$amount $unit of $name';
  }

  @override
  String toString() {
    return 'Ingredient(id: $id, name: $name, amount: $amount $unit)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Ingredient && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
