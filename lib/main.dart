import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // 1. IMPORT THIS

// Importing screens
import 'screens/splash_screen.dart';
import 'screens/exam_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/task_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ExamMateApp());
}

class ExamMateApp extends StatelessWidget {
  const ExamMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,

        // 2. APPLY GLOBAL FONT HERE
        // This takes the standard Material text theme and converts
        // every style (headlines, body text, buttons) to Poppins.
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),

        // Keep your existing animation transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/exam': (context) => const ExamSelectionScreen(),
        '/tasks': (context) => const TaskScreen(),
        '/progress': (context) => const ProgressScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
