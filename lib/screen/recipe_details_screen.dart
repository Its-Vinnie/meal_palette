import 'package:flutter/material.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/theme/theme_design.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  RecipeDetail? _recipe;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    try {
      final recipe = await SpoonacularService.getRecipeDetails(widget.recipeId);
      setState(() {
        _recipe = recipe;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryAccent),
        ),
      );
    }

    if (_error != null || _recipe == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Error loading recipe', style: AppTextStyles.bodyLarge),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _recipe!.title,
                  style: AppTextStyles.recipeTitle.copyWith(fontSize: 18),
                ),
              ),
              background: _recipe!.image != null
                  ? Image.network(_recipe!.image!, fit: BoxFit.cover)
                  : Container(color: AppColors.surface),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Row
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.access_time,
                        '${_recipe!.readyInMinutes} min',
                      ),
                      SizedBox(width: AppSpacing.md),
                      _buildInfoChip(
                        Icons.people_outline,
                        '${_recipe!.servings} servings',
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // Dietary Tags
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      if (_recipe!.vegetarian) _buildTag('Vegetarian'),
                      if (_recipe!.vegan) _buildTag('Vegan'),
                      if (_recipe!.glutenFree) _buildTag('Gluten Free'),
                      if (_recipe!.dairyFree) _buildTag('Dairy Free'),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  // Ingredients Section
                  Text('Ingredients', style: AppTextStyles.recipeTitle),
                  SizedBox(height: AppSpacing.lg),

                  ..._recipe!.ingredients.map(
                    (ingredient) => Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: AppColors.primaryAccent,
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              ingredient.original,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  // Instructions Section
                  Text('Instructions', style: AppTextStyles.recipeTitle),
                  SizedBox(height: AppSpacing.lg),

                  ..._recipe!.instructions.asMap().entries.map((entry) {
                    final instruction = entry.value;
                    return Container(
                      margin: EdgeInsets.only(bottom: AppSpacing.lg),
                      padding: EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${instruction.number}',
                                style: AppTextStyles.labelLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Text(
                              instruction.step,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
