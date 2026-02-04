import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';

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
  String _greeting = "Hello";

  final StreakService _streakService = StreakService();
  bool _isLoading = true;
  bool _isLowEnergyMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateGreeting();
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshNotification();
    });
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (mounted) {
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
  }

  Future<void> _refreshNotification() async {
    // FIX: Check if service is ready/safe to access
    if (_streakService.isSilentMode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isEnabled = prefs.getBool('daily_reminder') ?? false;
      if (isEnabled) {
        final int hour = prefs.getInt('reminder_hour') ?? 20;
        final int minute = prefs.getInt('reminder_minute') ?? 0;
        await NotificationService().scheduleDailyReminder(hour, minute);
      }
    } catch (e) {
      debugPrint("Error refreshing notifications: $e");
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
    try {
      await _streakService.init();
      final prefs = await SharedPreferences.getInstance();

      final savedExam = prefs.getString('selected_exam') ?? "General Exam";
      final String? savedDateString = prefs.getString('exam_date');
      DateTime? parsedDate;
      if (savedDateString != null) {
        parsedDate = DateTime.tryParse(savedDateString);
      }

      final DateTime defaultDate = DateTime(2026, 5, 20);
      final DateTime targetDate =
          parsedDate ?? AppConstants.examDates[savedExam] ?? defaultDate;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final targetStart =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final difference = targetStart.difference(todayStart).inDays;

      String todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      int rating = _streakService.dailyRatings[todayStr] ?? 0;
      bool lowEnergy = rating == 2 || rating == 3;

      if (mounted) {
        setState(() {
          _examName = savedExam;
          _daysLeft = difference < 0 ? 0 : difference;
          _rawDifference = difference;
          _isCustomExam = !AppConstants.availableExams.contains(savedExam);
          _isLowEnergyMode = lowEnergy;
          // _isLoading is handled in finally block to ensure it always turns off
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      // Optional: Set an error state text here if needed
    } finally {
      // FIX: Ensure loading spinner stops even if data loading fails
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showHonestDayDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How was today, honestly?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildRatingOption(
                "🟢 Good Focus", 1, "That's great! Keep flowing."),
            const SizedBox(height: 12),
            _buildRatingOption("🟡 Tried but struggled", 2,
                "Effort counts more than results."),
            const SizedBox(height: 12),
            _buildRatingOption(
                "🔵 Barely showed up", 3, "You're still here. That matters."),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingOption(String text, int rating, String feedback) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        await _streakService.logDailyRating(rating);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(feedback), duration: const Duration(seconds: 2)));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          // FIX: withValues replaced with withOpacity for compatibility
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(text, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _safeNavigate(String routeName) {
    try {
      Navigator.pushNamed(context, routeName).then((_) => _loadData());
    } catch (e) {
      debugPrint("Navigation Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardTextColor = isDark ? Colors.white : Colors.grey[900];
    final subtitleColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: theme.iconTheme.color),
            onPressed: () => _safeNavigate('/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "$_greeting, Student.",
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),

                    // --- MAIN DASHBOARD CARD ---
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isLowEnergyMode
                              ? (isDark
                                  ? [Colors.blueGrey.shade900, Colors.black45]
                                  : [
                                      Colors.blueGrey.shade100,
                                      Colors.blueGrey.shade50
                                    ])
                              : (isDark
                                  ? [
                                      const Color(0xFF1E1E1E),
                                      const Color(0xFF252525)
                                    ]
                                  : [Colors.white, Colors.grey.shade50]),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          if (!_isLowEnergyMode)
                            BoxShadow(
                                // FIX: withValues -> withOpacity
                                color: Colors.black
                                    .withOpacity(isDark ? 0.3 : 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // TOP ROW: Exam Name & Identity
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    // FIX: withValues -> withOpacity
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _streakService
                                            .getDisciplineIdentity()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            letterSpacing: 1.0),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // CENTER: Countdown
                            Text(
                              _rawDifference < 0 ? "Done" : '$_daysLeft',
                              style: TextStyle(
                                fontSize: _rawDifference < 0 ? 48 : 72,
                                fontWeight: FontWeight.w900,
                                color: cardTextColor,
                                height: 1.0,
                                letterSpacing: -2.0,
                              ),
                            ),

                            Text(
                              _rawDifference < 0
                                  ? 'Goal Completed'
                                  : 'Chances to show up',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),

                    if (_streakService.userWhy.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // FIX: withValues -> withOpacity
                          color: Colors.orange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("YOUR ANCHOR",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Text('"${_streakService.userWhy}"',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800])),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    if (!_streakService.hasActionToday) ...[
                      ElevatedButton.icon(
                        onPressed: _showHonestDayDialog,
                        icon: const Icon(Icons.mood, size: 18),
                        label: const Text("Log Today's Mood"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          foregroundColor: theme.textTheme.bodyLarge?.color,
                          elevation: 0,
                          side: BorderSide(
                              // FIX: withValues -> withOpacity
                              color: Colors.grey.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text('Quick Actions',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[800])),
                    ),
                    const SizedBox(height: 16),

                    _BouncingButton(
                      onTap: () => _safeNavigate('/tasks'),
                      child: _buildModernButtonContent(context,
                          icon: Icons.check_circle_outline,
                          label: 'Daily Tasks',
                          iconColor: Colors.green),
                    ),
                    const SizedBox(height: 16),
                    _BouncingButton(
                      onTap: () => _safeNavigate('/progress'),
                      child: _buildModernButtonContent(context,
                          icon: Icons.bar_chart,
                          label: 'My Progress',
                          iconColor: Colors.purple),
                    ),
                    const SizedBox(height: 16),
                    _BouncingButton(
                      onTap: () {
                        // Pomodoro usually doesn't need data reload on return
                        try {
                          Navigator.pushNamed(context, '/pomodoro');
                        } catch (e) {
                          debugPrint("$e");
                        }
                      },
                      child: _buildModernButtonContent(context,
                          icon: Icons.timer_outlined,
                          label: 'Pomodoro Timer',
                          iconColor: Colors.deepPurpleAccent),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernButtonContent(BuildContext context,
      {required IconData icon,
      required String label,
      required Color iconColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              // FIX: withValues -> withOpacity
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
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
                  // FIX: withValues -> withOpacity
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 20),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

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
      onTapDown: (_) {
        if (mounted) _controller.forward();
      },
      // FIX: Move action to onTap for proper gesture handling
      onTap: () {
        widget.onTap();
      },
      // FIX: Use onTapUp/Cancel only for animation reset
      onTapUp: (_) {
        if (mounted) _controller.reverse();
      },
      onTapCancel: () {
        if (mounted) _controller.reverse();
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
