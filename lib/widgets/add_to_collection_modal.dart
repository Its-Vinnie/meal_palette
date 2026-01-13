import 'package:flutter/material.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/state/collections_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/collection_form_modal.dart';

/// Modal for selecting which collections to add a recipe to
class AddToCollectionModal extends StatefulWidget {
  final Recipe recipe;

  const AddToCollectionModal({
    super.key,
    required this.recipe,
  });

  @override
  State<AddToCollectionModal> createState() => _AddToCollectionModalState();
}

class _AddToCollectionModalState extends State<AddToCollectionModal> {
  final CollectionsState _collectionsState = collectionsState;
  final Map<String, bool> _selectedCollections = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCollectionsAndCheck();
  }

  Future<void> _loadCollectionsAndCheck() async {
    setState(() => _isLoading = true);

    // Load all collections
    await _collectionsState.loadCollections();

    // Check which collections contain this recipe
    // For now, default to false - we'll check on save
    // A more complete implementation would add a method to CollectionsState for this
    for (final collection in _collectionsState.collections) {
      _selectedCollections[collection.id] = false;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
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
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          const Text(
            'Add to Collections',
            style: AppTextStyles.recipeTitle,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Recipe name
          Text(
            widget.recipe.title,
            style: AppTextStyles.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Create new collection button
          OutlinedButton.icon(
            onPressed: _showCreateCollectionModal,
            icon: const Icon(Icons.add),
            label: const Text('Create New Collection'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Collections list
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                ),
              ),
            )
          else if (_collectionsState.collections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'No collections yet. Create one to get started!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _collectionsState.collections.length,
                itemBuilder: (context, index) {
                  final collection = _collectionsState.collections[index];
                  final isSelected = _selectedCollections[collection.id] ?? false;

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        _selectedCollections[collection.id] = value ?? false;
                      });
                    },
                    title: Row(
                      children: [
                        Icon(
                          collection.iconData,
                          color: collection.colorValue,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            collection.name,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${collection.recipeCount} recipes',
                      style: AppTextStyles.labelMedium,
                    ),
                    activeColor: collection.colorValue,
                  );
                },
              ),
            ),

          const SizedBox(height: AppSpacing.xl),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textPrimary,
                        ),
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
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
      // Reload collections
      await _loadCollectionsAndCheck();
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    int added = 0;

    // Process each collection
    for (final entry in _selectedCollections.entries) {
      final collectionId = entry.key;
      final shouldBeInCollection = entry.value;

      if (shouldBeInCollection) {
        // Add to collection
        final success = await _collectionsState.addRecipeToCollection(collectionId, widget.recipe);
        if (success) added++;
      }
    }

    if (mounted) {
      Navigator.pop(context);

      String message = added > 0
          ? 'Added to $added ${added == 1 ? 'collection' : 'collections'}'
          : 'No collections selected';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: added > 0 ? AppColors.success : AppColors.info,
        ),
      );
    }
  }
}
