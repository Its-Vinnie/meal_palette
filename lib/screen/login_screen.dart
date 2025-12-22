import 'package:flutter/material.dart';
import 'package:meal_palette/screen/main_app_screen.dart';
import 'package:meal_palette/screen/register_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/custom_text_field.dart';
import 'package:meal_palette/widgets/animated_error_message.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  //* Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  //* Auth service instance
  final _authService = authService;

  @override
  void initState() {
    super.initState();
    //* Listen to auth service for error messages
    _authService.addListener(_handleAuthStateChange);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authService.removeListener(_handleAuthStateChange);
    super.dispose();
  }

  /// Handles auth state changes and shows errors
  void _handleAuthStateChange() {
    if (!mounted) return;

    //* Show error if exists
    if (_authService.errorMessage != null) {
      ErrorMessageOverlay.showError(context, _authService.errorMessage!);
      _authService.clearError();
    }
  }

  /// Handle email/password login
  Future<void> _handleEmailLogin() async {
    //* Validate form
    if (!_formKey.currentState!.validate()) return;

    //* Attempt sign in
    final credential = await _authService.signInWithEmailPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );

    //* Navigate to home if successful
    if (credential != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainAppScreen()),
      );
    }
  }

  /// Handle Google sign in
  Future<void> _handleGoogleSignIn() async {
    final credential = await _authService.signInWithGoogle();

    if (credential != null && mounted) {
      ErrorMessageOverlay.showSuccess(
        context,
        'Welcome back, ${credential.user?.displayName ?? "User"}!',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainAppScreen()),
      );
    }
  }

  /// Handle Apple sign in
  Future<void> _handleAppleSignIn() async {
    final credential = await _authService.signInWithApple();

    if (credential != null && mounted) {
      ErrorMessageOverlay.showSuccess(
        context,
        'Welcome back!',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainAppScreen()),
      );
    }
  }

  /// Show forgot password dialog
  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'Reset Password',
          style: AppTextStyles.recipeTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: AppTextStyles.bodyMedium,
            ),
            SizedBox(height: AppSpacing.lg),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty) {
                ErrorMessageOverlay.showError(
                  context,
                  'Please enter your email',
                );
                return;
              }

              Navigator.pop(context);

              final success = await _authService.sendPasswordResetEmail(
                email: emailController.text,
              );

              if (success && mounted) {
                ErrorMessageOverlay.showSuccess(
                  context,
                  'Password reset email sent! Check your inbox.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
            ),
            child: Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //* Header
                  Text("Welcome Back", style: AppTextStyles.pageHeadline),
                  SizedBox(height: 4),
                  Text(
                    "Let's get cooking 🧑‍🍳",
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  SizedBox(height: AppSpacing.xxxl),

                  //* Email field
                  CustomTextField(
                    controller: _emailController,
                    label: "Email",
                    hint: "Enter your email",
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppSpacing.lg),

                  //* Password field
                  PasswordTextField(
                    controller: _passwordController,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleEmailLogin(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppSpacing.md),

                  //* Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        'Forgot Password?',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: AppSpacing.md),

                  //* Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account yet?",
                        style: AppTextStyles.bodyMedium,
                      ),
                      SizedBox(width: 3),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.secondaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xl),

                  //* Login button with loading state
                  AnimatedBuilder(
                    animation: _authService,
                    builder: (context, child) {
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _authService.isLoading
                              ? null
                              : _handleEmailLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            foregroundColor: AppColors.textPrimary,
                            disabledBackgroundColor:
                                AppColors.primaryAccent.withOpacity(0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                          ),
                          child: _authService.isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.textPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "Login",
                                  style: AppTextStyles.button,
                                ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: AppSpacing.xl),

                  //* Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.textTertiary.withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Text(
                          "OR",
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.textTertiary.withOpacity(0.3),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xl),

                  //* Social login buttons
                  AnimatedBuilder(
                    animation: _authService,
                    builder: (context, child) {
                      return Column(
                        children: [
                          //* Google Sign In
                          _buildSocialButton(
                            icon: Icons.g_mobiledata,
                            label: "Continue with Google",
                            onPressed: _authService.isLoading
                                ? null
                                : _handleGoogleSignIn,
                          ),

                          SizedBox(height: AppSpacing.lg),

                          //* Apple Sign In
                          _buildSocialButton(
                            icon: Icons.apple,
                            label: "Continue with Apple",
                            onPressed: _authService.isLoading
                                ? null
                                : _handleAppleSignIn,
                          ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.surface.withOpacity(0.5),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            SizedBox(width: AppSpacing.md),
            Text(label, style: AppTextStyles.button.copyWith(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}