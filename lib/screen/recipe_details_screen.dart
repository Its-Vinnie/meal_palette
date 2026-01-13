import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/screen/cook_along_checklist_screen.dart';
import 'package:meal_palette/service/recipe_cache_service.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/add_to_collection_modal.dart';

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
  final recipeCacheService = RecipeCacheService();

  try {
    //* ✨ NEW: Use cache service which checks Firestore first, then API
    final recipe = await recipeCacheService.getRecipeDetails(widget.recipeId);

    if (recipe == null) {
      setState(() {
        _error = 'Recipe details not available';
        _isLoading = false;
      });
      return;
    }

    //* Track that user viewed this recipe
    await _firestoreService.trackRecipeView(
      _favoritesState.currentUserId,
      recipe.id,
    );

    setState(() {
      _recipe = recipe;
      _isLoading = false;
      _isUsingCache = false; // Cache service handles this internally
    });

    print('✅ Recipe loaded: ${recipe.title}');
  } catch (e) {
    setState(() {
      _error = 'Failed to load recipe details';
      _isLoading = false;
    });
    print('❌ Error loading recipe: $e');
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
          duration: const Duration(seconds: 2),
          backgroundColor:
              isNowFavorite ? AppColors.success : AppColors.textSecondary,
        ),
      );
    }
  }

  /// Handles add to collections button press
  Future<void> _handleAddToCollections() async {
    if (_recipe == null) return;

    final basicRecipe = Recipe(
      id: _recipe!.id,
      title: _recipe!.title,
      image: _recipe!.image,
      readyInMinutes: _recipe!.readyInMinutes,
      servings: _recipe!.servings,
      summary: _recipe!.summary,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToCollectionModal(recipe: basicRecipe),
    );
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
                  _error ??
                      'This recipe hasn\'t been cached yet. Please try viewing it when you have an active internet connection.',
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
              //* Cook Along Mode button - Quick access
              if (_recipe!.ingredients.isNotEmpty &&
                  _recipe!.instructions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryAccent,
                          AppColors.secondaryAccent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CookAlongChecklistScreen(
                              recipe: _recipe!,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Start Cook Along',
                    ),
                  ),
                ),
              //* Bookmark button for collections
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.bookmark_add_outlined,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: _handleAddToCollections,
                  ),
                ),
              ),
              //* Favorite button with state management
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedBuilder(
                  animation: _favoritesState,
                  builder: (context, child) {
                    final isFavorite = _favoritesState.isFavorite(_recipe!.id);
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
              titlePadding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
              ),
              title: Text(
                _recipe!.title,
                style: AppTextStyles.recipeTitle.copyWith(
                  fontSize: 18,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                  //* Enhanced gradient overlay - starts from middle, darker at bottom
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                        stops: [0.0, 0.4, 0.7, 1.0],
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
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
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

                  //* Cook Along Mode Button - Prominent placement
                  if (_recipe!.ingredients.isNotEmpty &&
                      _recipe!.instructions.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: AppSpacing.xxl),
                      child: Material(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        elevation: 4,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CookAlongChecklistScreen(
                                  recipe: _recipe!,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryAccent,
                                  AppColors.secondaryAccent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.play_circle_filled,
                                      size: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.md),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Cook Along Mode',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'AI voice-guided step-by-step cooking',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white.withValues(alpha: 0.95),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

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
