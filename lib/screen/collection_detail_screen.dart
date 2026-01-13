import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meal_palette/model/recipe_collection_model.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/screen/recipe_details_screen.dart';
import 'package:meal_palette/state/collections_state.dart';
import 'package:meal_palette/state/favorites_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/collection_form_modal.dart';
import 'package:share_plus/share_plus.dart';

/// Screen displaying recipes within a single collection
class CollectionDetailScreen extends StatefulWidget {
  final RecipeCollection collection;

  const CollectionDetailScreen({
    super.key,
    required this.collection,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final CollectionsState _collectionsState = collectionsState;
  final FavoritesState _favoritesState = FavoritesState();
  List<Recipe> _recipes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    final recipes = await _collectionsState.getCollectionRecipes(widget.collection.id);
    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with collection info
          _buildSliverAppBar(),

          // Recipes grid
          _buildRecipesGrid(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: AppColors.textPrimary),
          onPressed: _shareCollection,
        ),
        if (!widget.collection.isDefault)
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textPrimary),
            onPressed: _showEditModal,
          ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
          onPressed: _showMoreOptions,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.collection.name,
          style: AppTextStyles.recipeTitle.copyWith(fontSize: 20),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.collection.colorValue.withValues(alpha: 0.6),
                widget.collection.colorValue.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              widget.collection.iconData,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipesGrid() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
          ),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'No recipes yet',
                  style: AppTextStyles.recipeTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Add recipes to this collection from recipe details',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: 0.75,
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
    );
  }

  void _navigateToRecipeDetail(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
      ),
    );
  }

  Future<void> _removeRecipe(Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text(
          'Remove from Collection?',
          style: AppTextStyles.recipeTitle,
        ),
        content: Text(
          'Remove "${recipe.title}" from this collection?',
          style: AppTextStyles.bodyMedium,
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _collectionsState.removeRecipeFromCollection(
        widget.collection.id,
        recipe.id,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _recipes.removeWhere((r) => r.id == recipe.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe removed from collection'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove recipe'),
              backgroundColor: AppColors.favorite,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditModal() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CollectionFormModal(collection: widget.collection),
    );

    if (result == true && mounted) {
      // Reload to get updated collection info
      Navigator.pop(context);
    }
  }

  Future<void> _showMoreOptions() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            ListTile(
              leading: Icon(
                widget.collection.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppColors.primaryAccent,
              ),
              title: Text(
                widget.collection.isPinned ? 'Unpin' : 'Pin to top',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _togglePin();
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.share,
                color: AppColors.primaryAccent,
              ),
              title: Text(
                'Share',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _shareCollection();
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.copy,
                color: AppColors.info,
              ),
              title: Text(
                'Duplicate',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _duplicateCollection();
              },
            ),

            if (!widget.collection.isDefault)
              ListTile(
                leading: const Icon(
                  Icons.delete,
                  color: AppColors.favorite,
                ),
                title: Text(
                  'Delete',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCollection();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin() async {
    final success = await _collectionsState.togglePin(widget.collection.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? widget.collection.isPinned
                    ? 'Unpinned collection'
                    : 'Pinned to top'
                : 'Failed to update',
          ),
          backgroundColor: success ? AppColors.success : AppColors.favorite,
        ),
      );
    }
  }

  Future<void> _duplicateCollection() async {
    final nameController = TextEditingController(
      text: '${widget.collection.name} (Copy)',
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text(
          'Duplicate Collection',
          style: AppTextStyles.recipeTitle,
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            hintText: 'Enter name for duplicate',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      final newCollection = await _collectionsState.duplicateCollection(
        widget.collection.id,
        newName,
      );

      if (mounted) {
        if (newCollection != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collection duplicated'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to duplicate collection'),
              backgroundColor: AppColors.favorite,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCollection() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text(
          'Delete Collection?',
          style: AppTextStyles.recipeTitle,
        ),
        content: Text(
          'This will remove "${widget.collection.name}" and all its recipes. This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _collectionsState.deleteCollection(widget.collection.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context); // Go back to collections screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collection deleted'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete collection'),
              backgroundColor: AppColors.favorite,
            ),
          );
        }
      }
    }
  }

  Future<void> _shareCollection() async {
    // Get the share position for iPad BEFORE async operations (required on iOS)
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                  ),
                ),
                SizedBox(width: 12),
                Text('Creating share link...'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.surface,
          ),
        );
      }

      // Generate share link
      final shareToken = await _collectionsState.shareCollection(widget.collection.id);

      if (shareToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create share link'),
              backgroundColor: AppColors.favorite,
            ),
          );
        }
        return;
      }

      // Create shareable message
      final shareUrl = 'https://mealpalette.app/shared/$shareToken';
      final shareMessage = '''
Check out my "${widget.collection.name}" recipe collection on Meal Palette!

${widget.collection.description ?? '${widget.collection.recipeCount} delicious recipes'}

View collection: $shareUrl
''';

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: shareUrl));

      // Show native share sheet
      await Share.share(
        shareMessage,
        subject: '${widget.collection.name} - Recipe Collection',
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print('❌ Error sharing collection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share collection'),
            backgroundColor: AppColors.favorite,
          ),
        );
      }
    }
  }

  /// Build individual recipe grid item (matches RecipesListScreen pattern)
  Widget _buildRecipeGridItem(Recipe recipe) {
    return GestureDetector(
      onTap: () => _navigateToRecipeDetail(recipe),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                    borderRadius: const BorderRadius.only(
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
                      ? const Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : null,
                ),

                //* Remove button (instead of favorite for collections)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: () => _removeRecipe(recipe),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.favorite,
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
                padding: const EdgeInsets.all(AppSpacing.md),
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

                    const Spacer(),

                    //* Time and servings
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.readyInMinutes ?? 30} min',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        if (recipe.servings != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
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
