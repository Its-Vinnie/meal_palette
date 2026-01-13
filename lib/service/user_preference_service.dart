import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_palette/model/user_preferences_model.dart';

/// Service for managing user food preferences in Firestore
class UserPreferenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save or update user preferences
  Future<bool> savePreferences(
      String userId, UserPreferences preferences) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'preferences': preferences.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User preferences saved');
      return true;
    } catch (e) {
      print('❌ Error saving preferences: $e');
      return false;
    }
  }

  /// Get user preferences
  Future<UserPreferences?> getPreferences(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data()?['preferences'] != null) {
        return UserPreferences.fromJson(
            userDoc.data()!['preferences'] as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('❌ Error getting preferences: $e');
      return null;
    }
  }

  /// Update specific preference fields
  Future<bool> updatePreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    try {
      final updatedPrefs = preferences.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(userId).update({
        'preferences': updatedPrefs.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User preferences updated');
      return true;
    } catch (e) {
      print('❌ Error updating preferences: $e');
      return false;
    }
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final prefs = await getPreferences(userId);

      if (prefs == null) return false;

      // User has completed onboarding if they have at least one preference set
      return prefs.hasCompletedOnboarding;
    } catch (e) {
      print('❌ Error checking onboarding status: $e');
      return false;
    }
  }

  /// Mark onboarding as complete with default preferences
  Future<bool> markOnboardingComplete(String userId) async {
    try {
      // Check if preferences already exist
      final existing = await getPreferences(userId);
      if (existing != null) return true;

      // Create default preferences
      final defaultPrefs = UserPreferences.defaultPreferences;

      await _firestore.collection('users').doc(userId).update({
        'preferences': defaultPrefs.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Onboarding marked as complete');
      return true;
    } catch (e) {
      print('❌ Error marking onboarding complete: $e');
      return false;
    }
  }

  /// Clear all preferences (reset)
  Future<bool> clearPreferences(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'preferences': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User preferences cleared');
      return true;
    } catch (e) {
      print('❌ Error clearing preferences: $e');
      return false;
    }
  }

  /// Stream of user preferences for real-time updates
  Stream<UserPreferences?> preferencesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data()?['preferences'] != null) {
        return UserPreferences.fromJson(
            snapshot.data()!['preferences'] as Map<String, dynamic>);
      }
      return null;
    });
  }
}

/// Global singleton instance
final userPreferenceService = UserPreferenceService();
