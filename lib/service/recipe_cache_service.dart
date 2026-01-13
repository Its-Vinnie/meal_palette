import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/model/recipe_model.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/service/spoonacular_service.dart';

/// Enhanced service for proactive recipe caching
/// Automatically fetches and caches full recipe details in background
class RecipeCacheService {
  final FirestoreService _firestoreService = FirestoreService();
  
  //* Track which recipes are being cached to avoid duplicates
  final Set<int> _cachingInProgress = {};
  
  //* Maximum concurrent caching operations
  static const int _maxConcurrentCache = 3;
  
  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================
  
  /// Caches a list of recipes with their full details
  /// Called after getting search results, trending recipes, etc.
  Future<void> cacheRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) return;
    
    print('📦 Starting cache operation for ${recipes.length} recipes');
    
    //* Save basic recipe info immediately
    await _firestoreService.saveRecipesBatch(recipes);
    print('✅ Saved ${recipes.length} basic recipes to Firestore');
    
    //* Start background caching of full details
    _cacheRecipeDetailsInBackground(recipes);
  }
  
  /// Caches a single recipe with full details
  Future<void> cacheSingleRecipe(Recipe recipe) async {
    await cacheRecipes([recipe]);
  }
  
  /// Gets recipe details - checks cache first, then API
  Future<RecipeDetail?> getRecipeDetails(int recipeId) async {
    try {
      //* Check Firestore cache first
      final cachedData = await _firestoreService.getRecipe(
        recipeId.toString(),
      );
      
      if (cachedData != null) {
        //* Check if we have full details (ingredients & instructions)
        if (_hasFullDetails(cachedData)) {
          print('✅ Loaded recipe $recipeId from cache (full details)');
          return RecipeDetail.fromJson(cachedData);
        }
      }
      
      //* Not in cache or incomplete - fetch from API
      print('🌐 Fetching recipe $recipeId from API');
      final recipe = await SpoonacularService.getRecipeDetails(recipeId);
      
      //* Save to cache for next time
      await _firestoreService.saveDetailedRecipe(recipe);
      print('💾 Saved detailed recipe to cache: ${recipe.title}');
      
      return recipe;
      
    } catch (e) {
      print('❌ Error getting recipe details: $e');
      return null;
    }
  }
  
  // ============================================================================
  // BACKGROUND CACHING
  // ============================================================================
  
  /// Caches recipe details in background without blocking UI
  void _cacheRecipeDetailsInBackground(List<Recipe> recipes) {
    //* Process recipes in batches to avoid overwhelming API
    _processCachingQueue(recipes);
  }
  
  /// Process caching queue with rate limiting
  Future<void> _processCachingQueue(List<Recipe> recipes) async {
    final recipesToCache = <Recipe>[];
    
    //* Filter out recipes already being cached
    for (final recipe in recipes) {
      if (!_cachingInProgress.contains(recipe.id)) {
        recipesToCache.add(recipe);
      }
    }
    
    if (recipesToCache.isEmpty) {
      print('ℹ️ No new recipes to cache');
      return;
    }
    
    print('🔄 Background caching ${recipesToCache.length} recipes');
    
    //* Process in small batches to respect API rate limits
    for (int i = 0; i < recipesToCache.length; i += _maxConcurrentCache) {
      final batch = recipesToCache.skip(i).take(_maxConcurrentCache).toList();
      
      //* Cache this batch concurrently
      final futures = batch.map((recipe) => _cacheRecipeWithDetails(recipe));
      await Future.wait(futures, eagerError: false);
      
      //* Small delay between batches to avoid rate limiting
      if (i + _maxConcurrentCache < recipesToCache.length) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
    
    print('✅ Background caching completed');
  }
  
  /// Caches a single recipe with full details
  Future<void> _cacheRecipeWithDetails(Recipe recipe) async {
    //* Skip if already cached with full details
    if (await _hasFullDetailsInFirestore(recipe.id)) {
      print('⏭️ Recipe ${recipe.id} already has full details, skipping');
      return;
    }
    
    //* Mark as being cached
    _cachingInProgress.add(recipe.id);
    
    try {
      //* Fetch detailed recipe from API
      final detailedRecipe = await SpoonacularService.getRecipeDetails(
        recipe.id,
      );
      
      //* Save to Firestore
      await _firestoreService.saveDetailedRecipe(detailedRecipe);
      
      print('💾 Cached detailed recipe: ${recipe.title}');
      
    } catch (e) {
      //* Don't log API limit errors as failures
      if (!e.toString().contains('402') && !e.toString().contains('429')) {
        print('⚠️ Failed to cache recipe ${recipe.id}: $e');
      }
    } finally {
      //* Remove from in-progress set
      _cachingInProgress.remove(recipe.id);
    }
  }
  
  // ============================================================================
  // HELPER METHODS
  // ============================================================================
  
  /// Checks if recipe data has full details
  bool _hasFullDetails(Map<String, dynamic> data) {
    //* Check if ingredients and instructions are present
    final hasIngredients = data.containsKey('ingredients') && 
                          (data['ingredients'] as List).isNotEmpty;
    
    final hasInstructions = data.containsKey('instructions') && 
                           (data['instructions'] as List).isNotEmpty;
    
    return hasIngredients && hasInstructions;
  }
  
  /// Checks if recipe in Firestore has full details
  Future<bool> _hasFullDetailsInFirestore(int recipeId) async {
    try {
      final data = await _firestoreService.getRecipe(recipeId.toString());
      return data != null && _hasFullDetails(data);
    } catch (e) {
      return false;
    }
  }
  
  // ============================================================================
  // STATISTICS & MAINTENANCE
  // ============================================================================
  
  /// Gets caching statistics
  Future<Map<String, int>> getCacheStats() async {
    try {
      final totalRecipes = await _firestoreService.getRecipeCount();
      
      //* Count recipes with full details
      final allRecipes = await _firestoreService.getAllRecipes();
      final fullDetailCount = allRecipes.where(_hasFullDetails).length;
      
      return {
        'total': totalRecipes,
        'with_details': fullDetailCount,
        'basic_only': totalRecipes - fullDetailCount,
        'cache_percentage': totalRecipes > 0 
            ? ((fullDetailCount / totalRecipes) * 100).round() 
            : 0,
      };
    } catch (e) {
      print('❌ Error getting cache stats: $e');
      return {
        'total': 0,
        'with_details': 0,
        'basic_only': 0,
        'cache_percentage': 0,
      };
    }
  }
  
  /// Identifies recipes that need detail caching
  Future<List<int>> getRecipesNeedingDetails() async {
    final allRecipes = await _firestoreService.getAllRecipes();
    
    return allRecipes
        .where((recipe) => !_hasFullDetails(recipe))
        .map((recipe) {
          final id = recipe['id'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id) ?? 0;
          return 0;
        })
        .where((id) => id != 0)
        .toList();
  }
  
  /// Background job to fill in missing details
  Future<void> fillMissingDetails({int limit = 10}) async {
    try {
      final recipesNeeding = await getRecipesNeedingDetails();
      
      if (recipesNeeding.isEmpty) {
        print('✅ All cached recipes have full details');
        return;
      }
      
      print('🔄 Filling details for ${recipesNeeding.take(limit).length} recipes');
      
      //* Convert IDs to Recipe objects for caching
      final recipesToCache = <Recipe>[];
      for (final id in recipesNeeding.take(limit)) {
        try {
          final data = await _firestoreService.getRecipe(id.toString());
          if (data != null) {
            recipesToCache.add(Recipe.fromJson(data));
          }
        } catch (e) {
          print('⚠️ Error loading recipe $id: $e');
          continue;
        }
      }
      
      if (recipesToCache.isNotEmpty) {
        await _processCachingQueue(recipesToCache);
      }
    } catch (e) {
      print('❌ Error in fillMissingDetails: $e');
    }
  }
}

//* Global instance
final recipeCacheService = RecipeCacheService();