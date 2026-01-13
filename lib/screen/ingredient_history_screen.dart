import 'package:flutter/material.dart';
import 'package:meal_palette/model/ingredient_generation_model.dart';
import 'package:meal_palette/screen/generated_recipes_screen.dart';
import 'package:meal_palette/service/ingredient_recipe_service.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Screen showing history of ingredient-based recipe generations
class IngredientHistoryScreen extends StatefulWidget {
  const IngredientHistoryScreen({super.key});

  @override
  State<IngredientHistoryScreen> createState() =>
      _IngredientHistoryScreenState();
}

class _IngredientHistoryScreenState extends State<IngredientHistoryScreen> {
  //* Services
  final IngredientRecipeService _ingredientService = IngredientRecipeService();
  final FavoritesState _favoritesState = FavoritesState();

  //* State
  List<IngredientGeneration> _history = [];
  bool _isLoading = true;
  Map<String, int>? _mostUsedIngredients;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadStats();
  }

  /// Load generation history
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final history = await _ingredientService.getGenerationHistory(
        _favoritesState.currentUserId,
      );

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load history');
    }
  }

  /// Load usage statistics
  Future<void> _loadStats() async {
    try {
      final stats = await _ingredientService.getMostUsedIngredients(
        _favoritesState.currentUserId,
        limit: 5,
      );

      setState(() {
        _mostUsedIngredients = stats;
      });
    } catch (e) {
      print('⚠️ Failed to load stats: $e');
    }
  }

  /// Regenerate recipes from a past generation
  void _regenerateFromHistory(IngredientGeneration generation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeneratedRecipesScreen(
          ingredients: generation.ingredients,
        ),
      ),
    );
  }

  /// Delete a generation from history
  Future<void> _deleteGeneration(IngredientGeneration generation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('Delete Generation?', style: AppTextStyles.recipeTitle),
        content: Text(
          'This will remove this generation from your history.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.favorite,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _ingredientService.deleteGeneration(
          _favoritesState.currentUserId,
          generation.id,
        );

        setState(() {
          _history.remove(generation);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Generation deleted')),
          );
        }
      } catch (e) {
        _showError('Failed to delete generation');
      }
    }
  }

  /// Clear all history
  Future<void> _clearAllHistory() async {
    if (_history.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('Clear All History?', style: AppTextStyles.recipeTitle),
        content: Text(
          'This will permanently delete all your recipe generation history.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.favorite,
            ),
            child: Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _ingredientService.clearAllHistory(
          _favoritesState.currentUserId,
        );

        setState(() {
          _history.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('History cleared')),
          );
        }
      } catch (e) {
        _showError('Failed to clear history');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.favorite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Generation History'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryAccent,
              ),
            )
          : _history.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              'No History Yet',
              style: AppTextStyles.recipeTitle,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Your recipe generations will appear here',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      children: [
        //* Stats Section
        if (_mostUsedIngredients != null &&
            _mostUsedIngredients!.isNotEmpty) ...[
          Container(
            margin: EdgeInsets.all(AppSpacing.lg),
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Used Ingredients',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _mostUsedIngredients!.entries.map((entry) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primaryAccent,
                            ),
                          ),
                          SizedBox(width: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${entry.value}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        //* History List Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Generations',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_history.length} total',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: AppSpacing.md),

        //* History Items
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final generation = _history[index];
              return _buildHistoryCard(generation);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(IngredientGeneration generation) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: () => _regenerateFromHistory(generation),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //* Header with date and delete button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        generation.formattedDate,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    onPressed: () => _deleteGeneration(generation),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.md),

              //* Ingredients
              Text(
                '${generation.ingredients.length} ingredients used',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppSpacing.sm),

              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: generation.ingredients
                    .take(5) // Show first 5 ingredients
                    .map(
                      (ingredient) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          ingredient,
                          style: AppTextStyles.labelMedium,
                        ),
                      ),
                    )
                    .toList(),
              ),

              if (generation.ingredients.length > 5)
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '+${generation.ingredients.length - 5} more',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),

              SizedBox(height: AppSpacing.md),

              //* Regenerate button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to regenerate',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryAccent,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: AppColors.primaryAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}