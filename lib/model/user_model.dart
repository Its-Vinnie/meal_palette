import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_palette/model/voice_settings_model.dart';
import 'package:meal_palette/model/user_preferences_model.dart';

/// User Model for storing user profile data in Firestore
/// This complements Firebase Authentication User
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final VoiceSettings? voiceSettings;
  final UserPreferences? preferences;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.updatedAt,
    this.voiceSettings,
    this.preferences,
  });

  /// Creates UserProfile from Firestore document
  /// Handles both Timestamp and String formats
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? 'User',
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _parseDateTime(json['updatedAt'])
          : null,
      voiceSettings: json['voiceSettings'] != null
          ? VoiceSettings.fromJson(json['voiceSettings'] as Map<String, dynamic>)
          : null,
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Helper method to parse DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    
    // Handle Firestore Timestamp
    if (value is Timestamp) {
      return value.toDate();
    }
    
    // Handle String ISO8601
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Error parsing date string: $e');
        return DateTime.now();
      }
    }
    
    // Handle DateTime
    if (value is DateTime) {
      return value;
    }
    
    // Fallback
    return DateTime.now();
  }

  /// Converts UserProfile to Map for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (voiceSettings != null) 'voiceSettings': voiceSettings!.toJson(),
      if (preferences != null) 'preferences': preferences!.toJson(),
    };
  }

  /// Creates a copy with updated fields
  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
    VoiceSettings? voiceSettings,
    UserPreferences? preferences,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      voiceSettings: voiceSettings ?? this.voiceSettings,
      preferences: preferences ?? this.preferences,
    );
  }

  /// Returns formatted member since date (e.g., "December 2025")
  String get memberSinceFormatted {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[createdAt.month - 1]} ${createdAt.year}';
  }

  @override
  String toString() {
    return 'UserProfile(uid: $uid, displayName: $displayName, email: $email)';
  }
}