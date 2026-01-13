import 'package:flutter/material.dart';
import 'package:meal_palette/model/custom_recipe_model.dart';
import 'package:meal_palette/screen/create_edit_recipe_screen.dart';
import 'package:meal_palette/screen/custom_recipe_details_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/state/custom_recipes_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Screen displaying all user's custom recipes
class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  final CustomRecipesState _recipesState = customRecipesState;
  final AuthService _authService = authService;

  bool _isGridView = true;
  String _searchQuery = '';
  String? _selectedCategory;
  SortOption _sortOption = SortOption.recent;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final user = _authService.currentUser;
    if (user != null) {
      await _recipesState.loadRecipes(user.uid);
    }
  }

  /// Get filtered and sorted recipes
  List<CustomRecipe> get _filteredRecipes {
    // Create mutable copy to avoid "Cannot modify unmodifiable list" error
    List<CustomRecipe> recipes = List.from(_recipesState.recipes);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      recipes = _recipesState.searchRecipes(_searchQuery);
      recipes = List.from(recipes); // Ensure mutable copy after search
    }

    // Filter by category
    if (_selectedCategory != null) {
      recipes = recipes.where((r) => r.category == _selectedCategory).toList();
    }

    // Sort recipes
    switch (_sortOption) {
      case SortOption.recent:
        recipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.titleAZ:
        recipes.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.titleZA:
        recipes.sort((a, b) => b.title.compareTo(a.title));
        break;
    }

    return recipes;
  }

  /// Delete recipe with confirmation
  Future<void> _deleteRecipe(CustomRecipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Recipe?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${recipe.title}"? This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.favorite),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = _authService.currentUser;
      if (user != null) {
        final success = await _recipesState.deleteRecipe(user.uid, recipe.id);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${recipe.title}"'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'My Recipes',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          // Grid/List toggle
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
          // Sort menu
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort, color: AppColors.textPrimary),
            color: AppColors.surface,
            onSelected: (option) {
              setState(() => _sortOption = option);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.recent,
                child: Text('Most Recent'),
              ),
              const PopupMenuItem(
                value: SortOption.titleAZ,
                child: Text('Title (A-Z)'),
              ),
              const PopupMenuItem(
                value: SortOption.titleZA,
                child: Text('Title (Z-A)'),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _recipesState,
        builder: (context, _) {
          if (_recipesState.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            );
          }

          if (_recipesState.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.favorite,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Error loading recipes',
                    style: AppTextStyles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _recipesState.error!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _loadRecipes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredRecipes = _filteredRecipes;

          return Column(
            children: [
              // Search bar
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.surface,
                child: TextField(
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search recipes...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // Category filter chips
              if (_recipesState.recipesByCategory.isNotEmpty)
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  color: AppColors.surface,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    children: [
                      // All filter
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text('All (${_recipesState.recipeCount})'),
                          selected: _selectedCategory == null,
                          onSelected: (_) {
                            setState(() => _selectedCategory = null);
                          },
                          backgroundColor: AppColors.background,
                          selectedColor: AppColors.primaryAccent,
                          labelStyle: TextStyle(
                            color: _selectedCategory == null
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Category filters
                      ..._recipesState.recipesByCategory.entries.map((entry) {
                        final category = entry.key;
                        final count = entry.value.length;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: FilterChip(
                            label: Text(
                              '${RecipeCategories.getIcon(category)} '
                              '${RecipeCategories.getDisplayName(category)} ($count)',
                            ),
                            selected: _selectedCategory == category,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory =
                                    _selectedCategory == category ? null : category;
                              });
                            },
                            backgroundColor: AppColors.background,
                            selectedColor: AppColors.primaryAccent,
                            labelStyle: TextStyle(
                              color: _selectedCategory == category
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              const Divider(height: 1, color: AppColors.textTertiary),

              // Recipe list/grid
              Expanded(
                child: filteredRecipes.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadRecipes,
                        color: AppColors.primaryAccent,
                        child: _isGridView
                            ? _buildGridView(filteredRecipes)
                            : _buildListView(filteredRecipes),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to create recipe screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateEditRecipeScreen(),
            ),
          );
          // Reload recipes after returning
          _loadRecipes();
        },
        backgroundColor: AppColors.primaryAccent,
        icon: const Icon(Icons.add),
        label: const Text('Create Recipe'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.restaurant_menu,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _searchQuery.isNotEmpty
                ? 'No recipes found'
                : 'Create your first recipe!',
            style: AppTextStyles.recipeTitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap the button below to get started',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<CustomRecipe> recipes) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _RecipeGridCard(
          recipe: recipe,
          onTap: () => _openRecipeDetails(recipe),
          onDelete: () => _deleteRecipe(recipe),
          onEdit: () => _editRecipe(recipe),
        );
      },
    );
  }

  Widget _buildListView(List<CustomRecipe> recipes) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _RecipeListCard(
          recipe: recipe,
          onTap: () => _openRecipeDetails(recipe),
          onDelete: () => _deleteRecipe(recipe),
          onEdit: () => _editRecipe(recipe),
        );
      },
    );
  }

  void _openRecipeDetails(CustomRecipe recipe) async {
    // Navigate to custom recipe details screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomRecipeDetailsScreen(recipe: recipe),
      ),
    );
    // Reload recipes after returning
    _loadRecipes();
  }

  void _editRecipe(CustomRecipe recipe) async {
    // Navigate to edit recipe screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditRecipeScreen(recipe: recipe),
      ),
    );
    // Reload recipes after returning
    _loadRecipes();
  }
}

// Grid card widget
class _RecipeGridCard extends StatelessWidget {
  final CustomRecipe recipe;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RecipeGridCard({
    required this.recipe,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
                image: recipe.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(recipe.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: recipe.imageUrl == null
                  ? Center(
                      child: Text(
                        recipe.category != null
                            ? RecipeCategories.getIcon(recipe.category!)
                            : '🍴',
                        style: const TextStyle(fontSize: 40),
                      ),
                    )
                  : null,
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (recipe.category != null)
                      Text(
                        RecipeCategories.getDisplayName(recipe.category!),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        if (recipe.totalTime != null) ...[
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.totalTime} min',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Actions menu
                        PopupMenuButton(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          color: AppColors.surface,
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: AppColors.favorite),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: AppColors.favorite)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                        ),
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

// List card widget
class _RecipeListCard extends StatelessWidget {
  final CustomRecipe recipe;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RecipeListCard({
    required this.recipe,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.md),
                ),
                image: recipe.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(recipe.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: recipe.imageUrl == null
                  ? Center(
                      child: Text(
                        recipe.category != null
                            ? RecipeCategories.getIcon(recipe.category!)
                            : '🍴',
                        style: const TextStyle(fontSize: 40),
                      ),
                    )
                  : null,
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (recipe.category != null)
                      Text(
                        RecipeCategories.getDisplayName(recipe.category!),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (recipe.servings != null) ...[
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.servings}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        if (recipe.totalTime != null) ...[
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.totalTime} min',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Actions menu
            PopupMenuButton(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textSecondary,
              ),
              color: AppColors.surface,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: AppColors.favorite),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.favorite)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum SortOption {
  recent,
  titleAZ,
  titleZA,
}
