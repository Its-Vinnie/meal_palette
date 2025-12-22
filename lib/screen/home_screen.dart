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
  List<Recipe> _categoryRecipes = [];
  bool _isLoadingTrending = true;
  bool _isLoadingCategory = false;

  //* Category state
  String _selectedCategory = 'Western';
  
  //* Favorites state management
  final FavoritesState _favoritesState = FavoritesState();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _favoritesState.loadFavorites();
  }

  /// Loads recipes from API with Firestore fallback
  Future<void> _loadRecipes() async {
    final firestoreService = FirestoreService();

    //* Load trending recipes (horizontal scroll)
    try {
      //* Try API first
      final trending = await SpoonacularService.getRandomRecipes(number: 6);
      
      //* Save trending recipes to Firestore in background
      _saveRecipesToFirestore(trending, firestoreService);
      
      setState(() {
        _trendingRecipes = trending;
        _isLoadingTrending = false;
      });
      
      print('✅ Loaded trending recipes from API');
    } catch (e) {
      print('⚠️ API limit reached, loading from Firestore: $e');
      
      //* Fallback to Firestore
      try {
        final cachedRecipes = await firestoreService.getRecipesPaginated(limit: 6);
        
        setState(() {
          _trendingRecipes = cachedRecipes;
          _isLoadingTrending = false;
        });
        
        print('✅ Loaded ${cachedRecipes.length} recipes from Firestore cache');
      } catch (firestoreError) {
        print('❌ Error loading from Firestore: $firestoreError');
        setState(() {
          _isLoadingTrending = false;
        });
      }
    }

    //* Load initial category recipes
    _loadCategoryRecipes(_selectedCategory);
  }

  /// Loads recipes for a specific category with Firestore fallback
  Future<void> _loadCategoryRecipes(String category) async {
    setState(() {
      _isLoadingCategory = true;
      _selectedCategory = category;
    });

    final firestoreService = FirestoreService();

    try {
      //* Try API first
      final searchQuery = _getCategorySearchQuery(category);
      
      final recipes = await SpoonacularService.searchRecipes(
        query: searchQuery,
        number: 5,
      );
      
      //* Save category recipes to Firestore in background
      _saveRecipesToFirestore(recipes, firestoreService);
      
      setState(() {
        _categoryRecipes = recipes;
        _isLoadingCategory = false;
      });
      
      print('✅ Loaded ${recipes.length} recipes for category: $category from API');
    } catch (e) {
      print('⚠️ API limit reached for category, loading from Firestore: $e');
      
      //* Fallback to Firestore - use category-based search
      try {
        final cachedRecipes = await firestoreService.getRecipesByCategory(
          category,
          limit: 5,
        );
        
        setState(() {
          _categoryRecipes = cachedRecipes;
          _isLoadingCategory = false;
        });
        
        print('✅ Loaded ${cachedRecipes.length} recipes from Firestore for: $category');
      } catch (firestoreError) {
        print('❌ Error loading from Firestore: $firestoreError');
        setState(() {
          _isLoadingCategory = false;
        });
      }
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

  /// Saves recipes to Firestore in the background
  Future<void> _saveRecipesToFirestore(
      List<Recipe> recipes, FirestoreService service) async {
    try {
      await service.saveRecipesBatch(recipes);
      print('💾 Saved ${recipes.length} recipes to Firestore database');
    } catch (e) {
      print('⚠️ Failed to save recipes to Firestore: $e');
    }
  }

  /// Handles favorite button press with state management
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
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryAccent,
          onRefresh: () async {
            setState(() {
              _isLoadingTrending = true;
              _isLoadingCategory = true;
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
                      print('Search: $value');
                    },
                  ),

                  SizedBox(height: AppSpacing.xl),

                  //* Category Icons with proper styling
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryIcon(
                          icon: Icons.restaurant,
                          label: "Western",
                          isActive: _selectedCategory == "Western",
                        ),
                        SizedBox(width: AppSpacing.md),
                        _buildCategoryIcon(
                          icon: Icons.bakery_dining,
                          label: "Bread",
                          isActive: _selectedCategory == "Bread",
                        ),
                        SizedBox(width: AppSpacing.md),
                        _buildCategoryIcon(
                          icon: Icons.soup_kitchen,
                          label: "Soup",
                          isActive: _selectedCategory == "Soup",
                        ),
                        SizedBox(width: AppSpacing.md),
                        _buildCategoryIcon(
                          icon: Icons.cake,
                          label: "Dessert",
                          isActive: _selectedCategory == "Dessert",
                        ),
                        SizedBox(width: AppSpacing.md),
                        _buildCategoryIcon(
                          icon: Icons.local_cafe,
                          label: "Coffee",
                          isActive: _selectedCategory == "Coffee",
                        ),
                      ],
                    ),
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

                  //* Horizontal Scrolling Recipe Cards
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

                  //* Section Header: Category Recipes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$_selectedCategory Recipes",
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          print("See more $_selectedCategory clicked");
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

                  //* Vertical Recipe Cards for Selected Category
                  _isLoadingCategory
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xxl),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        )
                      : _categoryRecipes.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.xxl),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      size: 64,
                                      color: AppColors.textTertiary,
                                    ),
                                    SizedBox(height: AppSpacing.lg),
                                    Text(
                                      'No $_selectedCategory recipes found',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: _categoryRecipes.map((recipe) {
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

  /// Builds category icon widget with improved design
  Widget _buildCategoryIcon(
    {required IconData icon, 
    required String label, 
    required bool isActive}
  ) {
    return GestureDetector(
      onTap: () {
        //* Load recipes for selected category
        _loadCategoryRecipes(label);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isActive 
              ? AppColors.primaryAccent 
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isActive 
                ? AppColors.primaryAccent 
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primaryAccent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive 
                  ? AppColors.textPrimary 
                  : AppColors.textSecondary,
              size: 24,
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: isActive 
                    ? AppColors.textPrimary 
                    : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}