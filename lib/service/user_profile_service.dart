import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meal_palette/model/user_model.dart';

/// Service for managing user profile data in Firestore
/// No profile pictures - uses initials-based avatars
class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // USER PROFILE OPERATIONS
  // ============================================================================

  /// Gets current Firebase Auth user
  User? get currentUser => _auth.currentUser;

  /// Gets current user's UID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Creates or updates user profile in Firestore after authentication
  /// Call this after successful sign up or sign in
  Future<UserProfile?> createOrUpdateUserProfile({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        //* User exists - update only if there are changes
        final existingData = userDoc.data()!;
        final updates = <String, dynamic>{};

        if (displayName != null &&
            displayName != existingData['displayName']) {
          updates['displayName'] = displayName;
        }

        if (updates.isNotEmpty) {
          updates['updatedAt'] = FieldValue.serverTimestamp();
          await userRef.update(updates);
        }

        //* Return updated profile
        return getUserProfile(uid);
      } else {
        //* New user - create profile
        final newProfile = UserProfile(
          uid: uid,
          email: email,
          displayName: displayName ?? email.split('@')[0],
          createdAt: DateTime.now(),
        );

        await userRef.set(newProfile.toJson());
        print('✅ Created new user profile: ${newProfile.displayName}');
        return newProfile;
      }
    } catch (e) {
      print('❌ Error creating/updating user profile: $e');
      return null;
    }
  }

  /// Gets user profile from Firestore
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        return UserProfile.fromJson(userDoc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  /// Gets current user's profile
  Future<UserProfile?> getCurrentUserProfile() async {
    if (currentUserId == null) return null;
    return getUserProfile(currentUserId!);
  }

  /// Stream of current user's profile for real-time updates
  Stream<UserProfile?> getCurrentUserProfileStream() {
    if (currentUserId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserProfile.fromJson(doc.data()!);
      }
      return null;
    });
  }

  /// Updates user's display name in both Firebase Auth and Firestore
  Future<bool> updateDisplayName(String newDisplayName) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      //* Update Firebase Auth display name
      await user.updateDisplayName(newDisplayName);

      //* Update Firestore profile
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': newDisplayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      //* Reload user to get updated data
      await user.reload();

      print('✅ Display name updated: $newDisplayName');
      return true;
    } catch (e) {
      print('❌ Error updating display name: $e');
      return false;
    }
  }

  /// Updates user's email in both Firebase Auth and Firestore
  /// Note: This requires recent authentication
  Future<bool> updateEmail(String newEmail) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      //* Update Firebase Auth email
      await user.verifyBeforeUpdateEmail(newEmail);

      //* Update Firestore profile
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      //* Reload user to get updated data
      await user.reload();

      print('✅ Email verification sent to: $newEmail');
      return true;
    } catch (e) {
      print('❌ Error updating email: $e');
      rethrow; // Rethrow to handle specific errors (like requires-recent-login)
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Re-authenticate user (required for sensitive operations)
  /// This is needed before updating email or password
  Future<bool> reauthenticateWithPassword(String password) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      print('✅ Re-authentication successful');
      return true;
    } catch (e) {
      print('❌ Re-authentication failed: $e');
      return false;
    }
  }

  /// Syncs Firebase Auth user data with Firestore
  /// Call this on app startup or after login
  Future<void> syncUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) return;

      await createOrUpdateUserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );

      print('✅ User profile synced');
    } catch (e) {
      print('❌ Error syncing user profile: $e');
    }
  }

  /// Extracts initials from display name (e.g., "Vincent Maphari" -> "VM")
  String getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    
    return '${parts[0].substring(0, 1)}${parts[parts.length - 1].substring(0, 1)}'
        .toUpperCase();
  }
}