import 'package:flutter/material.dart';
import 'package:meal_palette/screen/onboarding/dietary_preferences_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 60,
                  color: AppColors.primaryAccent,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Welcome Title
              Text(
                'Welcome to\nMeal Palette!',
                style: AppTextStyles.pageHeadline.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Subtitle
              Text(
                'Let\'s personalize your cooking experience',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                'We\'ll ask a few quick questions to tailor recipe recommendations just for you',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Get Started Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DietaryPreferencesScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Skip Button
              TextButton(
                onPressed: () {
                  // Skip onboarding - navigate to main app
                  Navigator.pushReplacementNamed(context, '/main');
                },
                child: Text(
                  'Skip for now',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
