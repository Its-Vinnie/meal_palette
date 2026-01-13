import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/screen/recipe_details_screen.dart';
import 'package:meal_palette/service/recipe_cache_service.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Screen to display a list of recipes based on type or category
/// Supports pagination and handles both trending and category-based recipes
class RecipesListScreen extends StatefulWidget {
  final String title;
  final RecipeListType type;
  final String? category; // Required for category type

  const RecipesListScreen({
    super.key,
    required this.title,
    required this.type,
    this.category,
  });

  @override
  State<RecipesListScreen> createState() => _RecipesListScreenState();
}

/// Enum to define the type of recipe list
enum RecipeListType {
  trending,
  category,
  search,
}

class _RecipesListScreenState extends State<RecipesListScreen> {
  //* Services
  final FirestoreService _firestoreService = FirestoreService();
  final RecipeCacheService _recipeCacheService = RecipeCacheService();
  final FavoritesState _favoritesState = FavoritesState();

  //* State variables
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreRecipes = true;

  //* Pagination
  static const int _recipesPerPage = 20;

  //* Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Handle scroll for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreRecipes) {
      _loadMoreRecipes();
    }
  }

  /// Load initial recipes based on type
  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Recipe> recipes = [];

      switch (widget.type) {
        case RecipeListType.trending:
          recipes = await _loadTrendingRecipes();
          break;
        case RecipeListType.category:
          if (widget.category != null) {
            recipes = await _loadCategoryRecipes(widget.category!);
          }
          break;
        case RecipeListType.search:
          // Can be extended for search functionality
          break;
      }

      //* Cache recipes in background
      if (recipes.isNotEmpty) {
        _recipeCacheService.cacheRecipes(recipes);
      }

      setState(() {
        _recipes = recipes;
        _isLoading = false;
        _hasMoreRecipes = recipes.length >= _recipesPerPage;
      });
    } catch (e) {
      print('❌ Error loading recipes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load more recipes (pagination)
  Future<void> _loadMoreRecipes() async {
    if (_isLoadingMore || !_hasMoreRecipes) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      List<Recipe> moreRecipes = [];

      switch (widget.type) {
        case RecipeListType.trending:
          moreRecipes = await _loadTrendingRecipes();
          break;
        case RecipeListType.category:
          if (widget.category != null) {
            moreRecipes = await _loadCategoryRecipes(widget.category!);
          }
          break;
        case RecipeListType.search:
          break;
      }

      //* Cache new recipes
      if (moreRecipes.isNotEmpty) {
        _recipeCacheService.cacheRecipes(moreRecipes);
      }

      setState(() {
        _recipes.addAll(moreRecipes);
        _isLoadingMore = false;
        _hasMoreRecipes = moreRecipes.length >= _recipesPerPage;
      });
    } catch (e) {
      print('❌ Error loading more recipes: $e');
      setState(() {
        _isLoadingMore = false;
        _hasMoreRecipes = false;
      });
    }
  }

  /// Load trending recipes
  Future<List<Recipe>> _loadTrendingRecipes() async {
    try {
      //* Try API first
      final recipes = await SpoonacularService.getRandomRecipes(
        number: _recipesPerPage,
      );
      return recipes;
    } catch (e) {
      print('⚠️ API limit reached, loading from Firestore: $e');

      //* Fallback to Firestore
      final cachedRecipes = await _firestoreService.getRecipesPaginated(
        limit: _recipesPerPage,
      );
      return cachedRecipes;
    }
  }

  /// Load category recipes
  Future<List<Recipe>> _loadCategoryRecipes(String category) async {
    try {
      //* Try API first
      final searchQuery = _getCategorySearchQuery(category);
      final recipes = await SpoonacularService.searchRecipes(
        searchQuery,
        number: _recipesPerPage,
      );
      return recipes;
    } catch (e) {
      print('⚠️ API limit reached, loading from Firestore: $e');

      //* Fallback to Firestore
      final cachedRecipes = await _firestoreService.getRecipesByCategory(
        category,
        limit: _recipesPerPage,
      );
      return cachedRecipes;
    }
  }

  /// Maps category name to appropriate search query
  String _getCategorySearchQuery(String category) {
    switch (category.toLowerCase()) {
      case 'western':
        return 'american burger steak';
      case 'bread':
        return 'bread baked goods';
      case 'soup':
        return 'soup';
      case 'dessert':
        return 'dessert cake';
      case 'coffee':
        return 'coffee drink beverage';
      default:
        return category;
    }
  }

  /// Handle favorite button press
  Future<void> _handleFavoritePressed(Recipe recipe) async {
    final isNowFavorite = await _favoritesState.toggleFavorite(recipe);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowFavorite
                ? '❤️ Added to favorites'
                : '💔 Removed from favorites',
          ),
          duration: Duration(seconds: 1),
          backgroundColor:
              isNowFavorite ? AppColors.success : AppColors.textSecondary,
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
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
        ),
        title: Text(
          widget.title,
          style: AppTextStyles.recipeTitle.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primaryAccent,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    Text(
                      'Loading delicious recipes...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : _recipes.isEmpty
                ? _buildEmptyState()
                : _buildRecipeGrid(),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'No recipes found',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Try refreshing or check back later',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: _loadRecipes,
              icon: Icon(Icons.refresh),
              label: Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build recipe grid
  Widget _buildRecipeGrid() {
    return RefreshIndicator(
      color: AppColors.primaryAccent,
      onRefresh: _loadRecipes,
      child: CustomScrollView(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          //* Recipe count header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_recipes.length} recipes found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  //* Filter button (can be implemented later)
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: AppColors.primaryAccent,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          //* Recipe grid
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final recipe = _recipes[index];
                  return AnimatedBuilder(
                    animation: _favoritesState,
                    builder: (context, child) {
                      return _buildRecipeGridItem(recipe);
                    },
                  );
                },
                childCount: _recipes.length,
              ),
            ),
          ),

          //* Loading more indicator
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryAccent,
                  ),
                ),
              ),
            ),

          //* End message
          if (!_hasMoreRecipes && _recipes.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    'You\'ve reached the end!',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),

          //* Bottom spacing
          SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xl),
          ),
        ],
      ),
    );
  }

  /// Build individual recipe grid item
  Widget _buildRecipeGridItem(Recipe recipe) {
    return GestureDetector(
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
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //* Image with favorite button
            Stack(
              children: [
                //* Recipe image
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.lg),
                      topRight: Radius.circular(AppRadius.lg),
                    ),
                    image: recipe.image != null
                        ? DecorationImage(
                            image: NetworkImage(recipe.image!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: AppColors.background,
                  ),
                  child: recipe.image == null
                      ? Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : null,
                ),

                //* Favorite button
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: () => _handleFavoritePressed(recipe),
                    child: Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _favoritesState.isFavorite(recipe.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _favoritesState.isFavorite(recipe.id)
                            ? AppColors.favorite
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            //* Recipe info
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //* Title
                    Text(
                      recipe.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    Spacer(),

                    //* Time and servings
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${recipe.readyInMinutes ?? 30} min',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        if (recipe.servings != null) ...[
                          SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${recipe.servings}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
