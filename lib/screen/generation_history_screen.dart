import 'package:flutter/material.dart';
import 'package:meal_palette/model/ingredient_generation_model.dart';
import 'package:meal_palette/screen/generated_recipes_screen.dart';
import 'package:meal_palette/service/ingredient_recipe_service.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Screen showing user's ingredient generation history
class GenerationHistoryScreen extends StatefulWidget {
  const GenerationHistoryScreen({super.key});

  @override
  State<GenerationHistoryScreen> createState() => _GenerationHistoryScreenState();
}

class _GenerationHistoryScreenState extends State<GenerationHistoryScreen> {
  //* Services
  final IngredientRecipeService _ingredientService = IngredientRecipeService();
  final FavoritesState _favoritesState = FavoritesState();

  //* State
  List<IngredientGeneration> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Load generation history
  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _ingredientService.getGenerationHistory(
        _favoritesState.currentUserId,
        limit: 50,
      );

      setState(() {
        _history = history;
        _isLoading = false;
      });

      print('✅ Loaded ${history.length} generation history items');
    } catch (e) {
      setState(() {
        _error = 'Failed to load history';
        _isLoading = false;
      });
      print('❌ Error loading history: $e');
    }
  }

  /// Delete a generation from history
  Future<void> _deleteGeneration(IngredientGeneration generation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('Delete Generation?', style: AppTextStyles.recipeTitle),
        content: Text(
          'Are you sure you want to remove this generation from your history?',
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

    if (confirmed == true) {
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
            SnackBar(
              content: Text('🗑️ Removed from history'),
              backgroundColor: AppColors.textSecondary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete'),
              backgroundColor: AppColors.favorite,
            ),
          );
        }
      }
    }
  }

  /// Clear all history
  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('Clear All History?', style: AppTextStyles.recipeTitle),
        content: Text(
          'This will permanently delete all your generation history. This action cannot be undone.',
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

    if (confirmed == true) {
      try {
        await _ingredientService.clearAllHistory(
          _favoritesState.currentUserId,
        );

        setState(() {
          _history.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ History cleared'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear history'),
              backgroundColor: AppColors.favorite,
            ),
          );
        }
      }
    }
  }

  /// Regenerate recipes from history item
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
              icon: Icon(Icons.delete_sweep),
              onPressed: _clearAllHistory,
              tooltip: 'Clear all history',
            ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    //* Loading state
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryAccent),
            SizedBox(height: AppSpacing.lg),
            Text('Loading history...', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    //* Error state
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.xl),
            Text(_error!, style: AppTextStyles.bodyLarge),
            SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _loadHistory,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    //* Empty state
    if (_history.isEmpty) {
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
              SizedBox(height: AppSpacing.md),
              Text(
                'Your ingredient generations will appear here',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                ),
                child: Text('Generate Recipes'),
              ),
            ],
          ),
        ),
      );
    }

    //* History list
    return RefreshIndicator(
      color: AppColors.primaryAccent,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.lg),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final generation = _history[index];
          return _buildHistoryCard(generation);
        },
      ),
    );
  }

  Widget _buildHistoryCard(IngredientGeneration generation) {
    return GestureDetector(
      onTap: () => _regenerateFromHistory(generation),
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.lg),
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //* Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                //* Date
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
                //* Delete button
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

            //* Ingredients count badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.primaryAccent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: AppColors.primaryAccent,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${generation.ingredients.length} ingredients',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.md),

            //* Ingredients preview
            Text(
              generation.ingredientsSummary,
              style: AppTextStyles.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: AppSpacing.md),

            //* Action button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _regenerateFromHistory(generation),
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text('Regenerate'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}