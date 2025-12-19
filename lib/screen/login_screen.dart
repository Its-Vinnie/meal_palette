import 'package:flutter/material.dart';
import 'package:meal_palette/screen/home_screen.dart';
import 'package:meal_palette/screen/register_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome Back", style: AppTextStyles.pageHeadline),

                  SizedBox(height: 4),

                  Text(
                    "Let's get cooking 🧑‍🍳 ",
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  SizedBox(height: 20),

                  CustomTextField(
                    controller: _emailController,
                    label: "Email",
                    hint: "Enter your email",
                    prefixIcon: Icons.email_outlined,
                  ),

                  SizedBox(height: 10),

                  CustomTextField(
                    controller: _passwordController,
                    label: "Password",
                    hint: "Enter your password",
                    prefixIcon: Icons.lock_outline,
                  ),

                  SizedBox(height: 10),

                  Row(
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
                          "SignUp",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.secondaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => HomeScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        shadowColor: AppColors.primaryAccent.withValues(
                          alpha: 0.3,
                        ),
                      ),

                      child: Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
