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
  bool _isCustomExam = false;

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
        _isCustomExam = !AppConstants.availableExams.contains(savedExam);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access current theme colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      // 1. Use Theme Background
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: textColor),
            onPressed: () {
              Navigator.pushNamed(context, '/settings').then((_) {
                _loadExamData();
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
              Container(
                decoration: BoxDecoration(
                  // 2. Use Theme Card Color
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          // 3. Dynamic Accent Color (Opacity works on both modes)
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _examName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 14,
                              ),
                            ),
                            if (_isCustomExam) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.edit,
                                  size: 14, color: Colors.blue),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$_daysLeft',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                // 4. Dynamic Text Color
                                color: textColor,
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
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.grey[300]
                        : Colors.grey[800], // Adjust for dark mode
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _BouncingButton(
                onTap: () => Navigator.pushNamed(context, '/tasks'),
                child: _buildModernButtonContent(
                  context,
                  icon: Icons.check_circle_outline,
                  label: 'Daily Tasks',
                  iconColor: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              _BouncingButton(
                onTap: () => Navigator.pushNamed(context, '/progress'),
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
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor, // Dynamic Background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color, // Dynamic Text
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

// Bouncing Button remains exactly the same...
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
