import 'package:flutter/material.dart';
import 'package:meal_palette/screen/recipe_details_screen.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/model/recipe_model.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  //* Favorites state management
  final FavoritesState _favoritesState = FavoritesState();

  @override
  void initState() {
    super.initState();
    //* Load favorites when screen opens
    _loadFavorites();
  }

  /// Loads favorite recipes from Firestore
  Future<void> _loadFavorites() async {
    await _favoritesState.loadFavorites();
  }

  /// Handles removing a recipe from favorites
  Future<void> _handleRemoveFavorite(Recipe recipe) async {
    //* Show confirmation dialog
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('Remove from Favorites?', style: AppTextStyles.recipeTitle),
        content: Text(
          'Are you sure you want to remove "${recipe.title}" from your favorites?',
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
            child: Text('Remove'),
          ),
        ],
      ),
    );

    //* Remove if confirmed
    if (shouldRemove == true) {
      await _favoritesState.removeFavorite(recipe.id);

      //* Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💔 Removed from favorites'),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //* Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Favorites", style: AppTextStyles.pageHeadline),
                  //* Favorite count badge
                  AnimatedBuilder(
                    animation: _favoritesState,
                    builder: (context, child) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.primaryAccent),
                        ),
                        child: Text(
                          '${_favoritesState.favoriteCount}',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.xl),

              //* Content - favorites list or empty state
              Expanded(
                child: AnimatedBuilder(
                  animation: _favoritesState,
                  builder: (context, child) {
                    //* Loading state
                    if (_favoritesState.isLoading) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.primaryAccent,
                            ),
                            SizedBox(height: AppSpacing.lg),
                            Text(
                              'Loading favorites...',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    //* Empty state
                    if (_favoritesState.favoriteRecipes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bookmark_border,
                              size: 64,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(height: AppSpacing.lg),
                            Text(
                              "No favorites yet",
                              style: AppTextStyles.recipeTitle,
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              "Start adding recipes you love!",
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    //* List of favorites
                    return RefreshIndicator(
                      color: AppColors.primaryAccent,
                      onRefresh: _loadFavorites,
                      child: ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        itemCount: _favoritesState.favoriteRecipes.length,
                        itemBuilder: (context, index) {
                          final recipe =
                              _favoritesState.favoriteRecipes[index];
                          return _buildFavoriteCard(recipe);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a favorite recipe card
  Widget _buildFavoriteCard(Recipe recipe) {
    return GestureDetector(
      onTap: () {
        //* Navigate to recipe details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            //* Recipe Image
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.xl),
                bottomLeft: Radius.circular(AppRadius.xl),
              ),
              child: recipe.image != null
                  ? Image.network(
                      recipe.image!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    )
                  : _buildPlaceholderImage(),
            ),

            //* Recipe Info
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //* Title
                    Text(
                      recipe.title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: AppSpacing.sm),

                    //* Time and Servings
                    Row(
                      children: [
                        if (recipe.readyInMinutes != null) ...[
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${recipe.readyInMinutes} min',
                            style: AppTextStyles.labelMedium,
                          ),
                        ],
                        if (recipe.servings != null) ...[
                          SizedBox(width: AppSpacing.md),
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${recipe.servings}',
                            style: AppTextStyles.labelMedium,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            //* Remove button
            IconButton(
              icon: Icon(
                Icons.favorite,
                color: AppColors.favorite,
              ),
              onPressed: () => _handleRemoveFavorite(recipe),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds placeholder image widget
  Widget _buildPlaceholderImage() {
    return Container(
      width: 120,
      height: 120,
      color: AppColors.surface,
      child: Icon(
        Icons.restaurant,
        color: AppColors.textTertiary,
        size: 48,
      ),
    );
  }
}