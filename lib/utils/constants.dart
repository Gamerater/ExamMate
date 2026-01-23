import 'package:flutter/material.dart';

class AppConstants {
  // App Strings
  static const String appName = 'ExamMate';
  static const String appSubtitle = 'Competitive Exam Planner';

  // Exam Dates (Year, Month, Day)
  // Edit this Map to add/remove exams or change dates
  static final Map<String, DateTime> examDates = {
    'JEE': DateTime(2026, 4, 15),
    'NEET': DateTime(2026, 5, 5),
    'UPSC': DateTime(2026, 6, 20),
    'SSC': DateTime(2026, 7, 10),
    'Banking': DateTime(2026, 8, 1),
  };

  // Dynamically get the list of names from the map keys
  static List<String> get availableExams => examDates.keys.toList();

  // Colors
  static const Color primaryColor = Colors.blue;
}
