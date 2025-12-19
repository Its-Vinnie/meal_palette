import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meal_palette/screen/welcome_screen.dart';
import 'package:meal_palette/screen/main_app_screen.dart';
import 'package:meal_palette/theme/theme_design.dart';

void main() async {

  //* Ensures that flutter is ready before firebase initialises 
  WidgetsFlutterBinding.ensureInitialized(); 

  //* initialises firebase with the app 
  Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: WelcomeScreen(),
      // Optional: Add named routes for better navigation
      routes: {
        '/welcome': (context) => WelcomeScreen(),
        '/main': (context) => MainAppScreen(),
      },
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:meal_palette/screen/welcome_screen.dart';
// import 'package:meal_palette/theme/theme_design.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       theme: AppTheme.darkTheme,
//       debugShowCheckedModeBanner: false,
//       home: WelcomeScreen(),
//     );
//   }
// }

