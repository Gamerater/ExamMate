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
    // Run timer and data loading in parallel for speed
    final delayJob = Future.delayed(const Duration(seconds: 2));
    final prefsJob = SharedPreferences.getInstance();

    await delayJob;
    final prefs = await prefsJob;

    final String? savedExam = prefs.getString('selected_exam');

    if (mounted) {
      if (savedExam != null && savedExam.isNotEmpty) {
        // User has already set up -> Go to Home
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // First time user -> Go to Selection
        Navigator.pushReplacementNamed(context, '/exam');
      }
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
