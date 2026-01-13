import 'package:flutter/material.dart';
import 'package:meal_palette/model/user_preferences_model.dart';
import 'package:meal_palette/screen/onboarding/cuisine_preferences_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';

class DietaryPreferencesScreen extends StatefulWidget {
  final List<String> initialSelections;

  const DietaryPreferencesScreen({
    super.key,
    this.initialSelections = const [],
  });

  @override
  State<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  final Set<String> _selectedRestrictions = {};

  @override
  void initState() {
    super.initState();
    _selectedRestrictions.addAll(widget.initialSelections);
  }

  void _toggleRestriction(String restriction) {
    setState(() {
      if (_selectedRestrictions.contains(restriction)) {
        _selectedRestrictions.remove(restriction);
      } else {
        _selectedRestrictions.add(restriction);
      }
    });
  }

  void _continue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CuisinePreferencesScreen(
          dietaryRestrictions: _selectedRestrictions.toList(),
        ),
      ),
    );
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
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _continue,
            child: const Text(
              'Skip',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: 1 / 5,
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
                    // Title
                    Text(
                      'Any dietary restrictions?',
                      style: AppTextStyles.pageHeadline.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'Select all that apply. This helps us filter recipes for you.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Dietary Restriction Chips
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: DietaryRestrictions.all.map((restriction) {
                        final isSelected =
                            _selectedRestrictions.contains(restriction);

                        return FilterChip(
                          label: Text(
                            DietaryRestrictions.getDisplayName(restriction),
                          ),
                          selected: isSelected,
                          onSelected: (_) => _toggleRestriction(restriction),
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

            // Continue Button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
