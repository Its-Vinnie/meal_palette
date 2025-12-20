import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/screen/recipe_details_screen.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/theme/theme_design.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  //* Controllers and state
  final _searchController = TextEditingController();
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;

  //* Services
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Searches recipes from API and saves results to Firestore
  Future<void> _searchRecipes() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      //* Search recipes from API
      final recipes = await SpoonacularService.searchRecipes(
        query: _searchController.text,
        number: 20,
      );

      //* Save search results to Firestore in background
      _saveSearchResultsToFirestore(recipes);

      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });

      print('🔍 Found ${recipes.length} recipes for: ${_searchController.text}');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('❌ Search error: $e');
    }
  }

  /// Saves search results to Firestore database
  /// Runs in background without blocking UI
  Future<void> _saveSearchResultsToFirestore(List<Recipe> recipes) async {
    if (recipes.isEmpty) return;

    try {
      await _firestoreService.saveRecipesBatch(recipes);
      print('💾 Saved ${recipes.length} search results to Firestore');
    } catch (e) {
      print('⚠️ Failed to save search results: $e');
      // Silent failure - don't interrupt user experience
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //* Header
              Text('Search Recipes', style: AppTextStyles.pageHeadline),

              SizedBox(height: AppSpacing.xl),

              //* Search Bar
              TextField(
                controller: _searchController,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search for recipes...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textTertiary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppColors.textTertiary,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _recipes.clear();
                            });
                          },
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.send,
                            color: AppColors.primaryAccent,
                          ),
                          onPressed: _searchRecipes,
                        ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: AppColors.primaryAccent,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {}); // Rebuild to show/hide clear button
                },
                onSubmitted: (_) => _searchRecipes(),
                textInputAction: TextInputAction.search,
              ),

              SizedBox(height: AppSpacing.lg),

              //* Search suggestions or filters could go here
              if (_recipes.isEmpty && !_isLoading && _error == null)
                _buildSearchSuggestions(),

              SizedBox(height: AppSpacing.lg),

              //* Results count
              if (_recipes.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    'Found ${_recipes.length} recipes',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

              //* Loading / Error / Results
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the main content area
  Widget _buildContent() {
    //* Loading state
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primaryAccent,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Searching recipes...',
              style: AppTextStyles.bodyMedium,
            ),
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
              color: AppColors.favorite,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Oops! Something went wrong',
              style: AppTextStyles.bodyLarge,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _searchRecipes,
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    //* Empty state
    if (_recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Search for delicious recipes!',
              style: AppTextStyles.bodyLarge,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Try searching for pasta, chicken, or desserts',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    //* Results list
    return ListView.builder(
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        return _buildRecipeCard(recipe);
      },
    );
  }

  /// Builds search suggestions
  Widget _buildSearchSuggestions() {
    final suggestions = [
      {'icon': Icons.restaurant, 'label': 'Pasta'},
      {'icon': Icons.local_pizza, 'label': 'Pizza'},
      {'icon': Icons.cake, 'label': 'Desserts'},
      {'icon': Icons.breakfast_dining, 'label': 'Breakfast'},
      {'icon': Icons.lunch_dining, 'label': 'Lunch'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Searches',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: suggestions.map((suggestion) {
            return GestureDetector(
              onTap: () {
                _searchController.text = suggestion['label'] as String;
                _searchRecipes();
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.textTertiary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      suggestion['icon'] as IconData,
                      size: 20,
                      color: AppColors.primaryAccent,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      suggestion['label'] as String,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Builds a recipe card
  Widget _buildRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () {
        //* Navigate to detail screen
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
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            //* Image
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

            //* Content
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
                    //* Info row
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

            //* Arrow
            Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds placeholder image
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