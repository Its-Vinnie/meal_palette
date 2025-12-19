import 'package:flutter/material.dart';
import 'package:meal_palette/theme/theme_design.dart';

class RecipeCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String time;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoritePressed;

  const RecipeCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.time,
    this.isFavorite = false,
    required this.onTap,
    required this.onFavoritePressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(child: _buildImage(imageUrl)),

              // Gradient Overlay (darker at bottom)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Favorite Button and Share Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Favorite Button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite
                                  ? AppColors.favorite
                                  : AppColors.textPrimary,
                              size: 20,
                            ),
                            onPressed: onFavoritePressed,
                            padding: EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                          ),
                        ),

                        // Arrow/Share Button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_forward,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            onPressed: onTap,
                            padding: EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                          ),
                        ),
                      ],
                    ),

                    Spacer(),

                    // Recipe Title
                    Text(
                      title,
                      style: AppTextStyles.recipeTitle.copyWith(
                        fontSize: 18,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: AppSpacing.sm),

                    // Time Badge
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                time,
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    // Check if it's a network URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback when network image fails to load
          return Container(
            color: AppColors.surface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: 8),
                Text(
                  'Image unavailable',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppColors.surface,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryAccent,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      // Local asset image
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.surface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: 8),
                Text(
                  'Image not found',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
    }
  }
}

