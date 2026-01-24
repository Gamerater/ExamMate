import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _examName = "Loading...";
  int _daysLeft = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExamData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadExamData();
    }
  }

  Future<void> _loadExamData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedExam = prefs.getString('selected_exam') ?? "General Exam";
    final String? savedDateString = prefs.getString('exam_date');

    DateTime targetDate;

    if (savedDateString != null) {
      targetDate = DateTime.parse(savedDateString);
    } else {
      targetDate = AppConstants.examDates[savedExam] ?? DateTime(2026, 5, 20);
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final targetStart =
        DateTime(targetDate.year, targetDate.month, targetDate.day);

    final difference = targetStart.difference(todayStart).inDays;

    if (mounted) {
      setState(() {
        _examName = savedExam;
        _daysLeft = difference > 0 ? difference : 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a lighter background for the whole screen
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent, // Modern "Floating" look
        elevation: 0,
      ),
      body: SingleChildScrollView(
        // Safe for smaller screens
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- HERO SECTION (COUNTDOWN CARD) ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  // Subtle, modern shadow
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 32.0, horizontal: 20.0),
                  child: Column(
                    children: [
                      // "Target" Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _examName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Huge Countdown Number
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$_daysLeft',
                              style: const TextStyle(
                                fontSize: 64, // Bigger and bolder
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                                height: 1.0,
                              ),
                            ),
                            const TextSpan(
                              text: '\nDays Left',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- ACTIONS HEADER ---
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800]),
                ),
              ),

              const SizedBox(height: 16),

              // --- MODERN BUTTONS ---

              // Daily Tasks Button
              _buildModernButton(
                icon: Icons.check_circle_outline,
                label: 'Daily Tasks',
                iconColor: Colors.green,
                onTap: () => Navigator.pushNamed(context, '/tasks'),
              ),

              const SizedBox(height: 16),

              // Progress Button
              _buildModernButton(
                icon: Icons.bar_chart,
                label: 'My Progress',
                iconColor: Colors.purple,
                onTap: () => Navigator.pushNamed(context, '/progress'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for consistent, clean buttons
  Widget _buildModernButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        iconColor.withOpacity(0.1), // Light background for icon
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 20),
                // Text
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                // Arrow indicator
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
