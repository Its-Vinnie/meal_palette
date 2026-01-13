import 'package:flutter/material.dart';
import 'package:meal_palette/model/user_preferences_model.dart';
import 'package:meal_palette/screen/onboarding/onboarding_complete_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/state/user_preferences_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

class MealTypePreferencesScreen extends StatefulWidget {
  final List<String> dietaryRestrictions;
  final List<String> cuisinePreferences;
  final String skillLevel;
  final List<String> initialMealTypes;

  const MealTypePreferencesScreen({
    super.key,
    required this.dietaryRestrictions,
    required this.cuisinePreferences,
    required this.skillLevel,
    this.initialMealTypes = const [],
  });

  @override
  State<MealTypePreferencesScreen> createState() =>
      _MealTypePreferencesScreenState();
}

class _MealTypePreferencesScreenState extends State<MealTypePreferencesScreen> {
  final Set<String> _selectedMealTypes = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMealTypes.addAll(widget.initialMealTypes);
  }

  void _toggleMealType(String mealType) {
    setState(() {
      if (_selectedMealTypes.contains(mealType)) {
        _selectedMealTypes.remove(mealType);
      } else {
        _selectedMealTypes.add(mealType);
      }
    });
  }

  Future<void> _complete() async {
    if (_selectedMealTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one meal type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create preferences object
      final preferences = UserPreferences(
        dietaryRestrictions: widget.dietaryRestrictions,
        cuisinePreferences: widget.cuisinePreferences,
        skillLevel: widget.skillLevel,
        mealTypePreferences: _selectedMealTypes.toList(),
        createdAt: DateTime.now(),
      );

      // Save preferences
      final success =
          await userPreferencesState.savePreferences(userId, preferences);

      if (success && mounted) {
        // Navigate to completion screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingCompleteScreen(),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preferences. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: 4 / 5,
              backgroundColor: AppColors.surface,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Which meal types do you enjoy?',
                      style: AppTextStyles.pageHeadline.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Select your favorite meal types',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: MealTypes.all.map((mealType) {
                        final isSelected = _selectedMealTypes.contains(mealType);
                        return FilterChip(
                          label: Text(MealTypes.getDisplayName(mealType)),
                          selected: isSelected,
                          onSelected: _isSaving ? null : (_) => _toggleMealType(mealType),
                          backgroundColor: AppColors.surface,
                          selectedColor:
                              AppColors.primaryAccent.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primaryAccent,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primaryAccent
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primaryAccent
                                  : AppColors.surface,
                              width: 2,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _complete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Complete Setup',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