// Vertical Recipe Card (for lists)
class RecipeCardVertical extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String time;
  final String servings;
  final String difficulty;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoritePressed;

  const RecipeCardVertical({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.time,
    required this.servings,
    required this.difficulty,
    this.isFavorite = false,
    required this.onTap,
    required this.onFavoritePressed,
  });

  Color _getDifficultyColor() {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'hard':
        return AppColors.favorite;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              // Background Image
              Container(
                height: 250,
                width: double.infinity,
                child: _buildImage(imageUrl),
              ),

              // Gradient Overlay
              Container(
                height: 250,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: [0.3, 1.0],
                  ),
                ),
              ),

              // Content
              Container(
                height: 250,
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Favorite Button
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? AppColors.favorite
                                : AppColors.textPrimary,
                            size: 22,
                          ),
                          onPressed: onFavoritePressed,
                        ),
                      ),
                    ),

                    Spacer(),

                    // Recipe Title
                    Text(
                      title,
                      style: AppTextStyles.recipeTitle.copyWith(fontSize: 20),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: AppSpacing.md),

                    // Info Row
                    Row(
                      children: [
                        // Time
                        _buildInfoChip(icon: Icons.access_time, label: time),
                        SizedBox(width: AppSpacing.sm),

                        // Servings
                        _buildInfoChip(
                          icon: Icons.people_outline,
                          label: servings,
                        ),
                        SizedBox(width: AppSpacing.sm),

                        // Difficulty
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor().withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: _getDifficultyColor(),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            difficulty,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: _getDifficultyColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    // Check if it's a network URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.surface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: 8),
                Text(
                  'Image unavailable',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                ),
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppColors.surface,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryAccent,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      // Local asset image
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.surface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: 8),
                Text(
                  'Image not found',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// // import 'package:flutter/material.dart';
// // import 'package:meal_palette/theme/theme_design.dart';

// class RecipeCard extends StatelessWidget {
//   final String imageUrl;
//   final String title;
//   final String time;
//   final bool isFavorite;
//   final VoidCallback onTap;
//   final VoidCallback onFavoritePressed;

//   const RecipeCard({
//     super.key,
//     required this.imageUrl,
//     required this.title,
//     required this.time,
//     this.isFavorite = false,
//     required this.onTap,
//     required this.onFavoritePressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 280,
//         height: 200,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(AppRadius.xl),
//           boxShadow: AppShadows.cardShadow,
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(AppRadius.xl),
//           child: Stack(
//             children: [
//               // Background Image
//               Positioned.fill(child: Image.asset(imageUrl, fit: BoxFit.cover)),

//               // Gradient Overlay (darker at bottom)
//               Positioned.fill(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [
//                         Colors.transparent,
//                         Colors.black.withValues(alpha: 0.7),
//                       ],
//                       stops: [0.4, 1.0],
//                     ),
//                   ),
//                 ),
//               ),

//               // Content
//               Padding(
//                 padding: EdgeInsets.all(AppSpacing.lg),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Top Row: Favorite Button and Share Button
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         // Favorite Button
//                         Container(
//                           decoration: BoxDecoration(
//                             color: AppColors.surface.withValues(alpha: 0.8),
//                             shape: BoxShape.circle,
//                           ),
//                           child: IconButton(
//                             icon: Icon(
//                               isFavorite
//                                   ? Icons.favorite
//                                   : Icons.favorite_border,
//                               color: isFavorite
//                                   ? AppColors.favorite
//                                   : AppColors.textPrimary,
//                               size: 20,
//                             ),
//                             onPressed: onFavoritePressed,
//                             padding: EdgeInsets.all(8),
//                             constraints: BoxConstraints(),
//                           ),
//                         ),

//                         // Arrow/Share Button
//                         Container(
//                           decoration: BoxDecoration(
//                             color: AppColors.surface.withValues(alpha: 0.8),
//                             shape: BoxShape.circle,
//                           ),
//                           child: IconButton(
//                             icon: Icon(
//                               Icons.arrow_forward,
//                               color: AppColors.textPrimary,
//                               size: 20,
//                             ),
//                             onPressed: onTap,
//                             padding: EdgeInsets.all(8),
//                             constraints: BoxConstraints(),
//                           ),
//                         ),
//                       ],
//                     ),

//                     Spacer(),

//                     // Recipe Title
//                     Text(
//                       title,
//                       style: AppTextStyles.recipeTitle.copyWith(
//                         fontSize: 18,
//                         height: 1.2,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),

//                     SizedBox(height: AppSpacing.sm),

//                     // Time Badge
//                     Row(
//                       children: [
//                         Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: AppSpacing.sm,
//                             vertical: 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: AppColors.surface.withValues(alpha: 0.6),
//                             borderRadius: BorderRadius.circular(AppRadius.sm),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                 Icons.access_time,
//                                 size: 14,
//                                 color: AppColors.textSecondary,
//                               ),
//                               SizedBox(width: 4),
//                               Text(
//                                 time,
//                                 style: AppTextStyles.labelMedium.copyWith(
//                                   color: AppColors.textSecondary,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // Vertical Recipe Card (for lists)
// class RecipeCardVertical extends StatelessWidget {
//   final String imageUrl;
//   final String title;
//   final String time;
//   final String servings;
//   final String difficulty;
//   final bool isFavorite;
//   final VoidCallback onTap;
//   final VoidCallback onFavoritePressed;

//   // ignore: use_super_parameters
//   const RecipeCardVertical({
//     super.key,
//     required this.imageUrl,
//     required this.title,
//     required this.time,
//     required this.servings,
//     required this.difficulty,
//     this.isFavorite = false,
//     required this.onTap,
//     required this.onFavoritePressed,
//   });

//   Color _getDifficultyColor() {
//     switch (difficulty.toLowerCase()) {
//       case 'easy':
//         return AppColors.success;
//       case 'medium':
//         return AppColors.warning;
//       case 'hard':
//         return AppColors.favorite;
//       default:
//         return AppColors.info;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         margin: EdgeInsets.only(bottom: AppSpacing.lg),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(AppRadius.xl),
//           boxShadow: AppShadows.cardShadow,
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(AppRadius.xl),
//           child: Stack(
//             children: [
//               // Background Image
//               Container(
//                 height: 250,
//                 width: double.infinity,
//                 child: Image.asset(imageUrl, fit: BoxFit.cover),
//               ),

//               // Gradient Overlay
//               Container(
//                 height: 250,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.transparent,
//                       Colors.black.withValues(alpha: 0.8),
//                     ],
//                     stops: [0.3, 1.0],
//                   ),
//                 ),
//               ),

//               // Content
//               Container(
//                 height: 250,
//                 padding: EdgeInsets.all(AppSpacing.lg),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Favorite Button
//                     Align(
//                       alignment: Alignment.topRight,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: AppColors.surface.withValues(alpha: 0.8),
//                           shape: BoxShape.circle,
//                         ),
//                         child: IconButton(
//                           icon: Icon(
//                             isFavorite ? Icons.favorite : Icons.favorite_border,
//                             color: isFavorite
//                                 ? AppColors.favorite
//                                 : AppColors.textPrimary,
//                             size: 22,
//                           ),
//                           onPressed: onFavoritePressed,
//                         ),
//                       ),
//                     ),

//                     Spacer(),

//                     // Recipe Title
//                     Text(
//                       title,
//                       style: AppTextStyles.recipeTitle.copyWith(fontSize: 20),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),

//                     SizedBox(height: AppSpacing.md),

//                     // Info Row
//                     Row(
//                       children: [
//                         // Time
//                         _buildInfoChip(icon: Icons.access_time, label: time),
//                         SizedBox(width: AppSpacing.sm),

//                         // Servings
//                         _buildInfoChip(
//                           icon: Icons.people_outline,
//                           label: servings,
//                         ),
//                         SizedBox(width: AppSpacing.sm),

//                         // Difficulty
//                         Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: AppSpacing.md,
//                             vertical: 6,
//                           ),
//                           decoration: BoxDecoration(
//                             color: _getDifficultyColor().withValues(alpha: 0.2),
//                             borderRadius: BorderRadius.circular(AppRadius.lg),
//                             border: Border.all(
//                               color: _getDifficultyColor(),
//                               width: 1,
//                             ),
//                           ),
//                           child: Text(
//                             difficulty,
//                             style: AppTextStyles.labelMedium.copyWith(
//                               color: _getDifficultyColor(),
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoChip({required IconData icon, required String label}) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
//       decoration: BoxDecoration(
//         color: AppColors.surface.withValues(alpha: 0.6),
//         borderRadius: BorderRadius.circular(AppRadius.lg),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 16, color: AppColors.textSecondary),
//           SizedBox(width: 4),
//           Text(
//             label,
//             style: AppTextStyles.labelMedium.copyWith(
//               color: AppColors.textSecondary,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
