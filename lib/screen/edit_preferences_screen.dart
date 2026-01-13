import 'package:flutter/material.dart';
import 'package:meal_palette/model/user_preferences_model.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/state/user_preferences_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

class EditPreferencesScreen extends StatefulWidget {
  const EditPreferencesScreen({super.key});

  @override
  State<EditPreferencesScreen> createState() => _EditPreferencesScreenState();
}

class _EditPreferencesScreenState extends State<EditPreferencesScreen> {
  final _preferencesState = userPreferencesState;
  final _userId = authService.currentUser?.uid;

  Set<String> _dietary = {};
  Set<String> _cuisines = {};
  String _skillLevel = SkillLevels.intermediate;
  Set<String> _mealTypes = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final userId = _userId;
    if (userId == null) return;

    setState(() => _isLoading = true);

    await _preferencesState.loadPreferences(userId);

    final prefs = _preferencesState.preferences;
    if (prefs != null) {
      setState(() {
        _dietary = Set.from(prefs.dietaryRestrictions);
        _cuisines = Set.from(prefs.cuisinePreferences);
        _skillLevel = prefs.skillLevel;
        _mealTypes = Set.from(prefs.mealTypePreferences);
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _savePreferences() async {
    final userId = _userId;
    if (userId == null) return;

    if (_cuisines.isEmpty || _mealTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one cuisine and meal type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final prefs = UserPreferences(
      dietaryRestrictions: _dietary.toList(),
      cuisinePreferences: _cuisines.toList(),
      skillLevel: _skillLevel,
      mealTypePreferences: _mealTypes.toList(),
      createdAt: _preferencesState.preferences?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await _preferencesState.updatePreferences(userId, prefs);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update preferences'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Food Preferences',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _savePreferences,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryAccent,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    'Dietary Restrictions',
                    DietaryRestrictions.all,
                    _dietary,
                    (item) => setState(() {
                      if (_dietary.contains(item)) {
                        _dietary.remove(item);
                      } else {
                        _dietary.add(item);
                      }
                    }),
                    DietaryRestrictions.getDisplayName,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSection(
                    'Favorite Cuisines',
                    CuisineTypes.all,
                    _cuisines,
                    (item) => setState(() {
                      if (_cuisines.contains(item)) {
                        _cuisines.remove(item);
                      } else {
                        _cuisines.add(item);
                      }
                    }),
                    CuisineTypes.getDisplayName,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSkillLevelSection(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSection(
                    'Meal Types',
                    MealTypes.all,
                    _mealTypes,
                    (item) => setState(() {
                      if (_mealTypes.contains(item)) {
                        _mealTypes.remove(item);
                      } else {
                        _mealTypes.add(item);
                      }
                    }),
                    MealTypes.getDisplayName,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(
    String title,
    List<String> items,
    Set<String> selected,
    Function(String) onToggle,
    String Function(String) getDisplayName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.recipeTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: items.map((item) {
            final isSelected = selected.contains(item);
            return FilterChip(
              label: Text(getDisplayName(item)),
              selected: isSelected,
              onSelected: (_) => onToggle(item),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryAccent.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primaryAccent,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primaryAccent : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSkillLevelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cooking Skill Level',
          style: AppTextStyles.recipeTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...SkillLevels.all.map((level) {
          final isSelected = _skillLevel == level;
          return RadioListTile<String>(
            value: level,
            groupValue: _skillLevel,
            onChanged: (value) => setState(() => _skillLevel = value!),
            title: Text(
              SkillLevels.getDisplayName(level),
              style: TextStyle(
                color: isSelected ? AppColors.primaryAccent : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              SkillLevels.getDescription(level),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            activeColor: AppColors.primaryAccent,
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          );
        }),
      ],
    );
  }
}
