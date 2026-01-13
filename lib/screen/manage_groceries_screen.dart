import 'package:flutter/material.dart';
import 'package:meal_palette/model/grocery_item_model.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/state/grocery_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:uuid/uuid.dart';

class ManageGroceriesScreen extends StatefulWidget {
  const ManageGroceriesScreen({super.key});

  @override
  State<ManageGroceriesScreen> createState() => _ManageGroceriesScreenState();
}

class _ManageGroceriesScreenState extends State<ManageGroceriesScreen> {
  final GroceryState _groceryState = groceryState;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final _uuid = const Uuid();

  List<String> _autocompleteSuggestions = [];
  bool _isSearching = false;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadGroceries();
  }

  Future<void> _loadGroceries() async {
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      await _groceryState.loadGroceries(userId);
    }
  }

  /// Search for ingredient suggestions using Spoonacular autocomplete
  Future<void> _searchIngredients(String query) async {
    setState(() {}); // Rebuild to update Add button state

    if (query.length < 2) {
      setState(() {
        _autocompleteSuggestions = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final suggestions = await SpoonacularService.autocompleteIngredientSearch(
        query,
        number: 10,
      );

      setState(() {
        _autocompleteSuggestions = suggestions;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _autocompleteSuggestions = [];
        _isSearching = false;
      });
      print('Error searching ingredients: $e');
    }
  }

  /// Add ingredient to grocery list
  Future<void> _addIngredient(String name) async {
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    // Check if already exists
    if (_groceryState.groceries.any((g) => g.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name is already in your groceries'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final item = GroceryItem(
      id: _uuid.v4(),
      name: name,
      category: _selectedCategory,
      addedAt: DateTime.now(),
    );

    final success = await _groceryState.addGrocery(userId, item);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $name to groceries'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );

      // Clear search
      _searchController.clear();
      setState(() {
        _autocompleteSuggestions = [];
        _selectedCategory = null;
      });
      _searchFocusNode.unfocus();
    }
  }

  /// Remove ingredient from grocery list
  Future<void> _removeIngredient(GroceryItem item) async {
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    final success = await _groceryState.removeGrocery(userId, item.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${item.name}'),
          backgroundColor: AppColors.textSecondary,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Clear all groceries with confirmation
  Future<void> _clearAllGroceries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text('Clear All Groceries?'),
        content: const Text(
          'This will remove all items from your grocery list. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.favorite,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = authService.currentUser?.uid;
      if (userId != null) {
        await _groceryState.clearAllGroceries(userId);
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
          'My Groceries',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_groceryState.hasGroceries)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.favorite),
              onPressed: _clearAllGroceries,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _groceryState,
        builder: (context, child) {
          if (_groceryState.isLoadingGroceries) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            );
          }

          return Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: AppColors.surface,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search or type ingredient...',
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.textTertiary,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _autocompleteSuggestions = [];
                                        });
                                      },
                                    )
                                  : _isSearching
                                      ? const Padding(
                                          padding: EdgeInsets.all(AppSpacing.md),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primaryAccent,
                                            ),
                                          ),
                                        )
                                      : null,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: _searchIngredients,
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                _addIngredient(value.trim());
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ElevatedButton(
                          onPressed: _searchController.text.trim().isEmpty
                              ? null
                              : () {
                                  _addIngredient(_searchController.text.trim());
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            minimumSize: const Size(60, 50),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Autocomplete Suggestions
                    if (_autocompleteSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _autocompleteSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _autocompleteSuggestions[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.primaryAccent,
                              ),
                              title: Text(
                                suggestion,
                                style: AppTextStyles.bodyMedium,
                              ),
                              onTap: () => _addIngredient(suggestion),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // Grocery Count
              if (_groceryState.hasGroceries)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  color: AppColors.surface.withValues(alpha: 0.5),
                  child: Text(
                    '${_groceryState.groceryCount} ${_groceryState.groceryCount == 1 ? "item" : "items"} in your list',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

              // Groceries List
              Expanded(
                child: _groceryState.hasGroceries
                    ? _buildGroceriesList()
                    : _buildEmptyState(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroceriesList() {
    final categorized = _groceryState.groceriesByCategory;
    final categories = categorized.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final items = categorized[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Text(
                    GroceryCategories.getIcon(category),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    GroceryCategories.getDisplayName(category),
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '(${items.length})',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Items in Category
            ...items.map((item) => _buildGroceryItem(item)),
          ],
        );
      },
    );
  }

  Widget _buildGroceryItem(GroceryItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.favorite,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => _removeIngredient(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            // Ingredient Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                color: AppColors.primaryAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Ingredient Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.quantity != null && item.unit != null)
                    Text(
                      '${item.quantity} ${item.unit}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            // Pin Icon
            if (item.isPinned)
              const Icon(
                Icons.push_pin,
                color: AppColors.primaryAccent,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 80,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'No Groceries Yet',
              style: AppTextStyles.recipeTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Add ingredients you have at home to discover recipes you can make',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () {
                _searchFocusNode.requestFocus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
