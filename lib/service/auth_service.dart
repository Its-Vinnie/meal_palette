import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:meal_palette/database/firestore_service.dart';

/// Enhanced Authentication Service
/// Handles all authentication operations including:
/// - Email/Password authentication
/// - Google Sign In
/// - Apple Sign In
/// - User state management
/// - Firestore user profile creation
class AuthService extends ChangeNotifier {
  //* Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  //* Firebase instances
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();

  //* Current user getter
  User? get currentUser => _firebaseAuth.currentUser;

  //* Auth state stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  //* Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  //* Error state
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // EMAIL & PASSWORD AUTHENTICATION
  // ============================================================================

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print("✅ Sign in successful: ${credential.user?.email}");
      return credential;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    } catch (e) {
      _setError("An unexpected error occurred. Please try again.");
      print("❌ Sign in error: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Create account with email and password
  Future<UserCredential?> createAccountWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      //* Create user account
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      //* Update display name
      await credential.user?.updateDisplayName(name);

      //* Create user profile in Firestore
      if (credential.user != null) {
        await _createUserProfile(
          userId: credential.user!.uid,
          email: email,
          name: name,
          photoUrl: null,
          provider: 'email',
        );
      }

      print("✅ Account created successfully: ${credential.user?.email}");
      return credential;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    } catch (e) {
      _setError("Failed to create account. Please try again.");
      print("❌ Create account error: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // GOOGLE SIGN IN
  // ============================================================================

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();

      //* Trigger Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        //* User cancelled the sign-in
        _setLoading(false);
        return null;
      }

      //* Obtain auth details from request
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      //* Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      //* Sign in to Firebase with credential
      final userCredential = 
          await _firebaseAuth.signInWithCredential(credential);

      //* Create or update user profile in Firestore
      if (userCredential.user != null) {
        final user = userCredential.user!;
        await _createUserProfile(
          userId: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'Google User',
          photoUrl: user.photoURL,
          provider: 'google',
        );
      }

      print("✅ Google sign in successful: ${userCredential.user?.email}");
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    } catch (e) {
      _setError("Google sign in failed. Please try again.");
      print("❌ Google sign in error: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // APPLE SIGN IN
  // ============================================================================

  /// Sign in with Apple
  /// Note: Apple Sign In requires proper configuration in:
  /// - iOS: Xcode capabilities
  /// - Firebase: Apple as authentication provider
  Future<UserCredential?> signInWithApple() async {
    try {
      _setLoading(true);
      _clearError();

      //* Request credential for the Apple ID
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      //* Create OAuth credential
      final oAuthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      //* Sign in to Firebase
      final userCredential = 
          await _firebaseAuth.signInWithCredential(oAuthCredential);

      //* Create or update user profile
      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        //* Apple provides name only on first sign in
        String displayName = user.displayName ?? 'Apple User';
        if (appleCredential.givenName != null) {
          displayName = 
              '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
              .trim();
          await user.updateDisplayName(displayName);
        }

        await _createUserProfile(
          userId: user.uid,
          email: user.email ?? appleCredential.email ?? '',
          name: displayName,
          photoUrl: user.photoURL,
          provider: 'apple',
        );
      }

      print("✅ Apple sign in successful: ${userCredential.user?.email}");
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _setLoading(false);
        return null; // User cancelled
      }
      _setError("Apple sign in failed: ${e.message}");
      print("❌ Apple sign in error: $e");
      return null;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    } catch (e) {
      _setError("Apple sign in failed. Please try again.");
      print("❌ Apple sign in error: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // USER PROFILE MANAGEMENT
  // ============================================================================

  /// Creates or updates user profile in Firestore
  Future<void> _createUserProfile({
    required String userId,
    required String email,
    required String name,
    String? photoUrl,
    required String provider,
  }) async {
    try {
      //* Check if profile already exists
      final existingProfile = await _firestoreService.getUserProfile(userId);

      if (existingProfile == null) {
        //* Create new profile
        await _firestoreService.saveUserProfile(
          userId,
          name: name,
          email: email,
        );

        //* Add additional profile fields
        await _firestoreService.updateUserProfile(userId, {
          'photoUrl': photoUrl,
          'provider': provider,
          'lastSignIn': FieldValue.serverTimestamp(),
        });

        print("✅ User profile created in Firestore");
      } else {
        //* Update existing profile
        await _firestoreService.updateUserProfile(userId, {
          'lastSignIn': FieldValue.serverTimestamp(),
        });

        print("✅ User profile updated in Firestore");
      }
    } catch (e) {
      print("❌ Error managing user profile: $e");
      // Don't throw - profile creation failure shouldn't block auth
    }
  }

  // ============================================================================
  // PASSWORD MANAGEMENT
  // ============================================================================

  /// Send password reset email
  Future<bool> sendPasswordResetEmail({required String email}) async {
    try {
      _setLoading(true);
      _clearError();

      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());

      print("✅ Password reset email sent to: $email");
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _setError("Failed to send reset email. Please try again.");
      print("❌ Password reset error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update password (requires recent authentication)
  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = currentUser;
      if (user == null || user.email == null) {
        _setError("No authenticated user found");
        return false;
      }

      //* Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      //* Update password
      await user.updatePassword(newPassword);

      print("✅ Password updated successfully");
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _setError("Failed to update password. Please try again.");
      print("❌ Update password error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // ACCOUNT MANAGEMENT
  // ============================================================================

  /// Update display name
  Future<bool> updateDisplayName({required String name}) async {
    try {
      await currentUser?.updateDisplayName(name);
      
      //* Also update in Firestore
      if (currentUser != null) {
        await _firestoreService.updateUserProfile(
          currentUser!.uid,
          {'name': name},
        );
      }

      notifyListeners();
      print("✅ Display name updated to: $name");
      return true;
    } catch (e) {
      _setError("Failed to update name");
      print("❌ Update name error: $e");
      return false;
    }
  }

  /// Delete account (requires recent authentication)
  Future<bool> deleteAccount({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = currentUser;
      if (user == null) {
        _setError("No authenticated user found");
        return false;
      }

      //* Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      //* Delete user data from Firestore first
      // TODO: Implement cascade delete of user data

      //* Delete Firebase Auth account
      await user.delete();

      print("✅ Account deleted successfully");
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _setError("Failed to delete account. Please try again.");
      print("❌ Delete account error: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _setLoading(true);

      //* Sign out from Google if signed in
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      //* Sign out from Firebase
      await _firebaseAuth.signOut();

      print("✅ User signed out successfully");
    } catch (e) {
      print("❌ Sign out error: $e");
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // ERROR HANDLING
  // ============================================================================

  /// Handles Firebase Auth errors and sets user-friendly messages
  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        _setError('Invalid email address format');
        break;
      case 'user-disabled':
        _setError('This account has been disabled');
        break;
      case 'user-not-found':
        _setError('No account found with this email');
        break;
      case 'wrong-password':
        _setError('Incorrect password');
        break;
      case 'email-already-in-use':
        _setError('An account already exists with this email');
        break;
      case 'weak-password':
        _setError('Password is too weak. Use at least 6 characters');
        break;
      case 'operation-not-allowed':
        _setError('This sign-in method is not enabled');
        break;
      case 'invalid-credential':
        _setError('Invalid credentials. Please try again');
        break;
      case 'account-exists-with-different-credential':
        _setError('Account exists with different sign-in method');
        break;
      case 'requires-recent-login':
        _setError('Please sign in again to perform this action');
        break;
      case 'network-request-failed':
        _setError('Network error. Check your connection');
        break;
      case 'too-many-requests':
        _setError('Too many attempts. Please try again later');
        break;
      default:
        _setError('Authentication failed: ${e.message}');
    }
    print("❌ Firebase Auth Error [${e.code}]: ${e.message}");
  }

  // ============================================================================
  // STATE MANAGEMENT HELPERS
  // ============================================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error message manually
  void clearError() {
    _clearError();
  }
}

//* Global auth service instance
final authService = AuthService();