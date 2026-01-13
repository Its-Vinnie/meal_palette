import 'package:flutter/material.dart';
import 'package:meal_palette/model/user_preferences_model.dart';
import 'package:meal_palette/screen/onboarding/skill_level_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';

class CuisinePreferencesScreen extends StatefulWidget {
  final List<String> dietaryRestrictions;
  final List<String> initialCuisines;

  const CuisinePreferencesScreen({
    super.key,
    required this.dietaryRestrictions,
    this.initialCuisines = const [],
  });

  @override
  State<CuisinePreferencesScreen> createState() =>
      _CuisinePreferencesScreenState();
}

class _CuisinePreferencesScreenState extends State<CuisinePreferencesScreen> {
  final Set<String> _selectedCuisines = {};

  @override
  void initState() {
    super.initState();
    _selectedCuisines.addAll(widget.initialCuisines);
  }

  void _toggleCuisine(String cuisine) {
    setState(() {
      if (_selectedCuisines.contains(cuisine)) {
        _selectedCuisines.remove(cuisine);
      } else {
        _selectedCuisines.add(cuisine);
      }
    });
  }

  void _continue() {
    if (_selectedCuisines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one cuisine'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SkillLevelScreen(
          dietaryRestrictions: widget.dietaryRestrictions,
          cuisinePreferences: _selectedCuisines.toList(),
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: 2 / 5,
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
                      'What cuisines do you love?',
                      style: AppTextStyles.pageHeadline.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Select your favorite cuisines to personalize your feed',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: CuisineTypes.all.map((cuisine) {
                        final isSelected = _selectedCuisines.contains(cuisine);
                        return FilterChip(
                          label: Text(CuisineTypes.getDisplayName(cuisine)),
                          selected: isSelected,
                          onSelected: (_) => _toggleCuisine(cuisine),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
