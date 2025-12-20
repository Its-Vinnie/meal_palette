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
  final _searchController = TextEditingController();
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  FirestoreService firestoreService = FirestoreService();
  String? _error;

  Future<void> _searchRecipes() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recipes = await SpoonacularService.searchRecipes(
        query: _searchController.text,
        number: 20,
      );

      setState(() {
        _recipes = recipes;
        firestoreService.saveRecipe(recipes);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Search Recipes')),
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _searchRecipes,
                ),
              ),
              onSubmitted: (_) => _searchRecipes(),
            ),

            SizedBox(height: AppSpacing.xl),

            // Loading / Error / Results
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryAccent,
                ),
              )
            else if (_error != null)
              Center(
                child: Text(
                  'Error: $_error',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.favorite,
                  ),
                ),
              )
            else if (_recipes.isEmpty)
              Center(
                child: Text(
                  'Search for delicious recipes!',
                  style: AppTextStyles.bodyLarge,
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _recipes[index];
                    return _buildRecipeCard(recipe);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () {
        // Navigate to detail screen
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
        ),
        child: Row(
          children: [
            // Image
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
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      color: AppColors.surface,
                      child: Icon(
                        Icons.restaurant,
                        color: AppColors.textTertiary,
                        size: 48,
                      ),
                    ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipe.readyInMinutes != null) ...[
                      SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${recipe.readyInMinutes} min',
                            style: AppTextStyles.labelMedium,
                          ),
                          if (recipe.servings != null) ...[
                            SizedBox(width: AppSpacing.md),
                            Icon(
                              Icons.people_outline,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${recipe.servings} servings',
                              style: AppTextStyles.labelMedium,
                            ),
                          ],
                        ],
                      ),
                    ],
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
