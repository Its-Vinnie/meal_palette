import 'package:flutter/material.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/screen/cook_along_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Ingredient and equipment checklist screen before starting Cook Along Mode
class CookAlongChecklistScreen extends StatefulWidget {
  final RecipeDetail recipe;

  const CookAlongChecklistScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<CookAlongChecklistScreen> createState() =>
      _CookAlongChecklistScreenState();
}

class _CookAlongChecklistScreenState extends State<CookAlongChecklistScreen> {
  final Set<String> _checkedIngredients = {};
  final Set<String> _checkedEquipment = {};
  List<String> _equipment = [];

  @override
  void initState() {
    super.initState();
    _extractEquipment();
  }

  /// Extract equipment from recipe instructions
  void _extractEquipment() {
    final equipmentKeywords = {
      'pan': 'Pan',
      'pot': 'Pot',
      'bowl': 'Bowl',
      'knife': 'Knife',
      'spoon': 'Spoon',
      'spatula': 'Spatula',
      'whisk': 'Whisk',
      'oven': 'Oven',
      'stove': 'Stove',
      'blender': 'Blender',
      'mixer': 'Mixer',
      'cutting board': 'Cutting Board',
      'baking sheet': 'Baking Sheet',
      'skillet': 'Skillet',
      'saucepan': 'Saucepan',
      'grill': 'Grill',
      'microwave': 'Microwave',
    };

    final foundEquipment = <String>{};

    for (final instruction in widget.recipe.instructions) {
      final stepLower = instruction.step.toLowerCase();
      for (final entry in equipmentKeywords.entries) {
        if (stepLower.contains(entry.key)) {
          foundEquipment.add(entry.value);
        }
      }
    }

    setState(() {
      _equipment = foundEquipment.toList()..sort();
    });
  }

  bool get _allIngredientsChecked =>
      _checkedIngredients.length == widget.recipe.ingredients.length;

  bool get _allEquipmentChecked =>
      _equipment.isEmpty || _checkedEquipment.length == _equipment.length;

  bool get _canStartCooking => _allIngredientsChecked && _allEquipmentChecked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cook Along Checklist',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipe.title,
                  style: AppTextStyles.recipeTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check off items you have ready',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildProgressChip(
                      'Ingredients',
                      _checkedIngredients.length,
                      widget.recipe.ingredients.length,
                    ),
                    const SizedBox(width: 12),
                    if (_equipment.isNotEmpty)
                      _buildProgressChip(
                        'Equipment',
                        _checkedEquipment.length,
                        _equipment.length,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Checklist content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Ingredients section
                _buildSectionHeader('Ingredients', Icons.egg_outlined),
                const SizedBox(height: 12),
                ...widget.recipe.ingredients.map((ingredient) {
                  final isChecked =
                      _checkedIngredients.contains(ingredient.original);
                  return _buildChecklistItem(
                    ingredient.original,
                    isChecked,
                    () {
                      setState(() {
                        if (isChecked) {
                          _checkedIngredients.remove(ingredient.original);
                        } else {
                          _checkedIngredients.add(ingredient.original);
                        }
                      });
                    },
                  );
                }),

                // Equipment section
                if (_equipment.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildSectionHeader('Equipment', Icons.kitchen_outlined),
                  const SizedBox(height: 12),
                  ..._equipment.map((item) {
                    final isChecked = _checkedEquipment.contains(item);
                    return _buildChecklistItem(
                      item,
                      isChecked,
                      () {
                        setState(() {
                          if (isChecked) {
                            _checkedEquipment.remove(item);
                          } else {
                            _checkedEquipment.add(item);
                          }
                        });
                      },
                    );
                  }),
                ],

                const SizedBox(height: 100), // Space for button
              ],
            ),
          ),
        ],
      ),

      // Start Cooking button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_canStartCooking)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Check all items to start cooking',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canStartCooking
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CookAlongScreen(
                                recipe: widget.recipe,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    disabledBackgroundColor:
                        AppColors.textTertiary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        "I'm Ready - Start Cooking!",
                        style: AppTextStyles.button,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryAccent, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(
    String text,
    bool isChecked,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isChecked
                        ? AppColors.success
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isChecked
                          ? AppColors.success
                          : AppColors.textTertiary,
                      width: 2,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Text
                Expanded(
                  child: Text(
                    text,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isChecked
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                      decoration: isChecked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressChip(String label, int completed, int total) {
    final isComplete = completed == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isComplete
            ? AppColors.success.withOpacity(0.2)
            : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isComplete ? AppColors.success : AppColors.textTertiary,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isComplete)
            const Icon(
              Icons.check_circle,
              size: 16,
              color: AppColors.success,
            )
          else
            Icon(
              Icons.radio_button_unchecked,
              size: 16,
              color: AppColors.textTertiary,
            ),
          const SizedBox(width: 6),
          Text(
            '$label: $completed/$total',
            style: AppTextStyles.labelMedium.copyWith(
              color: isComplete ? AppColors.success : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
