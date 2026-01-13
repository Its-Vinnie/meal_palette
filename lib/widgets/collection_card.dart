import 'package:flutter/material.dart';
import 'package:meal_palette/model/recipe_collection_model.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/collection_cover_image.dart';

/// Card widget for displaying a recipe collection in a grid
class CollectionCard extends StatelessWidget {
  final RecipeCollection collection;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final List<String>? recipeImages; // First 4 recipe images for cover

  const CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    this.onLongPress,
    this.recipeImages,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image section
            Expanded(
              flex: 3,
              child: _buildCoverImage(),
            ),

            // Collection info section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Collection name
                    Row(
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
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (collection.isPinned)
                          Icon(
                            Icons.push_pin,
                            size: 16,
                            color: collection.colorValue,
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Recipe count
                    Text(
                      '${collection.recipeCount} ${collection.recipeCount == 1 ? 'recipe' : 'recipes'}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
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

  Widget _buildCoverImage() {
    return CollectionCoverImage(
      collection: collection,
      recipeImages: recipeImages,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppRadius.xl),
        topRight: Radius.circular(AppRadius.xl),
      ),
    );
  }
}
