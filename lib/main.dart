import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meal_palette/database/firestore_service.dart';
import 'package:meal_palette/screen/welcome_screen.dart';
import 'package:meal_palette/screen/main_app_screen.dart';
import 'package:meal_palette/screen/onboarding/onboarding_welcome_screen.dart';
import 'package:meal_palette/screen/url_recipe_import_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/service/cache_maintenance_service.dart';
import 'package:meal_palette/service/user_profile_service.dart';
import 'package:meal_palette/service/user_preference_service.dart';
import 'package:meal_palette/state/user_profile_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

void main() async {
  //* Ensure Flutter is ready before Firebase initializes
  WidgetsFlutterBinding.ensureInitialized();

  //* Initialize Firebase
  await Firebase.initializeApp();

  //* Start cache maintenance service
  cacheMaintenanceService.startMaintenance();

  //* Initialize UserProfileState (singleton will auto-start listening)
  UserProfileState();

  //* Sync user profile on startup if user is logged in
  final userProfileService = UserProfileService();
  if (userProfileService.currentUser != null) {
    await userProfileService.syncUserProfile();
  }

    _testPermissions();

  runApp(const MyApp());
}


  Future<void> _testPermissions() async {
    // Wait a bit for app to fully load
    await Future.delayed(const Duration(seconds: 2));
    
    print('🧪 Testing permission request...');
    
    // Request microphone
    final micStatus = await Permission.microphone.request();
    print('🎤 Microphone status: $micStatus');
    
    // Request speech
    final speechStatus = await Permission.speech.request();
    print('🎤 Speech status: $speechStatus');
    
    // Check if they appear in settings now
    if (micStatus.isGranted && speechStatus.isGranted) {
      print('✅ Permissions granted!');
    } else {
      print('❌ Permissions denied: mic=$micStatus, speech=$speechStatus');
    }
  }

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Global key for navigation
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initSharingIntent();
  }

  /// Initialize sharing intent listener
  void _initSharingIntent() {
    // Listen to shared media (URLs, text) when app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final sharedUrl = value.first.path;
          _handleSharedUrl(sharedUrl);
        }
      },
      onError: (err) {
        print("❌ Error receiving shared media: $err");
      },
    );

    // Get the media sharing coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final sharedUrl = value.first.path;
        Future.delayed(const Duration(seconds: 1), () {
          _handleSharedUrl(sharedUrl);
        });
      }
    });

    // Alternative: listen for text sharing (if supported)
    // Some versions of receive_sharing_intent package support text sharing
    // If not available, the media stream should handle URLs shared as text
  }

  /// Handle shared URL by navigating to URL import screen
  void _handleSharedUrl(String url) {
    print('🔗 Received shared URL: $url');

    // Validate URL
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      print('⚠️ Invalid URL: $url');
      return;
    }

    // Navigate to URL import screen with pre-filled URL
    Future.delayed(const Duration(milliseconds: 500), () {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => UrlRecipeImportScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: AuthStateHandler(),
      routes: {
        '/welcome': (context) => WelcomeScreen(),
        '/main': (context) => MainAppScreen(),
      },
    );
  }
}

/// Handles authentication state and shows appropriate screen
class AuthStateHandler extends StatelessWidget {
  const AuthStateHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        //* Loading state while checking auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  //* App logo or icon here
                  Icon(
                    Icons.restaurant_menu,
                    size: 80,
                    color: AppColors.primaryAccent,
                  ),
                  SizedBox(height: AppSpacing.xl),
                  CircularProgressIndicator(
                    color: AppColors.primaryAccent,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    'Meal Palette',
                    style: AppTextStyles.pageHeadline,
                  ),
                ],
              ),
            ),
          );
        }

        //* User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          // Trigger migration of existing favorites to collections
          Future.microtask(() async {
            final firestoreService = FirestoreService();
            await firestoreService.migrateExistingFavorites(snapshot.data!.uid);
          });

          // Check if user has completed onboarding
          return FutureBuilder<bool>(
            future: userPreferenceService.hasCompletedOnboarding(snapshot.data!.uid),
            builder: (context, onboardingSnapshot) {
              // Loading while checking onboarding status
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryAccent,
                    ),
                  ),
                );
              }

              // Show onboarding if not completed
              final hasCompleted = onboardingSnapshot.data ?? false;
              if (!hasCompleted) {
                return const OnboardingWelcomeScreen();
              }

              // Show main app if onboarding is complete
              return const MainAppScreen();
            },
          );
        }

        //* User is not logged in
        return WelcomeScreen();
      },
    );
  }
}