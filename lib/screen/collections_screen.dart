import 'package:flutter/material.dart';
import 'package:meal_palette/model/recipe_collection_model.dart';
import 'package:meal_palette/screen/collection_detail_screen.dart';
import 'package:meal_palette/state/collections_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/collection_card.dart';
import 'package:meal_palette/widgets/collection_form_modal.dart';

/// Screen displaying all user's recipe collections
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final CollectionsState _collectionsState = collectionsState;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    await _collectionsState.loadCollections();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Collections grid
            Expanded(
              child: AnimatedBuilder(
                animation: _collectionsState,
                builder: (context, child) {
                  if (_collectionsState.isLoading) {
                    return _buildLoadingState();
                  }

                  if (_collectionsState.collections.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildCollectionsGrid();
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateCollectionModal,
        backgroundColor: AppColors.primaryAccent,
        child: const Icon(Icons.add, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Collections',
            style: AppTextStyles.pageHeadline,
          ),
          AnimatedBuilder(
            animation: _collectionsState,
            builder: (context, child) {
              final count = _collectionsState.collectionCount;
              if (count == 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
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
              Icons.collections_bookmark_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No collections yet',
              style: AppTextStyles.recipeTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create your first collection to organize your recipes',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: _showCreateCollectionModal,
              icon: const Icon(Icons.add),
              label: const Text('Create Collection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsGrid() {
    return RefreshIndicator(
      onRefresh: _loadCollections,
      color: AppColors.primaryAccent,
      backgroundColor: AppColors.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: 0.85,
        ),
        itemCount: _collectionsState.collections.length,
        itemBuilder: (context, index) {
          final collection = _collectionsState.collections[index];
          final recipeImages = _collectionsState.getCollectionCoverImages(collection.id);

          return CollectionCard(
            collection: collection,
            recipeImages: recipeImages.isNotEmpty ? recipeImages : null,
            onTap: () => _navigateToCollectionDetail(collection),
            onLongPress: () => _showCollectionOptions(collection),
          );
        },
      ),
    );
  }

  void _navigateToCollectionDetail(RecipeCollection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(collection: collection),
      ),
    );
  }

  Future<void> _showCreateCollectionModal() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CollectionFormModal(),
    );

    if (result == true && mounted) {
      // Reload collections after creation
      await _loadCollections();
    }
  }

  Future<void> _showCollectionOptions(RecipeCollection collection) async {
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

            // Collection name
            Text(
              collection.name,
              style: AppTextStyles.recipeTitle,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Options
            ListTile(
              leading: Icon(
                collection.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppColors.primaryAccent,
              ),
              title: Text(
                collection.isPinned ? 'Unpin' : 'Pin to top',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _togglePin(collection);
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.edit,
                color: AppColors.info,
              ),
              title: Text(
                'Edit',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditCollectionModal(collection);
              },
            ),

            if (!collection.isDefault)
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
                  _confirmDelete(collection);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin(RecipeCollection collection) async {
    final success = await _collectionsState.togglePin(collection.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? collection.isPinned
                    ? 'Unpinned collection'
                    : 'Pinned to top'
                : 'Failed to update collection',
          ),
          backgroundColor: success ? AppColors.success : AppColors.favorite,
        ),
      );
    }
  }

  Future<void> _showEditCollectionModal(RecipeCollection collection) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CollectionFormModal(collection: collection),
    );

    if (result == true && mounted) {
      await _loadCollections();
    }
  }

  Future<void> _confirmDelete(RecipeCollection collection) async {
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
          'This will remove "${collection.name}" and all its recipes. This action cannot be undone.',
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
      final success = await _collectionsState.deleteCollection(collection.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Collection deleted'
                  : 'Failed to delete collection',
            ),
            backgroundColor: success ? AppColors.success : AppColors.favorite,
          ),
        );
      }
    }
  }
}
