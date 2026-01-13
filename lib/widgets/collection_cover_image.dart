import 'package:flutter/material.dart';
import 'package:meal_palette/model/recipe_collection_model.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Widget for rendering collection cover images based on cover type
class CollectionCoverImage extends StatelessWidget {
  final RecipeCollection collection;
  final List<String>? recipeImages; // First 4 recipe images for grid mode
  final double? height;
  final BorderRadius? borderRadius;

  const CollectionCoverImage({
    super.key,
    required this.collection,
    this.recipeImages,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(AppRadius.xl);

    return Container(
      height: height,
      constraints: height == null ? const BoxConstraints.expand() : null,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            collection.colorValue.withValues(alpha: 0.6),
            collection.colorValue.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Stack(
          children: [
            // Base cover image
            _buildCoverContent(),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: effectiveBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    collection.colorValue.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverContent() {
    switch (collection.coverImageType) {
      case 'grid':
        return _buildGridCover();
      case 'first':
        return _buildFirstImageCover();
      case 'custom':
        return _buildCustomCover();
      default:
        return _buildPlaceholder();
    }
  }

  /// Build 2x2 grid of recipe images
  Widget _buildGridCover() {
    if (recipeImages == null || recipeImages!.isEmpty) {
      return _buildPlaceholder();
    }

    final imagesToShow = recipeImages!.take(4).toList();

    // If only one image, show it full
    if (imagesToShow.length == 1) {
      return Image.network(
        imagesToShow[0],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // Show up to 4 images in a 2x2 grid
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(4, (index) {
        if (index < imagesToShow.length) {
          return Image.network(
            imagesToShow[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: collection.colorValue.withValues(alpha: 0.2),
              child: Icon(
                Icons.restaurant,
                color: Colors.white.withValues(alpha: 0.3),
                size: 40,
              ),
            ),
          );
        }
        // Placeholder for empty grid cells
        return Container(
          color: collection.colorValue.withValues(alpha: 0.2),
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: Colors.white.withValues(alpha: 0.3),
            size: 40,
          ),
        );
      }),
    );
  }

  /// Build cover with first recipe image
  Widget _buildFirstImageCover() {
    if (recipeImages == null || recipeImages!.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      recipeImages!.first,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  /// Build custom cover from URL
  Widget _buildCustomCover() {
    if (collection.customCoverUrl == null || collection.customCoverUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      collection.customCoverUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  /// Build placeholder when no images available
  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        collection.iconData,
        size: 64,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}
