import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/exam_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/task_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/intro_screen.dart';

// Services
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FIX: Initialize Notifications before app starts
  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;

  runApp(ExamMateApp(initialIsDark: isDark));
}

class ExamMateApp extends StatelessWidget {
  final bool initialIsDark;

  // Global Theme Notifier for Settings Screen
  static late ValueNotifier<ThemeMode> themeNotifier;

  ExamMateApp({super.key, required this.initialIsDark}) {
    themeNotifier =
        ValueNotifier(initialIsDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'ExamMate',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // --- LIGHT THEME ---
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey[50],
            cardColor: Colors.white,
            useMaterial3: true,
            textTheme:
                GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black87),
              titleTextStyle: TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              systemOverlayStyle: SystemUiOverlayStyle.dark,
            ),
          ),

          // --- DARK THEME ---
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            useMaterial3: true,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFFE0E0E0)),
              titleTextStyle: TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
            dividerColor: Colors.grey[800],
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(10),
              ),
              hintStyle: TextStyle(color: Colors.grey[600]),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
          ),

          // FIX: Updated Entry Point and Routes
          initialRoute: '/intro',
          routes: {
            '/intro': (context) => const IntroScreen(),
            '/splash': (context) => const SplashScreen(),
            '/home': (context) => const HomeScreen(),
            '/exam': (context) => const ExamSelectionScreen(),
            '/tasks': (context) => const TaskScreen(),
            '/progress': (context) => const ProgressScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/privacy': (context) => const PrivacyPolicyScreen(),
          },
        );
      },
    );
  }
}
