import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    // 1. Start the minimum delay timer immediately (Parallel execution)
    // Ensures splash is visible for at least 2 seconds regardless of load speed
    final delayJob = Future.delayed(const Duration(seconds: 2));

    SharedPreferences? prefs;

    // 2. Try to load preferences safely
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // FIX: Catch storage errors to prevent App Hang in release mode
      debugPrint("Error loading SharedPreferences: $e");
      // prefs remains null, triggering fallback below
    }

    // 3. Always wait for the animation/delay to finish
    await delayJob;

    if (!mounted) return;

    // 4. Determine Navigation
    // If prefs is null (error) or key is missing, default to '/exam'
    final String? savedExam = prefs?.getString('selected_exam');

    try {
      if (savedExam != null && savedExam.isNotEmpty) {
        // Data exists -> Go to Home (Skip selection)
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // No data or Error -> Go to Selection (Safe Fallback)
        Navigator.pushReplacementNamed(context, '/exam');
      }
    } catch (e) {
      // FIX: Prevent crash if route names are missing in main.dart
      debugPrint("Navigation Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Adapt to current theme (prevent white flash in Dark Mode)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // FIX: Use theme background color
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ExamMate',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Competitive Exam Planner',
              style: TextStyle(
                fontSize: 16,
                // FIX: Ensure text is visible on both light/dark backgrounds
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
