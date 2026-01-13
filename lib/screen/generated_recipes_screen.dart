import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/screen/recipe_details_screen.dart';
import 'package:meal_palette/service/recipe_cache_service.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/service/ingredient_recipe_service.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/recipe_cards.dart';

/// Screen that displays recipes generated based on user's ingredients
class GeneratedRecipesScreen extends StatefulWidget {
  final List<String> ingredients;

  const GeneratedRecipesScreen({
    super.key,
    required this.ingredients,
  });

  @override
  State<GeneratedRecipesScreen> createState() => _GeneratedRecipesScreenState();
}

class _GeneratedRecipesScreenState extends State<GeneratedRecipesScreen> {
  //* State
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  String? _error;
  
  //* Services
  final FavoritesState _favoritesState = FavoritesState();
  final FirestoreService _firestoreService = FirestoreService();
  final IngredientRecipeService _ingredientRecipeService = 
      IngredientRecipeService();

  @override
  void initState() {
    super.initState();
    _generateRecipes();
    _saveGenerationToHistory();
  }

  /// Generate recipes from ingredients using Spoonacular API
  Future<void> _generateRecipes() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  final recipeCacheService = RecipeCacheService();

  try {
    //* Call Spoonacular API to find recipes by ingredients
    final recipes = await SpoonacularService.findRecipesByIngredients(
      widget.ingredients,
      number: 20,
    );

    if (recipes.isEmpty) {
      setState(() {
        _error = 'No recipes found with these ingredients. Try different ones!';
        _isLoading = false;
      });
      return;
    }

    //* ✨ NEW: Automatically cache ALL generated recipes with full details
    recipeCacheService.cacheRecipes(recipes);

    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });

    print('✅ Generated and cached ${recipes.length} recipes');
  } catch (e) {
    print('❌ Error generating recipes: $e');
    
    //* Try to load from Firestore cache as fallback
    try {
      final cachedRecipes = await _firestoreService.getRecipesPaginated(
        limit: 20,
      );
      
      if (cachedRecipes.isNotEmpty) {
        setState(() {
          _recipes = cachedRecipes;
          _error = 'Showing cached recipes (offline mode)';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to generate recipes. Please check your connection.';
          _isLoading = false;
        });
      }
    } catch (cacheError) {
      setState(() {
        _error = 'Failed to load recipes';
        _isLoading = false;
      });
    }
  }
}

  /// Save this generation to user's history
  Future<void> _saveGenerationToHistory() async {
    try {
      await _ingredientRecipeService.saveIngredientGeneration(
        _favoritesState.currentUserId,
        widget.ingredients,
      );
    } catch (e) {
      print('⚠️ Failed to save to history: $e');
    }
  }

  /// Handle favorite toggle
  Future<void> _handleFavoriteToggle(Recipe recipe) async {
    await _favoritesState.toggleFavorite(recipe);
    
    if (mounted) {
      final isFavorite = _favoritesState.isFavorite(recipe.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? '❤️ Added to favorites' : '💔 Removed from favorites',
          ),
          duration: Duration(seconds: 2),
          backgroundColor: isFavorite 
              ? AppColors.success 
              : AppColors.textSecondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Generated Recipes'),
        actions: [
          // Save this meal plan button
          IconButton(
            icon: Icon(Icons.bookmark_border),
            onPressed: () {
              // TODO: Implement save meal plan
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Meal plan saved!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          //* Ingredients Used Section
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primaryAccent,
                      size: 20,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Using ${widget.ingredients.length} ingredients',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: widget.ingredients
                      .map(
                        (ingredient) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            ingredient,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.lg),

          //* Recipes List
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
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
            Text(
              'Finding perfect recipes...',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    //* Error state
    if (_error != null && _recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: AppColors.textTertiary,
              ),
              SizedBox(height: AppSpacing.xl),
              Text(
                'No Recipes Found',
                style: AppTextStyles.recipeTitle,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                _error!,
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
                child: Text('Try Different Ingredients'),
              ),
            ],
          ),
        ),
      );
    }

    //* Success - show recipes
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Found ${_recipes.length} Recipes',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_error != null && _recipes.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 14,
                        color: AppColors.info,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: _recipes.length,
            itemBuilder: (context, index) {
              final recipe = _recipes[index];
              return AnimatedBuilder(
                animation: _favoritesState,
                builder: (context, child) {
                  return RecipeCardVertical(
                    imageUrl: recipe.image ?? '',
                    title: recipe.title,
                    time: recipe.readyInMinutes != null 
                        ? '${recipe.readyInMinutes} min' 
                        : 'N/A',
                    servings: recipe.servings != null 
                        ? '${recipe.servings}' 
                        : 'N/A',
                    difficulty: _getDifficulty(recipe),
                    isFavorite: _favoritesState.isFavorite(recipe.id),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeDetailScreen(
                            recipeId: recipe.id,
                          ),
                        ),
                      );
                    },
                    onFavoritePressed: () => _handleFavoriteToggle(recipe),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Helper to determine difficulty based on time
  String _getDifficulty(Recipe recipe) {
    if (recipe.readyInMinutes == null) return 'Medium';
    if (recipe.readyInMinutes! <= 20) return 'Easy';
    if (recipe.readyInMinutes! <= 45) return 'Medium';
    return 'Hard';
  }
}