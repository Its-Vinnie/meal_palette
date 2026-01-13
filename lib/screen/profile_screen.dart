import 'package:flutter/material.dart';
import 'package:meal_palette/screen/edit_preferences_screen.dart';
import 'package:meal_palette/screen/edit_profile_screen.dart';
import 'package:meal_palette/screen/manage_groceries_screen.dart';
import 'package:meal_palette/screen/my_recipes_screen.dart';
import 'package:meal_palette/screen/url_recipe_import_screen.dart';
import 'package:meal_palette/screen/voice_settings_screen.dart';
import 'package:meal_palette/screen/welcome_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/state/user_profile_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/animated_error_message.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  //* Services and state
  final AuthService _authService = authService;
  final UserProfileState _userProfileState = UserProfileState();

  /// Handle logout with confirmation
  Future<void> _handleLogout() async {
    final shouldLogout = await _showLogoutDialog(context);

    if (shouldLogout == true) {
      try {
        //* Show loading
        if (mounted) {
          ErrorMessageOverlay.showSuccess(
            context,
            'Logging out...',
          );
        }

        //* Perform logout
        await _authService.signOut();

        //* Navigate to welcome screen and clear navigation stack
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => WelcomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorMessageOverlay.showError(
            context,
            'Failed to logout. Please try again.',
          );
        }
        print('Logout error: $e');
      }
    }
  }

  /// Navigate to voice settings screen
  Future<void> _openVoiceSettings() async {
    final userProfile = _userProfileState.userProfile;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceSettingsScreen(
          initialSettings: userProfile?.voiceSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _userProfileState,
      builder: (context, child) {
        //* Show loading while profile loads
        if (_userProfileState.isLoading) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryAccent,
              ),
            ),
          );
        }

        return _buildProfileContent();
      },
    );
  }

  Widget _buildProfileContent() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text('Profile', style: AppTextStyles.pageHeadline),
                SizedBox(height: AppSpacing.xxl),

                // Profile Card
                Center(
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar with Initials
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryAccent,
                          ),
                          child: Center(
                            child: Text(
                              _userProfileState.initials,
                              style: AppTextStyles.pageHeadline.copyWith(
                                fontSize: 40,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.lg),

                        // Name
                        Text(
                          _userProfileState.displayName,
                          style: AppTextStyles.recipeTitle,
                        ),
                        SizedBox(height: AppSpacing.sm),

                        // Email
                        Text(
                          _userProfileState.email,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),

                        // Member Since
                        Text(
                          'Member since ${_userProfileState.memberSince}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: AppSpacing.xxl),

                // Settings Options
                _buildProfileOption(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  onTap: () async {
                    // Navigate to edit profile
                    // No need to reload - UserProfileState auto-updates
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.md),

                _buildProfileOption(
                  icon: Icons.bookmark_border,
                  title: 'Saved Recipes',
                  onTap: () {},
                ),
                SizedBox(height: AppSpacing.md),

                _buildProfileOption(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'My Recipes',
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MyRecipesScreen()));
                  },
                ),
                SizedBox(height: AppSpacing.md),

                _buildProfileOption(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Grocery List',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageGroceriesScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.md),

                _buildProfileOption(
                  icon: Icons.link_outlined,
                  title: 'Import Recipe from URL',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UrlRecipeImportScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.md),

                _buildProfileOption(
                  icon: Icons.record_voice_over_outlined,
                  title: 'Voice Settings',
                  onTap: _openVoiceSettings,
                ),
                SizedBox(height: AppSpacing.md),

                _buildProfileOption(
                  icon: Icons.tune_outlined,
                  title: 'Food Preferences',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditPreferencesScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.md),

                _buildProfileOption(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {},
                ),
                SizedBox(height: AppSpacing.md),

                _buildProfileOption(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {},
                ),
                SizedBox(height: AppSpacing.xxl),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _handleLogout,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.favorite),
                      foregroundColor: AppColors.favorite,
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: AppSpacing.sm),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 24),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('Logout', style: AppTextStyles.recipeTitle),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.favorite,
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}
