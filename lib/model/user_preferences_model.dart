import 'package:cloud_firestore/cloud_firestore.dart';

/// User preferences for personalizing recipe recommendations
class UserPreferences {
  final List<String> dietaryRestrictions;
  final List<String> cuisinePreferences;
  final String skillLevel;
  final List<String> mealTypePreferences;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserPreferences({
    required this.dietaryRestrictions,
    required this.cuisinePreferences,
    required this.skillLevel,
    required this.mealTypePreferences,
    required this.createdAt,
    this.updatedAt,
  });

  /// Default preferences for new users
  static UserPreferences get defaultPreferences => UserPreferences(
        dietaryRestrictions: [],
        cuisinePreferences: [],
        skillLevel: 'intermediate',
        mealTypePreferences: [],
        createdAt: DateTime.now(),
      );

  /// Create from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      dietaryRestrictions: (json['dietaryRestrictions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      cuisinePreferences: (json['cuisinePreferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      skillLevel: json['skillLevel'] as String? ?? 'intermediate',
      mealTypePreferences: (json['mealTypePreferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? _parseDateTime(json['updatedAt']) : null,
    );
  }

  /// Helper method to parse DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.now();
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'dietaryRestrictions': dietaryRestrictions,
      'cuisinePreferences': cuisinePreferences,
      'skillLevel': skillLevel,
      'mealTypePreferences': mealTypePreferences,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Create copy with modifications
  UserPreferences copyWith({
    List<String>? dietaryRestrictions,
    List<String>? cuisinePreferences,
    String? skillLevel,
    List<String>? mealTypePreferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      cuisinePreferences: cuisinePreferences ?? this.cuisinePreferences,
      skillLevel: skillLevel ?? this.skillLevel,
      mealTypePreferences: mealTypePreferences ?? this.mealTypePreferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if user has completed onboarding
  bool get hasCompletedOnboarding {
    return cuisinePreferences.isNotEmpty || mealTypePreferences.isNotEmpty;
  }

  /// Get max ready time based on skill level
  int? get maxReadyTime {
    switch (skillLevel) {
      case 'beginner':
        return 30;
      case 'intermediate':
        return 60;
      case 'advanced':
        return null; // No limit
      default:
        return 60;
    }
  }

  @override
  String toString() {
    return 'UserPreferences(dietary: $dietaryRestrictions, cuisine: $cuisinePreferences, skill: $skillLevel, meals: $mealTypePreferences)';
  }
}

/// Available dietary restrictions
class DietaryRestrictions {
  static const String vegetarian = 'vegetarian';
  static const String vegan = 'vegan';
  static const String glutenFree = 'glutenFree';
  static const String dairyFree = 'dairyFree';
  static const String ketogenic = 'ketogenic';
  static const String paleo = 'paleo';
  static const String pescatarian = 'pescatarian';
  static const String whole30 = 'whole30';

  static const List<String> all = [
    vegetarian,
    vegan,
    glutenFree,
    dairyFree,
    ketogenic,
    paleo,
    pescatarian,
    whole30,
  ];

  static String getDisplayName(String restriction) {
    switch (restriction) {
      case vegetarian:
        return 'Vegetarian';
      case vegan:
        return 'Vegan';
      case glutenFree:
        return 'Gluten-Free';
      case dairyFree:
        return 'Dairy-Free';
      case ketogenic:
        return 'Keto';
      case paleo:
        return 'Paleo';
      case pescatarian:
        return 'Pescatarian';
      case whole30:
        return 'Whole30';
      default:
        return restriction;
    }
  }
}

/// Available cuisine types
class CuisineTypes {
  static const String african = 'african';
  static const String american = 'american';
  static const String british = 'british';
  static const String cajun = 'cajun';
  static const String caribbean = 'caribbean';
  static const String chinese = 'chinese';
  static const String easternEuropean = 'eastern european';
  static const String european = 'european';
  static const String french = 'french';
  static const String german = 'german';
  static const String greek = 'greek';
  static const String indian = 'indian';
  static const String irish = 'irish';
  static const String italian = 'italian';
  static const String japanese = 'japanese';
  static const String jewish = 'jewish';
  static const String korean = 'korean';
  static const String latinAmerican = 'latin american';
  static const String mediterranean = 'mediterranean';
  static const String mexican = 'mexican';
  static const String middleEastern = 'middle eastern';
  static const String nordic = 'nordic';
  static const String southern = 'southern';
  static const String spanish = 'spanish';
  static const String thai = 'thai';
  static const String vietnamese = 'vietnamese';

  static const List<String> all = [
    african,
    american,
    british,
    cajun,
    caribbean,
    chinese,
    easternEuropean,
    european,
    french,
    german,
    greek,
    indian,
    irish,
    italian,
    japanese,
    jewish,
    korean,
    latinAmerican,
    mediterranean,
    mexican,
    middleEastern,
    nordic,
    southern,
    spanish,
    thai,
    vietnamese,
  ];

  static String getDisplayName(String cuisine) {
    return cuisine
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Skill levels
class SkillLevels {
  static const String beginner = 'beginner';
  static const String intermediate = 'intermediate';
  static const String advanced = 'advanced';

  static const List<String> all = [beginner, intermediate, advanced];

  static String getDisplayName(String level) {
    return level[0].toUpperCase() + level.substring(1);
  }

  static String getDescription(String level) {
    switch (level) {
      case beginner:
        return 'Quick & simple recipes under 30 minutes';
      case intermediate:
        return 'Moderate complexity, up to 1 hour';
      case advanced:
        return 'Complex recipes, no time limit';
      default:
        return '';
    }
  }
}

/// Meal types
class MealTypes {
  static const String breakfast = 'breakfast';
  static const String brunch = 'brunch';
  static const String lunch = 'lunch';
  static const String dinner = 'dinner';
  static const String snack = 'snack';
  static const String dessert = 'dessert';
  static const String appetizer = 'appetizer';
  static const String salad = 'salad';
  static const String soup = 'soup';
  static const String beverage = 'beverage';
  static const String sauce = 'sauce';
  static const String marinade = 'marinade';
  static const String bread = 'bread';

  static const List<String> all = [
    breakfast,
    brunch,
    lunch,
    dinner,
    snack,
    dessert,
    appetizer,
    salad,
    soup,
    beverage,
    sauce,
    marinade,
    bread,
  ];

  static String getDisplayName(String type) {
    return type[0].toUpperCase() + type.substring(1);
  }
}
