# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Meal Palette is a Flutter recipe application that combines recipe search, ingredient-based generation, and favorites management. The app uses Firebase for authentication and data storage, with the Spoonacular API for recipe data.

## Development Commands

### Running the App
```bash
flutter run                    # Run on default device
flutter run -d ios            # Run on iOS simulator
flutter run -d android        # Run on Android emulator
```

### Building
```bash
flutter build apk             # Build Android APK
flutter build ios             # Build iOS (requires macOS)
flutter build appbundle       # Build Android App Bundle
```

### Dependencies
```bash
flutter pub get               # Install dependencies
flutter pub upgrade           # Upgrade dependencies
flutter clean                 # Clean build artifacts
```

### Code Analysis
```bash
flutter analyze               # Run static analysis
```

### App Icons
```bash
flutter pub run flutter_launcher_icons
```

## Architecture

### Service Layer Pattern

The app uses a service-based architecture with singleton services:

- **SpoonacularService** (`lib/service/spoonacular_service.dart`): Static methods for Spoonacular API calls (search, ingredient-based search, recipe details, autocomplete)
- **RecipeCacheService** (`lib/service/recipe_cache_service.dart`): Proactive caching layer that stores API responses in Firestore to reduce API calls. Implements background caching with rate limiting.
- **FirestoreService** (`lib/database/firestore_service.dart`): All Firestore database operations (recipes, favorites, user profiles, view tracking)
- **IngredientRecipeService** (`lib/service/ingredient_recipe_service.dart`): Manages ingredient generation history and saved meal plans
- **AuthService** (`lib/service/auth_service.dart`): Singleton ChangeNotifier for Firebase Auth (email/password, Google, Apple sign-in)
- **CacheMaintenanceService** (`lib/service/cache_maintenance_service.dart`): Background service started in main.dart for cache cleanup

Global instances are exported at bottom of service files (e.g., `final authService = AuthService()`).

### State Management

- **FavoritesState** (`lib/state/favorites_state.dart`): ChangeNotifier singleton that manages favorites state, listens to auth state changes, implements optimistic UI updates
- **EditProfileState** (`lib/state/edit_profile_state.dart`): Manages profile editing state

State classes use singleton pattern with `_instance` and factory constructor.

### Data Flow: Recipe Details

1. User taps recipe → `RecipeCacheService.getRecipeDetails(id)`
2. Check Firestore cache for full details (ingredients + instructions)
3. If cached: return immediately
4. If not cached: fetch from Spoonacular API, save to Firestore
5. Background caching processes new recipes in batches (max 3 concurrent, 2s delay between batches)

### Navigation Structure

- **MainAppScreen** uses IndexedStack with 4 screens: Home, Search, Favorites, Profile
- **CustomBottomNavBar** with center FAB (index 4) opens ingredient input modal
- Auth routing in `main.dart`: StreamBuilder on `authService.authStateChanges` decides between WelcomeScreen and MainAppScreen

### Firebase Configuration

Firebase is initialized in `main.dart` before runApp:
```dart
await Firebase.initializeApp();
cacheMaintenanceService.startMaintenance();
```

Configuration files:
- iOS: `ios/Runner/GoogleService-Info.plist`
- Android: `android/app/google-services.json`

**IMPORTANT**: Never commit or modify Firebase config files directly.

### API Integration

Spoonacular API key is hardcoded in `SpoonacularService._apiKey`. Main endpoints used:
- `/recipes/complexSearch` - recipe search with filters
- `/recipes/findByIngredients` - ingredient-based search
- `/recipes/{id}/information` - detailed recipe data
- `/food/ingredients/autocomplete` - ingredient suggestions

Handle 402 (quota exceeded) and 429 (rate limit) status codes gracefully.

### Firestore Data Structure

```
users/{userId}/
  - profile data (name, email, photoUrl, provider)
  - favorites/{recipeId} - favorited recipes
  - viewHistory/{recipeId} - recipe views with timestamps
  - ingredientGenerations/{id} - ingredient generation history
  - mealPlans/{id} - saved meal plans

recipes/{recipeId}
  - Basic recipe data (id, title, image, etc.)
  - Full details when cached (ingredients, instructions)
```

Recipe IDs must be integers. Service includes `_parseRecipeId` helper to handle mixed types.

### Theme System

Theme defined in `lib/theme/theme_design.dart`:
- Dark theme by default (`AppTheme.darkTheme`)
- `AppColors` - semantic color tokens
- `AppTextStyles` - typography system
- `AppSpacing` and `AppRadius` - spacing/border radius constants

Use theme tokens instead of hardcoded values.

## Common Patterns

### Error Handling in Services

Services use try-catch with emoji logging:
```dart
try {
  // operation
  print("✅ Success message");
} catch (e) {
  print("❌ Error message: $e");
  rethrow; // or return fallback
}
```

### Authentication State

Auth state flows from `AuthService.authStateChanges` stream:
1. `main.dart` AuthStateHandler listens to stream
2. `FavoritesState` listens to load favorites on login
3. Services check `authService.currentUser` for user ID

### Adding New Recipe Sources

When adding new recipe data sources:
1. Fetch recipes and convert to `Recipe` model
2. Call `recipeCacheService.cacheRecipes(recipes)` to store
3. Background process will fetch full details
4. Use `recipeCacheService.getRecipeDetails(id)` for detail view

### Working with Models

Key models in `lib/model/`:
- **Recipe** - basic recipe data, includes `fromJson` and `toMap`
- **RecipeDetail** - full recipe with ingredients and instructions
- **IngredientGeneration** - stores ingredient list and timestamp
- **Ingredient** - structured ingredient data
- **InstructionStep** - cooking step data
- **UserModel** - user profile data

Models handle JSON serialization. Ensure ID fields are integers.

## Important Notes

- The app uses a cache-first strategy to minimize Spoonacular API calls
- Recipe caching happens in background; don't block UI
- Always use `recipeCacheService` instead of calling Spoonacular directly for recipe details
- Favorites require authenticated user; check `authService.currentUser != null`
- State classes use `notifyListeners()` after updates
- Optimistic UI updates: update UI immediately, revert on error
- Recipe ID parsing: handle both int and string types from Firestore