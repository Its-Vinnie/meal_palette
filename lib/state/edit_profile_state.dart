import 'package:flutter/foundation.dart';
import 'package:meal_palette/service/user_profile_service.dart';

/// State management for Edit Profile Screen
/// Handles username updates and provides reactive updates
class EditProfileState extends ChangeNotifier {
  //* Singleton pattern
  static final EditProfileState _instance = EditProfileState._internal();
  factory EditProfileState() => _instance;
  EditProfileState._internal() {
    _loadCurrentUsername();
  }

  //* Services
  final UserProfileService _userProfileService = UserProfileService();

  //* Current username
  final ValueNotifier<String> currentUsername = ValueNotifier<String>('User');

  //* Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Load current username from profile
  Future<void> _loadCurrentUsername() async {
    try {
      final profile = await _userProfileService.getCurrentUserProfile();
      if (profile != null) {
        currentUsername.value = profile.displayName;
      }
    } catch (e) {
      print('Error loading username: $e');
    }
  }

  /// Update username
  Future<bool> updateUsername(String newUsername) async {
    if (newUsername.trim().isEmpty) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final success = await _userProfileService.updateDisplayName(
        newUsername.trim(),
      );

      if (success) {
        currentUsername.value = newUsername.trim();
      }

      return success;
    } catch (e) {
      print('Error updating username: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh current username
  Future<void> refresh() async {
    await _loadCurrentUsername();
  }
}