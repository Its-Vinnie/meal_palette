import 'package:flutter/material.dart';
import 'package:meal_palette/screen/home_screen.dart';
import 'package:meal_palette/screen/recipe_search_screen.dart';
import 'package:meal_palette/screen/favourites_screen.dart';
import 'package:meal_palette/screen/profile_screen.dart';
import 'package:meal_palette/widgets/custom_bottom_navbar.dart';
import 'package:meal_palette/theme/theme_design.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  // List of screens
  final List<Widget> _screens = [
    HomeScreen(),
    RecipeSearchScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 4) {
            // Center FAB pressed - Show add recipe options
            _showAddRecipeModal();
          } else {
            // Regular navigation
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }

  void _showAddRecipeModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),

                // Title
                Text('Add New Recipe', style: AppTextStyles.recipeTitle),
                SizedBox(height: AppSpacing.xl),

                // Options
                _buildModalOption(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take Photo',
                  subtitle: 'Capture a recipe from a book',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Add camera functionality
                    print('Take photo tapped');
                  },
                ),
                SizedBox(height: AppSpacing.md),

                _buildModalOption(
                  icon: Icons.image_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Select recipe image',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Add gallery functionality
                    print('Gallery tapped');
                  },
                ),
                SizedBox(height: AppSpacing.md),

                _buildModalOption(
                  icon: Icons.edit_outlined,
                  title: 'Manual Entry',
                  subtitle: 'Write your own recipe',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to add recipe form
                    print('Manual entry tapped');
                  },
                ),
                SizedBox(height: AppSpacing.md),

                _buildModalOption(
                  icon: Icons.link_outlined,
                  title: 'Import from URL',
                  subtitle: 'Paste a recipe link',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Add URL import functionality
                    print('Import URL tapped');
                  },
                ),

                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.primaryAccent, size: 24),
            ),
            SizedBox(width: AppSpacing.lg),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
