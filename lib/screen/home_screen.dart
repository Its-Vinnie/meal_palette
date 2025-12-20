import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/screen/recipe_details_screen.dart';
import 'package:meal_palette/service/spoonacular_service.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/recipe_cards.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State variables
  List<Recipe> _trendingRecipes = [];
  List<Recipe> _popularRecipes = [];
  bool _isLoadingTrending = true;
  bool _isLoadingPopular = true;
  List<bool> _trendingFavorites = [];
  List<bool> _popularFavorites = [];

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    // Load trending recipes (horizontal scroll)
    try {
      final trending = await SpoonacularService.getRandomRecipes(number: 6);
      setState(() {
        _trendingRecipes = trending;
        _firestoreService.saveRecipe(trending);
        _trendingFavorites = List.filled(trending.length, false);
        print(_trendingFavorites);
        _isLoadingTrending = false;
      });
    } catch (e) {
      print('Error loading trending recipes: $e');
      setState(() {
        _isLoadingTrending = false;
      });
    }

    // Load popular recipes (vertical cards)
    try {
      final popular = await SpoonacularService.searchRecipes(
        query: 'low sugar',
        number: 5,
      );
      setState(() {
        _popularRecipes = popular;
        _popularFavorites = List.filled(popular.length, false);
        _isLoadingPopular = false;
      });
    } catch (e) {
      print('Error loading popular recipes: $e');
      setState(() {
        _isLoadingPopular = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryAccent,
          onRefresh: () async {
            setState(() {
              _isLoadingTrending = true;
              _isLoadingPopular = true;
            });
            await _loadRecipes();
          },
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: AppDecorations.iconButtonDecoration,
                            child: IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.person,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "Hi Vincent ",
                                  style: AppTextStyles.bodyLarge,
                                ),
                                TextSpan(text: "👋🏼"),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: AppDecorations.iconButtonDecoration,
                        child: IconButton(
                          onPressed: () {},
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // Main Headline
                  Text(
                    "What's cooking\ntoday?",
                    style: AppTextStyles.pageHeadline,
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // Search Bar
                  TextField(
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search your home...",
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textTertiary,
                      ),
                      suffixIcon: Container(
                        margin: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // Category Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCategoryIcon(Icons.lunch_dining, "Western", true),
                      _buildCategoryIcon(Icons.bakery_dining, "Bread", false),
                      _buildCategoryIcon(Icons.soup_kitchen, "Soup", false),
                      _buildCategoryIcon(Icons.cake, "Dessert", false),
                      _buildCategoryIcon(Icons.coffee, "Coffee", false),
                    ],
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  // Section Header: Trending Recipes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Trending Recipes",
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          print("See more trending clicked");
                        },
                        child: Row(
                          children: [
                            Text(
                              "See More",
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.primaryAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              color: AppColors.primaryAccent,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.lg),

                  // Horizontal Scrolling Recipe Cards
                  SizedBox(
                    height: 200,
                    child: _isLoadingTrending
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryAccent,
                            ),
                          )
                        : _trendingRecipes.isEmpty
                        ? Center(
                            child: Text(
                              'No trending recipes found',
                              style: AppTextStyles.bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _trendingRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = _trendingRecipes[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index == _trendingRecipes.length - 1
                                      ? 0
                                      : AppSpacing.lg,
                                ),
                                child: RecipeCard(
                                  imageUrl:
                                      recipe.image ??
                                      'assets/images/placeholder.png',
                                  title: recipe.title,
                                  time: '${recipe.readyInMinutes ?? 0} min',
                                  isFavorite: _trendingFavorites[index],
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            RecipeDetailScreen(
                                              recipeId: recipe.id,
                                            ),
                                      ),
                                    );
                                  },
                                  onFavoritePressed: () {
                                    setState(() {
                                      _trendingFavorites[index] =
                                          !_trendingFavorites[index];
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),

                  SizedBox(height: AppSpacing.xxl),

                  // Section Header: Popular
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Popular This Week",
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          print("See more popular clicked");
                        },
                        child: Row(
                          children: [
                            Text(
                              "See More",
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.primaryAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              color: AppColors.primaryAccent,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.lg),

                  // Vertical Recipe Cards from API
                  _isLoadingPopular
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xxl),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        )
                      : _popularRecipes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xxl),
                            child: Text(
                              'No popular recipes found',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        )
                      : Column(
                          children: _popularRecipes.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final recipe = entry.value;

                            return RecipeCardVertical(
                              imageUrl:
                                  recipe.image ??
                                  'assets/images/placeholder.png',
                              title: recipe.title,
                              time: '${recipe.readyInMinutes ?? 0} min',
                              servings: '${recipe.servings ?? 0} servings',
                              difficulty:
                                  'Medium', // API doesn't provide difficulty
                              isFavorite: _popularFavorites[index],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RecipeDetailScreen(recipeId: recipe.id),
                                  ),
                                );
                              },
                              onFavoritePressed: () {
                                setState(() {
                                  _popularFavorites[index] =
                                      !_popularFavorites[index];
                                });
                              },
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(IconData icon, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: isActive
              ? AppDecorations.activeCategoryIconDecoration
              : AppDecorations.categoryIconDecoration,
          child: Icon(
            icon,
            color: isActive ? AppColors.primaryAccent : AppColors.textPrimary,
            size: 28,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isActive ? AppColors.primaryAccent : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// import 'dart:ffi';

// import 'package:flutter/material.dart';
// import 'package:meal_palette/theme/theme_design.dart';
// import 'package:meal_palette/widgets/custom_gesture_widget.dart';

// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.overlayDark,
//       body: SingleChildScrollView(
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.all(AppSpacing.md),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.start,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       decoration: AppDecorations.glassDecoration,
//                       child: IconButton(
//                         onPressed: () {},
//                         icon: Icon(Icons.person),
//                       ),
//                     ),

//                     SizedBox(width: 5),

//                     Text("Hi Vincent 👋🏼", style: AppTextStyles.bodyLarge),

//                     SizedBox(width: 140),

//                     Container(
//                       decoration: AppDecorations.glassDecoration,
//                       child: IconButton(
//                         onPressed: () {},
//                         icon: Icon(Icons.notification_add_outlined),
//                       ),
//                     ),
//                   ],
//                 ),

//                 SizedBox(height: 10),

//                 Text(
//                   "What's cooking \ntoday?",
//                   style: AppTextStyles.recipeTitle,
//                 ),

//                 SizedBox(height: 25),

//                 TextField(
//                   decoration: InputDecoration(
//                     hint: Text(
//                       "Search a recipe",
//                       style: AppTextStyles.bodyMedium,
//                     ),
//                   ),
//                 ),

//                 SizedBox(height: 25),

//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     Container(
//                       width: 60,

//                       decoration: AppDecorations.glassDecoration,
//                       child: IconButton(
//                         onPressed: () {},
//                         icon: Icon(Icons.restaurant),
//                       ),
//                     ),

//                     Container(
//                       width: 60,

//                       decoration: AppDecorations.glassDecoration,
//                       child: IconButton(
//                         onPressed: () {},
//                         icon: Icon(Icons.set_meal),
//                       ),
//                     ),

//                     Container(
//                       width: 60,

//                       decoration: AppDecorations.glassDecoration,
//                       child: IconButton(
//                         onPressed: () {},
//                         icon: Icon(Icons.bakery_dining_rounded),
//                       ),
//                     ),

//                     Container(
//                       width: 60,
//                       decoration: AppDecorations.glassDecoration,
//                       child: IconButton(
//                         onPressed: () {},
//                         icon: Icon(Icons.restaurant),
//                       ),
//                     ),

//                     Container(
//                       width: 60,

//                       decoration: AppDecorations.glassDecoration,
//                       child: IconButton(
//                         onPressed: () {},
//                         icon: Icon(Icons.restaurant),
//                       ),
//                     ),
//                   ],
//                 ),

//                 SizedBox(height: 25),

//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text("Trending Recipes", style: AppTextStyles.bodyLarge),

//                     CustomGestureWidget(
//                       label: "See more",
//                       suffixIcon: Icon(Icons.arrow_circle_right_sharp),
//                       onTap: () {
//                         print("See more clicked");
//                       },
//                     ),

//                     // Text("See more", style: AppTextStyles.bodyLarge),

//                     // IconButton(onPressed: () {}, icon: Icon(Icons.arrow_forward)),
//                   ],
//                 ),

//                 SizedBox(height: 30),

//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Container(
//                       decoration: AppDecorations.recipeCardDecoration,
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Container(
//                             decoration: AppDecorations.glassDecoration,
//                             child: IconButton(
//                               onPressed: () {
//                                 //* it must react to the recipe
//                               },
//                               icon: Icon(Icons.favorite_border_outlined),
//                             ),
//                           ),

//                           Text(
//                             "Creamy tuscan \nchicken",
//                             style: AppTextStyles.recipeTitle,
//                           ),
//                         ],
//                       ),
//                     ),

//                     IconButton(
//                       onPressed: () {
//                         print("recipe clicked");
//                       },
//                       icon: Icon(Icons.arrow_right_alt_sharp),
//                     ),
//                   ],
//                 ),
//                 Container(
//                   decoration: AppDecorations.recipeCardDecoration,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         decoration: AppDecorations.glassDecoration,
//                         child: IconButton(
//                           onPressed: () {
//                             //* it must react to the recipe
//                           },
//                           icon: Icon(Icons.favorite_border_outlined),
//                         ),
//                       ),

//                       Text(
//                         "Creamy tuscan \nchicken",
//                         style: AppTextStyles.recipeTitle,
//                       ),
//                     ],
//                   ),
//                 ),
//                 Container(
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: AppColors.favorite),
//                     boxShadow: AppShadows.cardShadow,
//                     image: DecorationImage(
//                       image: AssetImage("assets/images/welcome_image.png"),
//                     ),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         decoration: AppDecorations.glassDecoration,
//                         child: IconButton(
//                           onPressed: () {
//                             //* it must react to the recipe
//                           },
//                           icon: Icon(Icons.favorite_border_outlined),
//                         ),
//                       ),

//                       Text(
//                         "Creamy tuscan \nchicken",
//                         style: AppTextStyles.recipeTitle,
//                       ),
//                     ],
//                   ),
//                 ),

//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
