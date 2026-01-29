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

    if (savedExam != null && savedExam.isNotEmpty) {
      // Data exists -> Go to Home (Skip selection)
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // No data or Error -> Go to Selection (Safe Fallback)
      Navigator.pushReplacementNamed(context, '/exam');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            const Text(
              'Competitive Exam Planner',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
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
