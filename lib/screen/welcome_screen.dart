import 'package:flutter/material.dart';
import 'package:meal_palette/screen/main_app_screen.dart';
// import 'package:meal_palette/screen/register_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/slider_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/welcome_image2.png"),
            fit: BoxFit.cover, // This makes it fill the whole screen
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cook.\nEat. \nBetter!', style: AppTextStyles.heroTitle),
                SizedBox(height: 20),
                Text(
                  "Delicious recipes for every \nmeal you can image. \nEasy. Fun. Healthy",
                  style: AppTextStyles.bodyLarge,
                ),
                SizedBox(height: 330),
                SliderButton(
                  label: "Get Started",
                  onSlideComplete: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => MainAppScreen()),
                    );
                  },

                  backgroundColor: AppColors.primaryAccent,
                  sliderColor: AppColors.background,
                  textColor: AppColors.textPrimary,
                ),
                SizedBox(height: 38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
