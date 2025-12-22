import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meal_palette/screen/welcome_screen.dart';
import 'package:meal_palette/screen/main_app_screen.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/theme/theme_design.dart';

void main() async {
  //* Ensure Flutter is ready before Firebase initializes
  WidgetsFlutterBinding.ensureInitialized();

  //* Initialize Firebase
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          return MainAppScreen();
        }

        //* User is not logged in
        return WelcomeScreen();
      },
    );
  }
}