import 'package:flutter/material.dart';
import 'package:meal_palette/screen/edit_profile_screen.dart';
import 'package:meal_palette/screen/welcome_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/service/user_profile_service.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/animated_error_message.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  //* Services
  final UserProfileService _userProfileService = UserProfileService();
  final AuthService _authService = authService;

  //* User profile data
  String _userName = 'User';
  String _userEmail = '';
  String _memberSince = 'December 2025';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  /// Load user profile data
  Future<void> _loadUserProfile() async {
    try {
      final profile = await _userProfileService.getCurrentUserProfile();
      
      if (profile != null && mounted) {
        setState(() {
          _userName = profile.displayName;
          _userEmail = profile.email;
          _memberSince = profile.memberSinceFormatted;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryAccent,
          ),
        ),
      );
    }

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
                              _userProfileService.getInitials(_userName),
                              style: AppTextStyles.pageHeadline.copyWith(
                                fontSize: 40,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.lg),

                        // Name
                        Text(_userName, style: AppTextStyles.recipeTitle),
                        SizedBox(height: AppSpacing.sm),

                        // Email
                        Text(
                          _userEmail,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),

                        // Member Since
                        Text(
                          'Member since $_memberSince',
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
                    // Navigate to edit profile and reload when coming back
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(),
                      ),
                    );
                    // Reload profile data
                    _loadUserProfile();
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
                  onTap: () {},
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