import 'package:flutter/material.dart';
import 'package:meal_palette/model/user_preferences_model.dart';
import 'package:meal_palette/screen/onboarding/meal_type_preferences_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';

class SkillLevelScreen extends StatefulWidget {
  final List<String> dietaryRestrictions;
  final List<String> cuisinePreferences;
  final String? initialSkill;

  const SkillLevelScreen({
    super.key,
    required this.dietaryRestrictions,
    required this.cuisinePreferences,
    this.initialSkill,
  });

  @override
  State<SkillLevelScreen> createState() => _SkillLevelScreenState();
}

class _SkillLevelScreenState extends State<SkillLevelScreen> {
  String _selectedSkill = SkillLevels.intermediate;

  @override
  void initState() {
    super.initState();
    if (widget.initialSkill != null) {
      _selectedSkill = widget.initialSkill!;
    }
  }

  void _continue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealTypePreferencesScreen(
          dietaryRestrictions: widget.dietaryRestrictions,
          cuisinePreferences: widget.cuisinePreferences,
          skillLevel: _selectedSkill,
        ),
      ),
    );
  }

  Widget _buildSkillCard(String level) {
    final isSelected = _selectedSkill == level;

    return Card(
      color: isSelected
          ? AppColors.primaryAccent.withValues(alpha: 0.1)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isSelected ? AppColors.primaryAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedSkill = level),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    level == SkillLevels.beginner
                        ? Icons.star_border
                        : level == SkillLevels.intermediate
                            ? Icons.star_half
                            : Icons.star,
                    color: isSelected
                        ? AppColors.primaryAccent
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      SkillLevels.getDisplayName(level),
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isSelected
                            ? AppColors.primaryAccent
                            : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.primaryAccent,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                SkillLevels.getDescription(level),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
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
              value: 3 / 5,
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
                      'What\'s your cooking skill level?',
                      style: AppTextStyles.pageHeadline.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'This helps us recommend recipes that match your expertise',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    ...SkillLevels.all.map((level) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _buildSkillCard(level),
                        )),
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
