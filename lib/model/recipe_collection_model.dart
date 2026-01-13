import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Model representing a recipe collection
/// Users can organize their favorite recipes into custom collections
class RecipeCollection {
  final String id;
  final String name;
  final String? description;
  final String icon; // Icon code (e.g., "favorite", "restaurant")
  final String color; // Hex color code (e.g., "#FF4757")
  final String coverImageType; // "grid", "first", "custom"
  final String? customCoverUrl;
  final bool isPinned;
  final bool isDefault; // True only for "All Favorites" collection
  final int sortOrder;
  final int recipeCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? shareToken; // Unique token for sharing (null if not shared)
  final bool isPublic;

  RecipeCollection({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    this.coverImageType = 'grid',
    this.customCoverUrl,
    this.isPinned = false,
    this.isDefault = false,
    required this.sortOrder,
    this.recipeCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.shareToken,
    this.isPublic = false,
  });

  /// Safe DateTime parsing - handles Firestore Timestamp, String, and DateTime
  static DateTime _parseDateTime(dynamic value) {
    try {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      return DateTime.now();
    } catch (e) {
      print('⚠️ Error parsing DateTime: $e, using current time');
      return DateTime.now();
    }
  }

  /// Creates a RecipeCollection from Firestore JSON data
  factory RecipeCollection.fromJson(Map<String, dynamic> json, String docId) {
    return RecipeCollection(
      id: docId,
      name: json['name'] ?? 'Untitled Collection',
      description: json['description'],
      icon: json['icon'] ?? 'favorite',
      color: json['color'] ?? '#FF4757',
      coverImageType: json['coverImageType'] ?? 'grid',
      customCoverUrl: json['customCoverUrl'],
      isPinned: json['isPinned'] ?? false,
      isDefault: json['isDefault'] ?? false,
      sortOrder: json['sortOrder'] ?? 0,
      recipeCount: json['recipeCount'] ?? 0,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      shareToken: json['shareToken'],
      isPublic: json['isPublic'] ?? false,
    );
  }

  /// Converts RecipeCollection to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'coverImageType': coverImageType,
      'customCoverUrl': customCoverUrl,
      'isPinned': isPinned,
      'isDefault': isDefault,
      'sortOrder': sortOrder,
      'recipeCount': recipeCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'shareToken': shareToken,
      'isPublic': isPublic,
    };
  }

  /// Creates a copy of the collection with updated fields
  RecipeCollection copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? color,
    String? coverImageType,
    String? customCoverUrl,
    bool? isPinned,
    bool? isDefault,
    int? sortOrder,
    int? recipeCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? shareToken,
    bool? isPublic,
  }) {
    return RecipeCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      coverImageType: coverImageType ?? this.coverImageType,
      customCoverUrl: customCoverUrl ?? this.customCoverUrl,
      isPinned: isPinned ?? this.isPinned,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      recipeCount: recipeCount ?? this.recipeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      shareToken: shareToken ?? this.shareToken,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  /// Formatted creation date for display
  String get formattedDate {
    return DateFormat('MMM d, yyyy').format(createdAt);
  }

  /// Get Color object from hex string
  Color get colorValue {
    try {
      final hexColor = color.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      print('⚠️ Error parsing color $color: $e');
      return const Color(0xFFFF4757); // Default red color
    }
  }

  /// Get IconData from icon code
  IconData get iconData {
    return CollectionIcons.fromCode(icon);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeCollection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RecipeCollection(id: $id, name: $name, recipeCount: $recipeCount, isPinned: $isPinned, isDefault: $isDefault)';
  }
}

/// Helper class for collection icon codes and IconData mapping
class CollectionIcons {
  static const Map<String, IconData> _iconMap = {
    'favorite': Icons.favorite,
    'restaurant': Icons.restaurant,
    'local_dining': Icons.local_dining,
    'restaurant_menu': Icons.restaurant_menu,
    'breakfast_dining': Icons.breakfast_dining,
    'lunch_dining': Icons.lunch_dining,
    'dinner_dining': Icons.dinner_dining,
    'cake': Icons.cake,
    'coffee': Icons.coffee,
    'fastfood': Icons.fastfood,
    'local_pizza': Icons.local_pizza,
    'icecream': Icons.icecream,
    'emoji_food_beverage': Icons.emoji_food_beverage,
    'ramen_dining': Icons.ramen_dining,
    'soup_kitchen': Icons.soup_kitchen,
    'local_cafe': Icons.local_cafe,
    'liquor': Icons.liquor,
    'tapas': Icons.tapas,
    'bakery_dining': Icons.bakery_dining,
    'set_meal': Icons.set_meal,
    'brunch_dining': Icons.brunch_dining,
    'outdoor_grill': Icons.outdoor_grill,
  };

  /// Get IconData from icon code string
  static IconData fromCode(String code) {
    return _iconMap[code] ?? Icons.bookmark;
  }

  /// Get icon code from IconData
  static String toCode(IconData iconData) {
    for (var entry in _iconMap.entries) {
      if (entry.value == iconData) {
        return entry.key;
      }
    }
    return 'bookmark';
  }

  /// Get list of all available icons for picker
  static List<MapEntry<String, IconData>> get allIcons {
    return _iconMap.entries.toList();
  }
}

/// Helper class for collection color presets
class CollectionColors {
  static const List<Color> presets = [
    Color(0xFFFF4757), // Red (default)
    Color(0xFFFF6348), // Orange
    Color(0xFFFFBE0B), // Yellow
    Color(0xFF1DD1A1), // Green
    Color(0xFF10AC84), // Teal
    Color(0xFF0ABDE3), // Blue
    Color(0xFF5F27CD), // Purple
    Color(0xFF9C27B0), // Deep Purple
    Color(0xFFE91E63), // Pink
    Color(0xFFFF7979), // Light Red
    Color(0xFFBADC58), // Lime
    Color(0xFF48DBFB), // Sky Blue
  ];

  /// Convert Color to hex string
  static String toHex(Color color) {
    final alpha = color.a.toInt();
    final red = color.r.toInt();
    final green = color.g.toInt();
    final blue = color.b.toInt();
    return '#${red.toRadixString(16).padLeft(2, '0')}${green.toRadixString(16).padLeft(2, '0')}${blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  /// Convert hex string to Color
  static Color fromHex(String hex) {
    try {
      final hexColor = hex.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      print('⚠️ Error parsing hex color $hex: $e');
      return const Color(0xFFFF4757);
    }
  }
}
