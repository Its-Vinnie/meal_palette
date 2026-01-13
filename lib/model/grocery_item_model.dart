import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a grocery item that the user has at home
class GroceryItem {
  final String id;
  final String name;
  final String? category; // 'vegetables', 'meat', 'dairy', 'grains', etc.
  final double? quantity;
  final String? unit; // 'cups', 'lbs', 'pieces', 'oz', etc.
  final DateTime addedAt;
  final bool isPinned; // Keep certain items always visible

  GroceryItem({
    required this.id,
    required this.name,
    this.category,
    this.quantity,
    this.unit,
    required this.addedAt,
    this.isPinned = false,
  });

  /// Create GroceryItem from JSON
  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
      unit: json['unit'] as String?,
      addedAt: json['addedAt'] is Timestamp
          ? (json['addedAt'] as Timestamp).toDate()
          : DateTime.parse(json['addedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  /// Convert GroceryItem to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'addedAt': Timestamp.fromDate(addedAt),
      'isPinned': isPinned,
    };
  }

  /// Create a copy with updated fields
  GroceryItem copyWith({
    String? id,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    DateTime? addedAt,
    bool? isPinned,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      addedAt: addedAt ?? this.addedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  String toString() {
    final quantityStr = quantity != null && unit != null
        ? '$quantity $unit of '
        : quantity != null
            ? '$quantity '
            : '';
    return '$quantityStr$name';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Common grocery categories for organization
class GroceryCategories {
  static const String vegetables = 'vegetables';
  static const String fruits = 'fruits';
  static const String meat = 'meat';
  static const String seafood = 'seafood';
  static const String dairy = 'dairy';
  static const String grains = 'grains';
  static const String spices = 'spices';
  static const String condiments = 'condiments';
  static const String beverages = 'beverages';
  static const String other = 'other';

  static const List<String> all = [
    vegetables,
    fruits,
    meat,
    seafood,
    dairy,
    grains,
    spices,
    condiments,
    beverages,
    other,
  ];

  /// Get display name for category
  static String getDisplayName(String category) {
    switch (category) {
      case vegetables:
        return 'Vegetables';
      case fruits:
        return 'Fruits';
      case meat:
        return 'Meat & Poultry';
      case seafood:
        return 'Seafood';
      case dairy:
        return 'Dairy & Eggs';
      case grains:
        return 'Grains & Pasta';
      case spices:
        return 'Spices & Herbs';
      case condiments:
        return 'Condiments & Sauces';
      case beverages:
        return 'Beverages';
      case other:
        return 'Other';
      default:
        return category;
    }
  }

  /// Get category icon emoji
  static String getIcon(String category) {
    switch (category) {
      case vegetables:
        return '🥬';
      case fruits:
        return '🍎';
      case meat:
        return '🍖';
      case seafood:
        return '🐟';
      case dairy:
        return '🥛';
      case grains:
        return '🌾';
      case spices:
        return '🌿';
      case condiments:
        return '🧂';
      case beverages:
        return '☕';
      case other:
        return '📦';
      default:
        return '📦';
    }
  }
}

/// Common measurement units
class MeasurementUnits {
  static const String cups = 'cups';
  static const String tablespoons = 'tbsp';
  static const String teaspoons = 'tsp';
  static const String pounds = 'lbs';
  static const String ounces = 'oz';
  static const String grams = 'g';
  static const String kilograms = 'kg';
  static const String pieces = 'pieces';
  static const String liters = 'L';
  static const String milliliters = 'mL';

  static const List<String> all = [
    cups,
    tablespoons,
    teaspoons,
    pounds,
    ounces,
    grams,
    kilograms,
    pieces,
    liters,
    milliliters,
  ];
}
