import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemUiOverlayStyle

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access theme data for dynamic colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic text colors (Defensive checks added)
    final headingColor = isDark ? Colors.white : Colors.black87;
    // explicit fallback to ensure non-null color safety
    final bodyColor = isDark
        ? (Colors.grey[300] ?? Colors.white70)
        : (Colors.grey[800] ?? Colors.black87);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // FIX: Ensure Status Bar icons are visible on transparent AppBar
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark, // Android
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // iOS
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Privacy Policy',
            style: TextStyle(color: headingColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          // FIX: Force icon color to match heading for guaranteed visibility
          iconTheme: IconThemeData(color: headingColor),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: "1. Introduction",
                content:
                    "ExamMate respects your privacy. We do not collect, store, or share your personal data. ExamMate is an offline-first application designed to help students track their exam preparation.",
                headingColor: headingColor,
                bodyColor: bodyColor,
              ),
              _buildSection(
                title: "2. Data Collection & Storage",
                content:
                    "We do not collect personal information like names or emails.\n\nAll data is stored locally on your device using internal storage. This includes:\n• Exam Goal Name\n• Exam Date\n• Daily Tasks\n• Streak Progress",
                headingColor: headingColor,
                bodyColor: bodyColor,
              ),
              _buildSection(
                title: "3. Data Sharing",
                content:
                    "Since ExamMate operates offline, your data never leaves your device. We do not sell or transfer your information. We do not use third-party analytics.",
                headingColor: headingColor,
                bodyColor: bodyColor,
              ),
              _buildSection(
                title: "4. Internet Access",
                content:
                    "The app works entirely without an internet connection. No data is uploaded to any server.",
                headingColor: headingColor,
                bodyColor: bodyColor,
              ),
              _buildSection(
                title: "5. Contact Us",
                content:
                    "If you have questions, please contact the developer via the app store support page.",
                headingColor: headingColor,
                bodyColor: bodyColor,
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  "Last Updated: January 2026",
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required Color? headingColor,
    required Color? bodyColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: bodyColor,
            ),
          ),
        ],
      ),
    );
  }
}
