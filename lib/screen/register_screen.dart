import 'package:flutter/material.dart';
import 'package:meal_palette/screen/login_screen.dart';
import 'package:meal_palette/screen/main_app_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/custom_text_field.dart';
import 'package:meal_palette/widgets/animated_error_message.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  //* Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  //* Auth service
  final _authService = authService;

  //* Password visibility
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _authService.addListener(_handleAuthStateChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authService.removeListener(_handleAuthStateChange);
    super.dispose();
  }

  /// Handle auth state changes
  void _handleAuthStateChange() {
    if (!mounted) return;

    if (_authService.errorMessage != null) {
      ErrorMessageOverlay.showError(context, _authService.errorMessage!);
      _authService.clearError();
    }
  }

  /// Handle email/password registration
  Future<void> _handleRegister() async {
    //* Validate form
    if (!_formKey.currentState!.validate()) return;

    //* Check password match
    if (_passwordController.text != _confirmPasswordController.text) {
      ErrorMessageOverlay.showError(context, 'Passwords do not match');
      return;
    }

    //* Create account
    final credential = await _authService.createAccountWithEmailPassword(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
    );

    //* Navigate to home if successful
    if (credential != null && mounted) {
      ErrorMessageOverlay.showSuccess(
        context,
        'Welcome, ${_nameController.text}! 🎉',
      );
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
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
      ErrorMessageOverlay.showSuccess(
        context,
        isNewUser
            ? 'Welcome, ${credential.user?.displayName ?? "User"}! 🎉'
            : 'Welcome back, ${credential.user?.displayName ?? "User"}!',
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
        'Welcome! 🎉',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainAppScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //* Header
                  Text("Create Account", style: AppTextStyles.pageHeadline),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    "Sign up to get started",
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  SizedBox(height: AppSpacing.xxxl),

                  //* Name Field
                  CustomTextField(
                    controller: _nameController,
                    label: "Full Name",
                    hint: "Enter your name",
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppSpacing.lg),

                  //* Email Field
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
                      final emailRegex = RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(value)) {
                        return 'Please enter a valid email format';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppSpacing.lg),

                  //* Password Field
                  CustomTextField(
                    controller: _passwordController,
                    label: "Password",
                    hint: "Create a password",
                    prefixIcon: Icons.lock_outline,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.next,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppSpacing.lg),

                  //* Confirm Password Field
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: "Confirm Password",
                    hint: "Re-enter your password",
                    prefixIcon: Icons.lock_outline,
                    obscureText: !_isConfirmPasswordVisible,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleRegister(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppSpacing.xxxl),

                  //* Register Button
                  AnimatedBuilder(
                    animation: _authService,
                    builder: (context, child) {
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _authService.isLoading
                              ? null
                              : _handleRegister,
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
                                  "Create Account",
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

                  //* Social Login Buttons
                  AnimatedBuilder(
                    animation: _authService,
                    builder: (context, child) {
                      return Column(
                        children: [
                          _buildSocialButton(
                            icon: Icons.g_mobiledata,
                            label: "Continue with Google",
                            onPressed: _authService.isLoading
                                ? null
                                : _handleGoogleSignIn,
                          ),
                          SizedBox(height: AppSpacing.lg),
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

                  //* Login Link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Sign In",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
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