import 'package:flutter/material.dart';
import 'package:meal_palette/service/user_profile_service.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/custom_text_field.dart';
import 'package:meal_palette/widgets/animated_error_message.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  //* Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  //* Services
  final _userProfileService = UserProfileService();
  
  //* Loading states
  bool _isLoadingProfile = true;
  bool _isUpdatingUsername = false;
  bool _isUpdatingEmail = false;
  
  //* Current values
  String? _currentUsername;
  String? _currentEmail;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Load current user profile
  Future<void> _loadUserProfile() async {
    try {
      final profile = await _userProfileService.getCurrentUserProfile();
      
      if (profile != null && mounted) {
        setState(() {
          _currentUsername = profile.displayName;
          _currentEmail = profile.email;
          _usernameController.text = profile.displayName;
          _emailController.text = profile.email;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorMessageOverlay.showError(context, 'Failed to load profile');
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  /// Update username only
  Future<void> _updateUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      ErrorMessageOverlay.showError(context, 'Please enter a username');
      return;
    }

    if (_usernameController.text.trim() == _currentUsername) {
      ErrorMessageOverlay.showError(context, 'Username is the same');
      return;
    }

    setState(() => _isUpdatingUsername = true);

    try {
      final success = await _userProfileService.updateDisplayName(
        _usernameController.text.trim(),
      );

      if (success && mounted) {
        setState(() {
          _currentUsername = _usernameController.text.trim();
        });
        ErrorMessageOverlay.showSuccess(
          context,
          'Username updated successfully!',
        );
      } else if (mounted) {
        ErrorMessageOverlay.showError(
          context,
          'Failed to update username',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorMessageOverlay.showError(
          context,
          'Error updating username: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingUsername = false);
      }
    }
  }

  /// Update email - requires password verification
  Future<void> _updateEmail() async {
    if (_emailController.text.trim().isEmpty) {
      ErrorMessageOverlay.showError(context, 'Please enter an email');
      return;
    }

    if (!_emailController.text.contains('@')) {
      ErrorMessageOverlay.showError(context, 'Please enter a valid email');
      return;
    }

    if (_emailController.text.trim() == _currentEmail) {
      ErrorMessageOverlay.showError(context, 'Email is the same');
      return;
    }

    // Show password dialog for security
    final password = await _showPasswordDialog();
    if (password == null) return;

    setState(() => _isUpdatingEmail = true);

    try {
      // Re-authenticate first
      final reauthSuccess = await _userProfileService.reauthenticateWithPassword(password);
      
      if (!reauthSuccess) {
        if (mounted) {
          ErrorMessageOverlay.showError(
            context,
            'Incorrect password. Please try again.',
          );
        }
        return;
      }

      // Update email
      final success = await _userProfileService.updateEmail(
        _emailController.text.trim(),
      );

      if (success && mounted) {
        ErrorMessageOverlay.showSuccess(
          context,
          'Verification email sent! Check your inbox.',
        );
        setState(() {
          _currentEmail = _emailController.text.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to update email';
        
        if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'Please sign in again to update your email';
        } else if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'This email is already in use';
        }
        
        ErrorMessageOverlay.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingEmail = false);
      }
    }
  }

  /// Show password verification dialog
  Future<String?> _showPasswordDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final passwordController = TextEditingController();
        
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Text('Verify Password', style: AppTextStyles.recipeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'For security, please enter your password to update your email.',
                style: AppTextStyles.bodyMedium,
              ),
              SizedBox(height: AppSpacing.lg),
              PasswordTextField(
                controller: passwordController,
                hint: 'Enter your password',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, passwordController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
              ),
              child: Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Edit Profile'),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryAccent,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Edit Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //* Profile Avatar
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryAccent,
                    ),
                    child: Center(
                      child: Text(
                        _userProfileService.getInitials(_currentUsername ?? 'U'),
                        style: AppTextStyles.pageHeadline.copyWith(
                          fontSize: 40,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: AppSpacing.xxl),

                //* Username Section
                Text(
                  'Username',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _usernameController,
                        label: 'Display Name',
                        hint: 'Enter your name',
                        prefixIcon: Icons.person_outline,
                      ),
                      SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUpdatingUsername ? null : _updateUsername,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          ),
                          child: _isUpdatingUsername
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.textPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('Update Username'),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSpacing.xl),

                //* Email Section
                Text(
                  'Email',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'You\'ll need to verify your password to change your email',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUpdatingEmail ? null : _updateEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryAccent,
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          ),
                          child: _isUpdatingEmail
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.textPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('Update Email'),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSpacing.xxl),

                //* Info Box
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.info,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Email changes require verification. Check your inbox after updating.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}