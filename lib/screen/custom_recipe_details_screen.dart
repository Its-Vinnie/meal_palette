import 'package:flutter/material.dart';
import 'package:meal_palette/model/custom_recipe_model.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/screen/cook_along_screen.dart';
import 'package:meal_palette/screen/create_edit_recipe_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/state/custom_recipes_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Screen displaying full details of a custom recipe
class CustomRecipeDetailsScreen extends StatefulWidget {
  final CustomRecipe recipe;

  const CustomRecipeDetailsScreen({super.key, required this.recipe});

  @override
  State<CustomRecipeDetailsScreen> createState() => _CustomRecipeDetailsScreenState();
}

class _CustomRecipeDetailsScreenState extends State<CustomRecipeDetailsScreen> {
  final CustomRecipesState _customRecipesState = customRecipesState;
  final AuthService _authService = authService;

  /// Delete recipe with confirmation
  Future<void> _deleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Recipe?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.recipe.title}"? This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.favorite),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = _authService.currentUser;
      if (user != null) {
        final success = await _customRecipesState.deleteRecipe(user.uid, widget.recipe.id);
        if (success && mounted) {
          Navigator.pop(context); // Go back after deleting
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${widget.recipe.title}"'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }

  /// Navigate to edit screen
  void _editRecipe() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditRecipeScreen(recipe: widget.recipe),
      ),
    );
  }

  /// Start cook-along mode
  void _startCookAlong() {
    // Convert CustomRecipe to RecipeDetail for cook-along
    final recipeDetail = RecipeDetail(
      id: 0, // Custom recipes don't have API IDs
      title: widget.recipe.title,
      image: widget.recipe.imageUrl,
      servings: widget.recipe.servings ?? 4, // Default to 4 servings
      readyInMinutes: widget.recipe.totalTime ?? 30, // Default to 30 minutes
      summary: widget.recipe.description ?? '',
      ingredients: widget.recipe.ingredients,
      instructions: widget.recipe.instructions,
      vegetarian: widget.recipe.vegetarian,
      vegan: widget.recipe.vegan,
      glutenFree: widget.recipe.glutenFree,
      dairyFree: widget.recipe.dairyFree,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CookAlongScreen(recipe: recipeDetail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primaryAccent),
                onPressed: _editRecipe,
                tooltip: 'Edit Recipe',
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.favorite),
                onPressed: _deleteRecipe,
                tooltip: 'Delete Recipe',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: widget.recipe.imageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.recipe.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: AppColors.surface,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryAccent,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ Error loading recipe image: $error');
                            print('Image URL: ${widget.recipe.imageUrl}');
                            return Container(
                              color: AppColors.surface,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.recipe.category != null
                                          ? RecipeCategories.getIcon(widget.recipe.category!)
                                          : '🍴',
                                      style: const TextStyle(fontSize: 80),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image failed to load',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.background.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.surface,
                      child: Center(
                        child: Text(
                          widget.recipe.category != null
                              ? RecipeCategories.getIcon(widget.recipe.category!)
                              : '🍴',
                          style: const TextStyle(fontSize: 80),
                        ),
                      ),
                    ),
            ),
          ),

          // Recipe content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.recipe.title,
                    style: AppTextStyles.pageHeadline,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Category badge
                  if (widget.recipe.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${RecipeCategories.getIcon(widget.recipe.category!)} ${RecipeCategories.getDisplayName(widget.recipe.category!)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // Meta info row
                  Row(
                    children: [
                      if (widget.recipe.servings != null) ...[
                        _buildMetaChip(
                          Icons.people_outline,
                          '${widget.recipe.servings} servings',
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      if (widget.recipe.totalTime != null) ...[
                        _buildMetaChip(
                          Icons.access_time,
                          '${widget.recipe.totalTime} min',
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      if (widget.recipe.prepTime != null) ...[
                        _buildMetaChip(
                          Icons.soup_kitchen,
                          'Prep: ${widget.recipe.prepTime} min',
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Dietary badges
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (widget.recipe.vegetarian)
                        _buildDietaryBadge('🌱 Vegetarian', Colors.green),
                      if (widget.recipe.vegan)
                        _buildDietaryBadge('🥬 Vegan', Colors.lightGreen),
                      if (widget.recipe.glutenFree)
                        _buildDietaryBadge('🌾 Gluten-Free', Colors.amber),
                      if (widget.recipe.dairyFree)
                        _buildDietaryBadge('🥛 Dairy-Free', Colors.blue),
                    ],
                  ),

                  if (widget.recipe.description != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      widget.recipe.description!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),

                  // Cook Along Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startCookAlong,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text(
                        'Start Cook-Along',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Ingredients section
                  Text(
                    'Ingredients',
                    style: AppTextStyles.recipeTitle,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  ...widget.recipe.ingredients.map((ingredient) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 8, right: AppSpacing.md),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              ingredient.original,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.xxl),

                  // Instructions section
                  Text(
                    'Instructions',
                    style: AppTextStyles.recipeTitle,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  ...widget.recipe.instructions.map((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
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
                                '${step.number}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                step.step,
                                style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.xxl),

                  // Source info if available
                  if (widget.recipe.sourceUrl != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.link,
                                color: AppColors.primaryAccent,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Source',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            widget.recipe.sourceUrl!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.secondaryAccent,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
