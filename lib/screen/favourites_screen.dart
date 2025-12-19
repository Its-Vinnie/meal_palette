import 'package:flutter/material.dart';
import 'package:meal_palette/theme/theme_design.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text("Favorites", style: AppTextStyles.pageHeadline),

              SizedBox(height: 280),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border),

                  SizedBox(width: 10),

                  Text("No favorites yet", style: AppTextStyles.recipeTitle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
