import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/screen/recipe_details_screen.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/recipe_cards.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //* State variables for recipes
  List<Recipe> _trendingRecipes = [];
  List<Recipe> _popularRecipes = [];
  bool _isLoadingTrending = true;
  bool _isLoadingPopular = true;

  //* Favorites state management
  final FavoritesState _favoritesState = FavoritesState();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _favoritesState.loadFavorites(); // Load favorites on startup
  }

  /// Loads recipes from API and saves them to Firestore
  Future<void> _loadRecipes() async {
    final firestoreService = FirestoreService();

    //* Load trending recipes (horizontal scroll)
    try {
      final trending = await SpoonacularService.getRandomRecipes(number: 6);
      
      //* Save trending recipes to Firestore in background
      _saveRecipesToFirestore(trending, firestoreService);
      
      setState(() {
        _trendingRecipes = trending;
        _isLoadingTrending = false;
      });
    } catch (e) {
      print('❌ Error loading trending recipes: $e');
      setState(() {
        _isLoadingTrending = false;
      });
    }

    //* Load popular recipes (vertical cards)
    try {
      final popular = await SpoonacularService.searchRecipes(
        query: 'pasta',
        number: 5,
      );
      
      //* Save popular recipes to Firestore in background
      _saveRecipesToFirestore(popular, firestoreService);
      
      setState(() {
        _popularRecipes = popular;
        _isLoadingPopular = false;
      });
    } catch (e) {
      print('❌ Error loading popular recipes: $e');
      setState(() {
        _isLoadingPopular = false;
      });
    }
  }

  /// Saves recipes to Firestore in the background
  /// Doesn't block the UI or throw errors
  Future<void> _saveRecipesToFirestore(
      List<Recipe> recipes, FirestoreService service) async {
    try {
      await service.saveRecipesBatch(recipes);
      print('💾 Saved ${recipes.length} recipes to Firestore database');
    } catch (e) {
      print('⚠️ Failed to save recipes to Firestore: $e');
      // Silent failure - don't interrupt user experience
    }
  }

  /// Handles favorite button press with state management
  Future<void> _handleFavoritePressed(Recipe recipe) async {
    final isNowFavorite = await _favoritesState.toggleFavorite(recipe);

    //* Show feedback
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
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryAccent,
          onRefresh: () async {
            setState(() {
              _isLoadingTrending = true;
              _isLoadingPopular = true;
            });
            await _loadRecipes();
          },
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //* Header Row with Profile and Notifications
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          //* Profile Avatar
                          Container(
                            decoration: AppDecorations.iconButtonDecoration,
                            child: IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.person,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          //* Greeting
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "Hi Vincent ",
                                  style: AppTextStyles.bodyLarge,
                                ),
                                TextSpan(text: "👋🏼"),
                              ],
                            ),
                          ),
                        ],
                      ),
                      //* Notifications
                      Container(
                        decoration: AppDecorations.iconButtonDecoration,
                        child: IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xl),

                  //* Main Headline
                  Text(
                    "What's cooking\ntoday?",
                    style: AppTextStyles.pageHeadline,
                  ),

                  SizedBox(height: AppSpacing.xl),

                  //* Search Bar
                  TextField(
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search recipes...",
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textTertiary,
                      ),
                      suffixIcon: Container(
                        margin: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (value) {
                      //* TODO: Navigate to search screen with query
                      print('Search: $value');
                    },
                  ),

                  SizedBox(height: AppSpacing.xl),

                  //* Category Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCategoryIcon(Icons.lunch_dining, "Western", true),
                      _buildCategoryIcon(Icons.bakery_dining, "Bread", false),
                      _buildCategoryIcon(Icons.soup_kitchen, "Soup", false),
                      _buildCategoryIcon(Icons.cake, "Dessert", false),
                      _buildCategoryIcon(Icons.coffee, "Coffee", false),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  //* Section Header: Trending Recipes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Trending Recipes",
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          print("See more trending clicked");
                        },
                        child: Row(
                          children: [
                            Text(
                              "See More",
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.primaryAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              color: AppColors.primaryAccent,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.lg),

                  //* Horizontal Scrolling Recipe Cards with Favorites
                  SizedBox(
                    height: 200,
                    child: _isLoadingTrending
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryAccent,
                            ),
                          )
                        : _trendingRecipes.isEmpty
                            ? Center(
                                child: Text(
                                  'No trending recipes found',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _trendingRecipes.length,
                                itemBuilder: (context, index) {
                                  final recipe = _trendingRecipes[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: index == _trendingRecipes.length - 1
                                          ? 0
                                          : AppSpacing.lg,
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _favoritesState,
                                      builder: (context, child) {
                                        return RecipeCard(
                                          imageUrl: recipe.image ??
                                              'assets/images/placeholder.png',
                                          title: recipe.title,
                                          time:
                                              '${recipe.readyInMinutes ?? 0} min',
                                          isFavorite: _favoritesState
                                              .isFavorite(recipe.id),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RecipeDetailScreen(
                                                  recipeId: recipe.id,
                                                ),
                                              ),
                                            );
                                          },
                                          onFavoritePressed: () =>
                                              _handleFavoritePressed(recipe),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  //* Section Header: Popular
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Popular This Week",
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          print("See more popular clicked");
                        },
                        child: Row(
                          children: [
                            Text(
                              "See More",
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.primaryAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              color: AppColors.primaryAccent,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.lg),

                  //* Vertical Recipe Cards with Favorites
                  _isLoadingPopular
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xxl),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        )
                      : _popularRecipes.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.xxl),
                                child: Text(
                                  'No popular recipes found',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            )
                          : Column(
                              children: _popularRecipes.map((recipe) {
                                return AnimatedBuilder(
                                  animation: _favoritesState,
                                  builder: (context, child) {
                                    return RecipeCardVertical(
                                      imageUrl: recipe.image ??
                                          'assets/images/placeholder.png',
                                      title: recipe.title,
                                      time:
                                          '${recipe.readyInMinutes ?? 0} min',
                                      servings:
                                          '${recipe.servings ?? 0} servings',
                                      difficulty: 'Medium',
                                      isFavorite: _favoritesState
                                          .isFavorite(recipe.id),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                RecipeDetailScreen(
                                              recipeId: recipe.id,
                                            ),
                                          ),
                                        );
                                      },
                                      onFavoritePressed: () =>
                                          _handleFavoritePressed(recipe),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds category icon widget
  Widget _buildCategoryIcon(IconData icon, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        //* TODO: Filter recipes by category
        print('Category selected: $label');
      },
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: isActive
                ? AppDecorations.activeCategoryIconDecoration
                : AppDecorations.categoryIconDecoration,
            child: Icon(
              icon,
              color:
                  isActive ? AppColors.primaryAccent : AppColors.textPrimary,
              size: 28,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: isActive
                  ? AppColors.primaryAccent
                  : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}