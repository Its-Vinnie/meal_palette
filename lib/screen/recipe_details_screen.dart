import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  //* Recipe data
  RecipeDetail? _recipe;
  bool _isLoading = true;
  String? _error;
  bool _isUsingCache = false; // Track if using cached data

  //* Services and state
  final FirestoreService _firestoreService = FirestoreService();
  final FavoritesState _favoritesState = FavoritesState();

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  /// Loads recipe details from API with Firestore fallback
  Future<void> _loadRecipe() async {
    try {
      //* Try API first
      final recipe = await SpoonacularService.getRecipeDetails(widget.recipeId);

      //* Save detailed recipe to Firestore
      await _firestoreService.saveDetailedRecipe(recipe);

      //* Track that user viewed this recipe
      await _firestoreService.trackRecipeView(
        _favoritesState.currentUserId,
        recipe.id,
      );

      //* Update UI
      setState(() {
        _recipe = recipe;
        _isLoading = false;
        _isUsingCache = false;
      });

      print("✅ Recipe loaded from API and saved: ${recipe.title}");
    } catch (e) {
      print("⚠️ API limit reached, loading from Firestore: $e");
      
      //* Fallback to Firestore
      try {
        final cachedRecipeData = await _firestoreService.getRecipe(
          widget.recipeId.toString(),
        );

        if (cachedRecipeData != null) {
          //* Convert to RecipeDetail
          final cachedRecipe = RecipeDetail.fromJson(cachedRecipeData);

          //* Track view even from cache
          await _firestoreService.trackRecipeView(
            _favoritesState.currentUserId,
            cachedRecipe.id,
          );

          setState(() {
            _recipe = cachedRecipe;
            _isLoading = false;
            _isUsingCache = true;
          });

          print("✅ Recipe loaded from Firestore cache: ${cachedRecipe.title}");
        } else {
          //* Recipe not in cache
          setState(() {
            _error = 'Recipe details not available offline. Please try again when connected.';
            _isLoading = false;
          });
          print("❌ Recipe not found in cache: ${widget.recipeId}");
        }
      } catch (cacheError) {
        setState(() {
          _error = 'Failed to load recipe details';
          _isLoading = false;
        });
        print("❌ Error loading from Firestore: $cacheError");
      }
    }
  }

  /// Handles favorite button press
  Future<void> _handleFavoritePressed() async {
    if (_recipe == null) return;

    //* Convert RecipeDetail to Recipe for favorites
    final basicRecipe = Recipe(
      id: _recipe!.id,
      title: _recipe!.title,
      image: _recipe!.image,
      readyInMinutes: _recipe!.readyInMinutes,
      servings: _recipe!.servings,
      summary: _recipe!.summary,
    );

    //* Toggle favorite status
    final isNowFavorite = await _favoritesState.toggleFavorite(basicRecipe);

    //* Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowFavorite
                ? '❤️ Added to favorites'
                : '💔 Removed from favorites',
          ),
          duration: Duration(seconds: 2),
          backgroundColor: isNowFavorite
              ? AppColors.success
              : AppColors.textSecondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    //* Loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryAccent),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Loading recipe...',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    //* Error state
    if (_error != null || _recipe == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: AppSpacing.xl),
                Text(
                  'Recipe Not Available',
                  style: AppTextStyles.recipeTitle,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  _error ?? 'This recipe hasn\'t been cached yet. Please try viewing it when you have an active internet connection.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.textTertiary),
                      ),
                      child: Text('Go Back'),
                    ),
                    SizedBox(width: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _loadRecipe();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                      ),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    //* Success state - show recipe details
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          //* App Bar with Image and Favorite Button
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: Padding(
              padding: EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              //* Favorite button with state management
              Padding(
                padding: EdgeInsets.all(8.0),
                child: AnimatedBuilder(
                  animation: _favoritesState,
                  builder: (context, child) {
                    final isFavorite =
                        _favoritesState.isFavorite(_recipe!.id);
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite
                              ? AppColors.favorite
                              : AppColors.textPrimary,
                        ),
                        onPressed: _handleFavoritePressed,
                      ),
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.overlayDark.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _recipe!.title,
                  style: AppTextStyles.recipeTitle.copyWith(fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  //* Recipe image
                  _recipe!.image != null
                      ? Image.network(
                          _recipe!.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.surface,
                              child: Icon(
                                Icons.restaurant_menu,
                                size: 64,
                                color: AppColors.textTertiary,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.surface,
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                        ),
                  //* Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          //* Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //* Cache indicator
                  if (_isUsingCache)
                    Container(
                      margin: EdgeInsets.only(bottom: AppSpacing.lg),
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.info.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storage,
                            color: AppColors.info,
                            size: 20,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Showing cached recipe details',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  //* Info Row (time, servings)
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

                  //* Dietary Tags
                  if (_recipe!.vegetarian ||
                      _recipe!.vegan ||
                      _recipe!.glutenFree ||
                      _recipe!.dairyFree) ...[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (_recipe!.vegetarian) _buildTag('🥬 Vegetarian'),
                        if (_recipe!.vegan) _buildTag('🌱 Vegan'),
                        if (_recipe!.glutenFree) _buildTag('🌾 Gluten Free'),
                        if (_recipe!.dairyFree) _buildTag('🥛 Dairy Free'),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xxl),
                  ],

                  //* Ingredients Section
                  Text('Ingredients', style: AppTextStyles.recipeTitle),
                  SizedBox(height: AppSpacing.lg),

                  if (_recipe!.ingredients.isEmpty)
                    Container(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'No ingredients information available.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._recipe!.ingredients.map(
                      (ingredient) => Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: EdgeInsets.only(top: 6, right: 12),
                              decoration: BoxDecoration(
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
                      ),
                    ),

                  SizedBox(height: AppSpacing.xxl),

                  //* Instructions Section
                  Text('Instructions', style: AppTextStyles.recipeTitle),
                  SizedBox(height: AppSpacing.lg),

                  if (_recipe!.instructions.isEmpty)
                    Container(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'No detailed instructions available for this recipe.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._recipe!.instructions.map((instruction) {
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
                            //* Step number
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
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.lg),
                            //* Step description
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

                  SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds info chip widget (time, servings)
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

  /// Builds dietary tag widget
  Widget _buildTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.2),
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