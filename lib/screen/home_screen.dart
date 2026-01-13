import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/screen/manage_groceries_screen.dart';
import 'package:meal_palette/screen/profile_screen.dart';
import 'package:meal_palette/screen/recipe_details_screen.dart';
import 'package:meal_palette/screen/recipe_search_screen.dart';
import 'package:meal_palette/screen/recipes_list_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/service/recipe_cache_service.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/state/grocery_state.dart';
import 'package:meal_palette/state/user_preferences_state.dart';
import 'package:meal_palette/state/user_profile_state.dart';
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

  FirestoreService firestoreService = FirestoreService();

  //* Category state
  String _selectedCategory = 'Trending';

  //* State management
  final FavoritesState _favoritesState = FavoritesState();
  final UserProfileState _userProfileState = UserProfileState();
  final UserPreferencesState _preferencesState = userPreferencesState;
  final GroceryState _groceryState = groceryState;

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndRecipes();
    _favoritesState.loadFavorites();
    // Schedule grocery loading after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroceriesAndRecipes();
    });
  }

  /// Load user preferences first, then load recipes with filters
  Future<void> _loadPreferencesAndRecipes() async {
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      await _preferencesState.loadPreferences(userId);
    }
    await _loadRecipes();
  }

  /// Load groceries and generate recipes from them
  Future<void> _loadGroceriesAndRecipes() async {
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      await _groceryState.loadGroceries(userId);
      if (_groceryState.hasGroceries) {
        await _groceryState.generateRecipes(number: 6);
      }
    }
  }

  Future<void> _loadRecipes() async {
    final recipeCacheService = RecipeCacheService();

    //* Get user preferences for filtering
    final preferences = _preferencesState.preferences;
    final diet = preferences?.dietaryRestrictions.isNotEmpty == true
        ? preferences!.dietaryRestrictions.first
        : null;
    final cuisine = preferences?.cuisinePreferences.isNotEmpty == true
        ? preferences!.cuisinePreferences.first
        : null;
    final maxReadyTime = preferences?.maxReadyTime;
    final mealTypes = preferences?.mealTypePreferences;

    // Debug logging for preferences
    if (preferences != null) {
      print('Loading recipes with preferences:');
      print('  Diet: $diet');
      print('  Cuisine: $cuisine');
      print('  Max ready time: $maxReadyTime');
      print('  Meal types: $mealTypes');
    }

    //* Load trending recipes
    try {
      //* Try API first with user preferences
      final trending = await SpoonacularService.getRandomRecipes(
        number: 6,
        diet: diet,
        cuisine: cuisine,
        maxReadyTime: maxReadyTime,
        mealTypes: mealTypes,
      );

      //* ✨ NEW: Automatically cache these recipes with full details
      recipeCacheService.cacheRecipes(trending);

      setState(() {
        _trendingRecipes = trending;
        _isLoadingTrending = false;
      });

      print('✅ Loaded ${trending.length} trending recipes from API');
    } catch (e) {
      print('⚠️ API limit reached, loading from Firestore: $e');

      //* Fallback to Firestore
      try {
        final cachedRecipes = await firestoreService.getRecipesPaginated(
          limit: 6,
        );

        setState(() {
          _trendingRecipes = cachedRecipes;
          _isLoadingTrending = false;
        });

        print('✅ Loaded ${cachedRecipes.length} recipes from cache');
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

  Future<void> _loadCategoryRecipes(String category) async {
    setState(() {
      _isLoadingCategory = true;
      _selectedCategory = category;
    });

    // Special handling for "My Groceries" category
    if (category == "My Groceries") {
      // Use already generated grocery-based recipes
      setState(() {
        _categoryRecipes = _groceryState.generatedRecipes.take(5).toList();
        _isLoadingCategory = false;
      });
      return;
    }

    final recipeCacheService = RecipeCacheService();

    //* Get user preferences for filtering
    final preferences = _preferencesState.preferences;
    final diet = preferences?.dietaryRestrictions.isNotEmpty == true
        ? preferences!.dietaryRestrictions.first
        : null;
    final maxReadyTime = preferences?.maxReadyTime;
    final intolerances = preferences?.dietaryRestrictions
        .where((restriction) =>
            restriction.contains('gluten') ||
            restriction.contains('dairy') ||
            restriction.contains('egg'))
        .toList();

    // Get cuisine preference for category recipes too
    final cuisine = preferences?.cuisinePreferences.isNotEmpty == true
        ? preferences!.cuisinePreferences.first
        : null;

    try {
      //* Try API first with user preferences
      final searchQuery = _getCategorySearchQuery(category);
      final recipes = await SpoonacularService.searchRecipes(
        searchQuery,
        number: 5,
        diet: diet,
        cuisine: cuisine,
        maxReadyTime: maxReadyTime,
        intolerances: intolerances?.isNotEmpty == true ? intolerances : null,
      );

      //* ✨ NEW: Automatically cache these recipes with full details
      recipeCacheService.cacheRecipes(recipes);

      setState(() {
        _categoryRecipes = recipes;
        _isLoadingCategory = false;
      });

      print('✅ Loaded ${recipes.length} recipes for category: $category');
    } catch (e) {
      print('⚠️ API limit reached, loading from Firestore: $e');

      //* Fallback to Firestore
      try {
        final cachedRecipes = await firestoreService.getRecipesByCategory(
          category,
          limit: 5,
        );

        setState(() {
          _categoryRecipes = cachedRecipes;
          _isLoadingCategory = false;
        });

        print('✅ Loaded ${cachedRecipes.length} recipes from cache');
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
      case 'trending':
        return 'popular';
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
    List<Recipe> recipes,
    FirestoreService service,
  ) async {
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

  /// Show notifications modal
  void _showNotificationsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(AppSpacing.xl),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xl),

              // Title
              Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: AppColors.primaryAccent,
                    size: 28,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Text(
                    'Notifications',
                    style: AppTextStyles.recipeTitle,
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xl),

              // Notifications list
              Expanded(
                child: _buildNotificationsList(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build notifications list
  Widget _buildNotificationsList() {
    // For now, show a placeholder with sample notifications
    // In a real app, you would fetch notifications from Firestore
    final notifications = [
      {
        'icon': Icons.restaurant_menu,
        'title': 'New recipes available!',
        'message': 'Check out the trending recipes for today',
        'time': '2 hours ago',
        'read': false,
      },
      {
        'icon': Icons.favorite,
        'title': 'Recipe saved',
        'message': 'Your favorite recipe has been updated',
        'time': '1 day ago',
        'read': true,
      },
      {
        'icon': Icons.tips_and_updates,
        'title': 'Cooking tip',
        'message': 'Try adding a pinch of salt to enhance flavors',
        'time': '2 days ago',
        'read': true,
      },
    ];

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'No notifications yet',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'We\'ll notify you about new recipes and updates',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final isRead = notification['read'] as bool;

        return Container(
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isRead ? AppColors.background : AppColors.primaryAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: isRead
                ? null
                : Border.all(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  notification['icon'] as IconData,
                  color: AppColors.primaryAccent,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'] as String,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      notification['message'] as String,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      notification['time'] as String,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        );
      },
    );
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
                          //* Profile Avatar - Navigate to profile
                          Container(
                            decoration: AppDecorations.iconButtonDecoration,
                            child: IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(),
                                  ),
                                );
                              },
                              icon: AnimatedBuilder(
                                animation: _userProfileState,
                                builder: (context, child) {
                                  // Show initials or person icon
                                  final initials = _userProfileState.initials;
                                  if (initials.isNotEmpty && initials != 'U') {
                                    return Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          initials,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Icon(
                                    Icons.person,
                                    color: AppColors.textPrimary,
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          //* Greeting with dynamic name
                          AnimatedBuilder(
                            animation: _userProfileState,
                            builder: (context, child) {
                              return RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Hi ${_userProfileState.firstName} ",
                                      style: AppTextStyles.bodyLarge,
                                    ),
                                    TextSpan(text: "👋🏼"),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      //* Notifications
                      Container(
                        decoration: AppDecorations.iconButtonDecoration,
                        child: IconButton(
                          onPressed: () => _showNotificationsModal(context),
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

                  //* Search Bar - Tappable to navigate to search screen
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeSearchScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              "Search recipes...",
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(AppSpacing.sm),
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
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: AppSpacing.xl),

                  //* Category Icons with proper styling
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryIcon(
                          icon: Icons.trending_up,
                          label: "Trending",
                          isActive: _selectedCategory == "Trending",
                        ),
                        SizedBox(width: AppSpacing.md),
                        _buildCategoryIcon(
                          icon: Icons.restaurant,
                          label: "Western",
                          isActive: _selectedCategory == "Western",
                        ),
                        // My Groceries category positioned before other categories
                        if (_groceryState.hasGroceries) ...[
                          SizedBox(width: AppSpacing.md),
                          _buildCategoryIcon(
                            icon: Icons.shopping_basket,
                            label: "My Groceries",
                            isActive: _selectedCategory == "My Groceries",
                            hasNotificationDot: true,
                          ),
                        ],
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipesListScreen(
                                title: 'Trending Recipes',
                                type: RecipeListType.trending,
                              ),
                            ),
                          );
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

                  //* Vertical Recipe Cards for Trending
                  _isLoadingTrending
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xxl),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        )
                      : _trendingRecipes.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.xxl),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      size: 64,
                                      color: AppColors.textTertiary,
                                    ),
                                    SizedBox(height: AppSpacing.lg),
                                    Text(
                                      'No trending recipes found',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: _trendingRecipes.map((recipe) {
                                return AnimatedBuilder(
                                  animation: _favoritesState,
                                  builder: (context, child) {
                                    return RecipeCardVertical(
                                      imageUrl: recipe.image ??
                                          'assets/images/placeholder.png',
                                      title: recipe.title,
                                      time: '${recipe.readyInMinutes ?? 0} min',
                                      servings:
                                          '${recipe.servings ?? 0} servings',
                                      difficulty: 'Medium',
                                      isFavorite: _favoritesState.isFavorite(
                                        recipe.id,
                                      ),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipesListScreen(
                                title: '$_selectedCategory Recipes',
                                type: RecipeListType.category,
                                category: _selectedCategory,
                              ),
                            ),
                          );
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
                                      time: '${recipe.readyInMinutes ?? 0} min',
                                      servings:
                                          '${recipe.servings ?? 0} servings',
                                      difficulty: 'Medium',
                                      isFavorite: _favoritesState.isFavorite(
                                        recipe.id,
                                      ),
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
  Widget _buildCategoryIcon({
    required IconData icon,
    required String label,
    required bool isActive,
    bool hasNotificationDot = false,
  }) {
    return GestureDetector(
      onTap: () {
        //* Load recipes for selected category
        _loadCategoryRecipes(label);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryAccent : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: isActive ? AppColors.primaryAccent : Colors.transparent,
                width: 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primaryAccent.withValues(alpha: 0.3),
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
                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  size: 24,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color:
                        isActive ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Notification dot for special categories
          if (hasNotificationDot && !isActive)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
