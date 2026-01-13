import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:meal_palette/model/user_preferences_model.dart';
import 'package:meal_palette/service/user_preference_service.dart';

/// State management for user food preferences
class UserPreferencesState extends ChangeNotifier {
  static UserPreferencesState? _instance;
  final UserPreferenceService _preferenceService = userPreferenceService;

  UserPreferences? _preferences;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserPreferences?>? _preferencesSubscription;

  // Private constructor
  UserPreferencesState._();

  // Singleton factory
  factory UserPreferencesState() {
    _instance ??= UserPreferencesState._();
    return _instance!;
  }

  // Getters
  UserPreferences? get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPreferences => _preferences != null;
  bool get hasCompletedOnboarding =>
      _preferences?.hasCompletedOnboarding ?? false;

  // Convenience getters for quick access
  List<String> get dietaryRestrictions =>
      _preferences?.dietaryRestrictions ?? [];
  List<String> get cuisinePreferences => _preferences?.cuisinePreferences ?? [];
  String get skillLevel => _preferences?.skillLevel ?? 'intermediate';
  List<String> get mealTypePreferences =>
      _preferences?.mealTypePreferences ?? [];
  int? get maxReadyTime => _preferences?.maxReadyTime;

  /// Load preferences for a user
  Future<void> loadPreferences(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _preferences = await _preferenceService.getPreferences(userId);
      _errorMessage = null;
      print('✅ Loaded user preferences: $_preferences');
    } catch (e) {
      _errorMessage = 'Failed to load preferences';
      print('❌ Error loading preferences: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start listening to preference changes in real-time
  void startListening(String userId) {
    // Cancel existing subscription
    _preferencesSubscription?.cancel();

    _preferencesSubscription =
        _preferenceService.preferencesStream(userId).listen(
      (prefs) {
        _preferences = prefs;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Error listening to preferences';
        print('❌ Preferences stream error: $error');
        notifyListeners();
      },
    );

    print('✅ Started listening to preference changes');
  }

  /// Stop listening to preference changes
  void stopListening() {
    _preferencesSubscription?.cancel();
    _preferencesSubscription = null;
    print('🔇 Stopped listening to preference changes');
  }

  /// Save new preferences
  Future<bool> savePreferences(
      String userId, UserPreferences preferences) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success =
          await _preferenceService.savePreferences(userId, preferences);

      if (success) {
        _preferences = preferences;
        _errorMessage = null;
        print('✅ Preferences saved successfully');
      } else {
        _errorMessage = 'Failed to save preferences';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Failed to save preferences';
      print('❌ Error saving preferences: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update existing preferences
  Future<bool> updatePreferences(
      String userId, UserPreferences preferences) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success =
          await _preferenceService.updatePreferences(userId, preferences);

      if (success) {
        _preferences = preferences;
        _errorMessage = null;
        print('✅ Preferences updated successfully');
      } else {
        _errorMessage = 'Failed to update preferences';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Failed to update preferences';
      print('❌ Error updating preferences: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add dietary restriction
  Future<void> addDietaryRestriction(String userId, String restriction) async {
    if (_preferences == null) return;

    final updated = _preferences!.copyWith(
      dietaryRestrictions: [
        ..._preferences!.dietaryRestrictions,
        restriction,
      ],
      updatedAt: DateTime.now(),
    );

    await updatePreferences(userId, updated);
  }

  /// Remove dietary restriction
  Future<void> removeDietaryRestriction(
      String userId, String restriction) async {
    if (_preferences == null) return;

    final updated = _preferences!.copyWith(
      dietaryRestrictions: _preferences!.dietaryRestrictions
          .where((r) => r != restriction)
          .toList(),
      updatedAt: DateTime.now(),
    );

    await updatePreferences(userId, updated);
  }

  /// Add cuisine preference
  Future<void> addCuisinePreference(String userId, String cuisine) async {
    if (_preferences == null) return;

    final updated = _preferences!.copyWith(
      cuisinePreferences: [
        ..._preferences!.cuisinePreferences,
        cuisine,
      ],
      updatedAt: DateTime.now(),
    );

    await updatePreferences(userId, updated);
  }

  /// Remove cuisine preference
  Future<void> removeCuisinePreference(String userId, String cuisine) async {
    if (_preferences == null) return;

    final updated = _preferences!.copyWith(
      cuisinePreferences:
          _preferences!.cuisinePreferences.where((c) => c != cuisine).toList(),
      updatedAt: DateTime.now(),
    );

    await updatePreferences(userId, updated);
  }

  /// Update skill level
  Future<void> updateSkillLevel(String userId, String skillLevel) async {
    if (_preferences == null) return;

    final updated = _preferences!.copyWith(
      skillLevel: skillLevel,
      updatedAt: DateTime.now(),
    );

    await updatePreferences(userId, updated);
  }

  /// Add meal type preference
  Future<void> addMealTypePreference(String userId, String mealType) async {
    if (_preferences == null) return;

    final updated = _preferences!.copyWith(
      mealTypePreferences: [
        ..._preferences!.mealTypePreferences,
        mealType,
      ],
      updatedAt: DateTime.now(),
    );

    await updatePreferences(userId, updated);
  }

  /// Remove meal type preference
  Future<void> removeMealTypePreference(String userId, String mealType) async {
    if (_preferences == null) return;

    final updated = _preferences!.copyWith(
      mealTypePreferences:
          _preferences!.mealTypePreferences.where((m) => m != mealType).toList(),
      updatedAt: DateTime.now(),
    );

    await updatePreferences(userId, updated);
  }

  /// Clear all preferences
  Future<bool> clearPreferences(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _preferenceService.clearPreferences(userId);

      if (success) {
        _preferences = null;
        _errorMessage = null;
      } else {
        _errorMessage = 'Failed to clear preferences';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Failed to clear preferences';
      print('❌ Error clearing preferences: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear state on logout
  void clear() {
    stopListening();
    _preferences = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

/// Global singleton instance
final userPreferencesState = UserPreferencesState();
