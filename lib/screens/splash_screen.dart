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
    // ... (delay logic)
    final delayJob = Future.delayed(const Duration(seconds: 2));
    final prefsJob = SharedPreferences.getInstance();

    await delayJob;
    final prefs = await prefsJob;

    // CHECKING PERSISTENCE:
    final String? savedExam = prefs.getString('selected_exam');

    if (mounted) {
      if (savedExam != null && savedExam.isNotEmpty) {
        // Data exists -> Go to Home (Skip selection)
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // No data -> Go to Selection
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
