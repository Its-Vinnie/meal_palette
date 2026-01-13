import 'package:flutter/material.dart';
import 'package:meal_palette/screen/generation_history_screen.dart';
import 'package:meal_palette/screen/home_screen.dart';
import 'package:meal_palette/screen/recipe_search_screen.dart';
import 'package:meal_palette/screen/collections_screen.dart';
import 'package:meal_palette/screen/profile_screen.dart';
import 'package:meal_palette/screen/ingredient_input_screen.dart';
import 'package:meal_palette/screen/create_edit_recipe_screen.dart';
import 'package:meal_palette/screen/voice_recipe_creation_screen.dart';
import 'package:meal_palette/screen/url_recipe_import_screen.dart';
import 'package:meal_palette/screen/manage_groceries_screen.dart';
import 'package:meal_palette/widgets/custom_bottom_navbar.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:permission_handler/permission_handler.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  // List of screens
  final List<Widget> _screens = [
    const HomeScreen(),
    const RecipeSearchScreen(),
    const CollectionsScreen(),
    const ProfileScreen(),
  ];


 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 4) {
            // Center FAB pressed - Show ingredient input options
            _showIngredientInputModal();
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

  /// Show modal for quick actions
  void _showIngredientInputModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              top: AppSpacing.xl,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
            ),
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
                Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: AppColors.primaryAccent,
                      size: 28,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Text(
                      'Quick Actions',
                      style: AppTextStyles.recipeTitle,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Choose what you want to do',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppSpacing.xl),

                // Generate from ingredients
                _buildModalOption(
                  icon: Icons.auto_awesome,
                  title: 'Generate from Ingredients',
                  subtitle: 'AI-powered recipe suggestions',
                  color: AppColors.primaryAccent,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IngredientInputScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.sm),

                // View generation history
                _buildModalOption(
                  icon: Icons.history,
                  title: 'View History',
                  subtitle: 'See your past generations',
                  color: Color(0xFF9C27B0),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenerationHistoryScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.sm),

                // Create custom recipe
                _buildModalOption(
                  icon: Icons.edit_note,
                  title: 'Create a Recipe',
                  subtitle: 'Write your own recipe',
                  color: Color(0xFF00BCD4),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateEditRecipeScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.sm),

                // Voice recipe creation
                _buildModalOption(
                  icon: Icons.mic,
                  title: 'Voice Recipe Creation',
                  subtitle: 'Create recipe with AI voice assistant',
                  color: Color(0xFFE91E63),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VoiceRecipeCreationScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.sm),

                // Import from URL
                _buildModalOption(
                  icon: Icons.link,
                  title: 'Import from URL',
                  subtitle: 'Extract recipe from website',
                  color: Color(0xFFFF9800),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UrlRecipeImportScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.sm),

                // Manage groceries
                _buildModalOption(
                  icon: Icons.shopping_basket_outlined,
                  title: 'Manage Groceries',
                  subtitle: 'Add or view your grocery list',
                  color: Color(0xFF4CAF50),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageGroceriesScreen(),
                      ),
                    );
                  },
                ),

                SizedBox(height: AppSpacing.lg),
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 28),
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
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
