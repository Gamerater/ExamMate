import 'package:flutter/material.dart';

// Importing screens
import 'screens/splash_screen.dart';
import 'screens/exam_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/task_screen.dart';
import 'screens/progress_screen.dart';

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
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/exam': (context) => const ExamSelectionScreen(),
        '/tasks': (context) => const TaskScreen(),
        '/progress': (context) => const ProgressScreen(),
      },
    );
  }
}
