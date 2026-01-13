import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:meal_palette/model/user_model.dart';
import 'package:meal_palette/service/user_profile_service.dart';

/// State management for user profile using ChangeNotifier
/// Provides real-time updates when user profile changes
class UserProfileState extends ChangeNotifier {
  //* Singleton pattern - ensures only one instance exists
  static final UserProfileState _instance = UserProfileState._internal();
  factory UserProfileState() => _instance;

  UserProfileState._internal() {
    //* Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _startListeningToProfile();
      } else {
        _stopListeningToProfile();
        _clearProfile();
      }
    });
  }

  //* User profile service
  final UserProfileService _userProfileService = UserProfileService();

  //* User profile data
  UserProfile? _userProfile;
  bool _isLoading = true;

  //* Stream subscription for profile updates
  StreamSubscription<UserProfile?>? _profileSubscription;

  // ============================================================================
  // GETTERS
  // ============================================================================

  /// Returns current user profile
  UserProfile? get userProfile => _userProfile;

  /// Returns loading state
  bool get isLoading => _isLoading;

  /// Returns display name with fallback
  String get displayName {
    if (_userProfile != null) {
      return _userProfile!.displayName;
    }

    //* Fallback to Firebase Auth user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      //* Extract name from email as last resort
      if (user.email != null) {
        return user.email!.split('@')[0];
      }
    }

    return 'User';
  }

  /// Returns first name only (for greetings)
  String get firstName {
    final name = displayName;
    final parts = name.split(' ');
    return parts.isNotEmpty ? parts[0] : name;
  }

  /// Returns email with fallback
  String get email {
    if (_userProfile != null) {
      return _userProfile!.email;
    }

    //* Fallback to Firebase Auth user
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? '';
  }

  /// Returns initials for avatar
  String get initials {
    return _userProfileService.getInitials(displayName);
  }

  /// Returns member since date
  String get memberSince {
    if (_userProfile != null) {
      return _userProfile!.memberSinceFormatted;
    }
    return 'Recently';
  }

  // ============================================================================
  // METHODS
  // ============================================================================

  /// Start listening to profile updates from Firestore
  void _startListeningToProfile() {
    _isLoading = true;
    notifyListeners();

    //* Cancel existing subscription if any
    _profileSubscription?.cancel();

    //* Listen to profile stream
    _profileSubscription = _userProfileService
        .getCurrentUserProfileStream()
        .listen(
          (UserProfile? profile) {
            _userProfile = profile;
            _isLoading = false;
            notifyListeners();

            if (profile != null) {
              print('✅ User profile updated: ${profile.displayName}');
            }
          },
          onError: (error) {
            print('❌ Error in profile stream: $error');
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Stop listening to profile updates
  void _stopListeningToProfile() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  /// Clear profile data (on logout)
  void _clearProfile() {
    _userProfile = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Manually reload profile (useful after updates)
  Future<void> reloadProfile() async {
    try {
      _isLoading = true;
      notifyListeners();

      final profile = await _userProfileService.getCurrentUserProfile();
      _userProfile = profile;
      _isLoading = false;
      notifyListeners();

      print('✅ Profile reloaded');
    } catch (e) {
      print('❌ Error reloading profile: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopListeningToProfile();
    super.dispose();
  }
}

//* Global instance
final userProfileState = UserProfileState();
