import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _examName = "Loading...";
  int _daysLeft = 0;
  int _rawDifference = 0;
  bool _isCustomExam = false;

  // NEW: State for Streak and Greeting
  int _streak = 0;
  String _greeting = "Hello";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateGreeting(); // Set initial greeting
    _loadData(); // Load all data (Exam + Streak)
    _refreshNotification(); // Ensure notifications are sync'd
  }

  /// Updates greeting based on hour of day
  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        _greeting = "Good Morning";
      } else if (hour < 17) {
        _greeting = "Good Afternoon";
      } else {
        _greeting = "Good Evening";
      }
    });
  }

  /// Checks if reminders are enabled and updates the message/time
  Future<void> _refreshNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('daily_reminder') ?? false;

    if (isEnabled) {
      final int hour = prefs.getInt('reminder_hour') ?? 20;
      final int minute = prefs.getInt('reminder_minute') ?? 0;
      await NotificationService().scheduleDailyReminder(hour, minute);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
      _updateGreeting();
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Streak
    final int streak = prefs.getInt('current_streak') ?? 0;

    // 2. Load Exam Data
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
        _streak = streak; // Update Streak UI
        _examName = savedExam;

        if (difference < 0) {
          _daysLeft = 0;
        } else {
          _daysLeft = difference;
        }

        _rawDifference = difference;
        _isCustomExam = !AppConstants.availableExams.contains(savedExam);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: textColor),
            onPressed: () {
              Navigator.pushNamed(context, '/settings').then((_) {
                _loadData(); // Reload when returning from settings
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // NEW: Greeting Text
              Text(
                "$_greeting, Student.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // --- MAIN DASHBOARD CARD ---
              Container(
                decoration: BoxDecoration(
                  // NEW: Subtle Gradient for premium look
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1E1E), const Color(0xFF252525)]
                        : [Colors.white, Colors.grey.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // TOP ROW: Exam Name vs Streak
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Exam Tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _examName.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                if (_isCustomExam) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit,
                                      size: 12, color: Colors.blue),
                                ],
                              ],
                            ),
                          ),

                          // Streak Counter (NEW)
                          Row(
                            children: [
                              Icon(Icons.local_fire_department,
                                  size: 20,
                                  color: _streak > 0
                                      ? Colors.deepOrange
                                      : Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                "$_streak Day Streak",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _streak > 0
                                      ? Colors.deepOrange
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),

                      const SizedBox(height: 30),

                      // CENTER: Countdown
                      Text(
                        _rawDifference < 0 ? "Done" : '$_daysLeft',
                        style: TextStyle(
                          fontSize: _rawDifference < 0 ? 48 : 72,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          height: 1.0,
                          letterSpacing: -2.0,
                        ),
                      ),
                      Text(
                        _rawDifference < 0
                            ? 'Goal Completed'
                            : 'Days Remaining',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- QUICK ACTIONS ---
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _BouncingButton(
                onTap: () => Navigator.pushNamed(context, '/tasks')
                    .then((_) => _loadData()),
                child: _buildModernButtonContent(
                  context,
                  icon: Icons.check_circle_outline,
                  label: 'Daily Tasks',
                  iconColor: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              _BouncingButton(
                onTap: () => Navigator.pushNamed(context, '/progress')
                    .then((_) => _loadData()),
                child: _buildModernButtonContent(
                  context,
                  icon: Icons.bar_chart,
                  label: 'My Progress',
                  iconColor: Colors.purple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernButtonContent(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark ? Border.all(color: Colors.white10) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

// Button Animation Class (Unchanged)
class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _BouncingButton({required this.child, required this.onTap});
  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
