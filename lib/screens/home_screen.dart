import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../utils/constants.dart';
import '../utils/subject_color_helper.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';
import '../services/task_service.dart';

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
  final TaskService _taskService = TaskService();
  
  bool _isLoading = true;
  bool _isLowEnergyMode = false;
  int _todayMoodRating = 0;
  DateTime? _targetDateObj;
  
  // Smart Task State
  Task? _nextTask;

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
      bool didReset = await _taskService.performDailyResetIfNeeded();
      if (didReset && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("New day started. Your tasks are ready."),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await _streakService.init();
      await _loadNextTask(); // Load the smart suggestion

      final prefs = await SharedPreferences.getInstance();

      final savedExam = prefs.getString('selected_exam') ?? "General Exam";
      final String? savedDateString = prefs.getString('exam_date');
      DateTime? parsedDate;
      if (savedDateString != null) {
        parsedDate = DateTime.tryParse(savedDateString);
      }

      final DateTime defaultDate = DateTime(2026, 5, 20);
      final DateTime targetDate = parsedDate ?? AppConstants.examDates[savedExam] ?? defaultDate;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final targetStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final difference = targetStart.difference(todayStart).inDays;

      String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      int rating = _streakService.dailyRatings[todayStr] ?? 0;
      bool lowEnergy = rating == 2 || rating == 3;

      if (mounted) {
        setState(() {
          _examName = savedExam;
          _targetDateObj = targetDate;
          _daysLeft = difference < 0 ? 0 : difference;
          _rawDifference = difference;
          _isCustomExam = !AppConstants.availableExams.contains(savedExam);
          _isLowEnergyMode = lowEnergy;
          _todayMoodRating = rating;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- SMART NEXT TASK LOGIC ---
  Future<void> _loadNextTask() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? tasksString = prefs.getString('tasks_data');
      
      if (tasksString == null || tasksString.isEmpty) {
        if (mounted) setState(() => _nextTask = null);
        return;
      }

      final List<dynamic> decoded = jsonDecode(tasksString);
      final allTasks = decoded.map((e) => Task.fromMap(e)).toList();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      List<Task> pending = allTasks.where((t) {
        if (t.isCompleted || t.status == TaskStatus.completed) return false;
        if (t.isTemporary && t.deadline != null && t.deadline!.isBefore(now)) return false;
        
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        if (tDate.isAfter(todayStart)) return false; // Ignore future tasks
        
        return true;
      }).toList();

      if (pending.isEmpty) {
        if (mounted) setState(() => _nextTask = null);
        return;
      }

      // Sort by Priority (Effort) descending, then Earliest Created
      pending.sort((a, b) {
        int effortCompare = b.effort.index.compareTo(a.effort.index);
        if (effortCompare != 0) return effortCompare;
        return a.createdAt.compareTo(b.createdAt);
      });

      if (mounted) {
        setState(() => _nextTask = pending.first);
      }
    } catch (e) {
      debugPrint("Error finding next task: $e");
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
            const Text("How was today, honestly?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildRatingOption("🟢 Good Focus", 1, "That's great! Keep flowing."),
            const SizedBox(height: 12),
            _buildRatingOption("🟡 Tried but struggled", 2, "Effort counts more than results."),
            const SizedBox(height: 12),
            _buildRatingOption("🔵 Barely showed up", 3, "You're still here. That matters."),
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(feedback), duration: const Duration(seconds: 2)));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
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

  void _showJourneyDetails() {
    final int totalDays = _daysLeft + _streakService.currentStreak;
    final double progress = totalDays > 0 ? (_streakService.currentStreak / totalDays) : 0.0;

    final String dateStr = _targetDateObj != null
        ? "${_targetDateObj!.day.toString().padLeft(2, '0')}/${_targetDateObj!.month.toString().padLeft(2, '0')}/${_targetDateObj!.year}"
        : "N/A";

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Journey Overview", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildJourneyRow("Target Goal", _examName),
            const Divider(height: 24),
            _buildJourneyRow("Target Date", dateStr),
            const Divider(height: 24),
            _buildJourneyRow("Days Remaining", "$_daysLeft days"),
            const Divider(height: 24),
            _buildJourneyRow("Estimated Journey", "$totalDays days"),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Progress", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                Text("${(progress * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  String _getMoodString() {
    if (_todayMoodRating == 1) return "Today's Mood: 🟢 Focused";
    if (_todayMoodRating == 2) return "Today's Mood: 🟡 Struggled";
    if (_todayMoodRating == 3) return "Today's Mood: 🔵 Low Energy";
    return "Tap to log today's mood";
  }

  void _safeNavigate(String routeName) {
    try {
      Navigator.pushNamed(context, routeName).then((_) => _loadData());
    } catch (e) {
      debugPrint("Navigation Error: $e");
    }
  }

  // --- FOCUS NEXT WIDGET ---
  Widget _buildFocusNextCard(ThemeData theme, bool isDark) {
    if (_nextTask == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text("No tasks pending today.", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _safeNavigate('/tasks'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Add Task"),
            )
          ],
        ),
      );
    }

    Color effortColor = _nextTask!.effort == TaskEffort.quick ? Colors.amber : _nextTask!.effort == TaskEffort.medium ? Colors.blue : Colors.deepPurple;
    String effortText = _nextTask!.effort == TaskEffort.quick ? "Quick" : _nextTask!.effort == TaskEffort.medium ? "Medium" : "Deep";
    Color subjectColor = SubjectColorHelper.getColor(_nextTask!.subject);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.grey.shade200),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nextTask!.title, 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.bodyLarge?.color),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_nextTask!.subject != null && _nextTask!.subject!.isNotEmpty)
                      _buildMiniChip(text: _nextTask!.subject!, icon: Icons.bookmark, color: subjectColor, isDark: isDark, isFilled: true),
                    _buildMiniChip(text: effortText, icon: Icons.bolt, color: effortColor, isDark: isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              // Pass the task as an argument to auto-link
              Navigator.pushNamed(context, '/pomodoro', arguments: _nextTask).then((_) => _loadData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            ),
            child: const Text("Start Focus", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          )
        ],
      ),
    );
  }

  Widget _buildMiniChip({required String text, required IconData icon, required Color color, required bool isDark, bool isFilled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFilled ? color.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isFilled ? color.withOpacity(0.3) : (isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isFilled ? (isDark ? color.withOpacity(0.9) : color.withOpacity(1.0)) : Colors.grey.shade500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardTextColor = isDark ? Colors.white : Colors.grey[900];
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
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
                      style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),

                    if (_streakService.userWhy.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.anchor, size: 16, color: Colors.orange[800]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '"${_streakService.userWhy}"',
                                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],

                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isLowEnergyMode
                              ? (isDark
                                  ? [Colors.blueGrey.shade900, Colors.blueGrey.shade800]
                                  : [Colors.blueGrey.shade100, Colors.blueGrey.shade50])
                              : (isDark
                                  ? [const Color(0xFF1E1E1E), const Color(0xFF252525)]
                                  : [Colors.white, Colors.grey.shade50]),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          if (!_isLowEnergyMode)
                            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showJourneyDetails,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _streakService.getDisciplineIdentity().toUpperCase(),
                                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0),
                                      ),
                                    ),
                                    Icon(Icons.insights, size: 18, color: Colors.grey.withOpacity(0.5)),
                                  ],
                                ),
                                const SizedBox(height: 24),
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
                                const SizedBox(height: 8),
                                Text(
                                  _rawDifference < 0 ? 'Goal Completed' : 'Days Until $_examName',
                                  style: TextStyle(fontSize: 18, color: cardTextColor, fontWeight: FontWeight.w700),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Show up every day.',
                                  style: TextStyle(fontSize: 14, color: subtitleColor, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- NEW: FOCUS NEXT SECTION ---
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text('Focus Next', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                    ),
                    const SizedBox(height: 16),
                    _buildFocusNextCard(theme, isDark),

                    const SizedBox(height: 32),

                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                    ),
                    const SizedBox(height: 16),

                    _BouncingButton(
                      onTap: () => _safeNavigate('/tasks'),
                      child: _buildModernButtonContent(context, icon: Icons.check_circle_outline, label: 'Daily Tasks', iconColor: Colors.green),
                    ),
                    const SizedBox(height: 12),
                    _BouncingButton(
                      onTap: () => _safeNavigate('/progress'),
                      child: _buildModernButtonContent(context, icon: Icons.bar_chart, label: 'My Progress', iconColor: Colors.purple),
                    ),
                    const SizedBox(height: 12),
                    _BouncingButton(
                      onTap: () => _safeNavigate('/pomodoro'),
                      child: _buildModernButtonContent(context, icon: Icons.timer_outlined, label: 'Pomodoro Timer', iconColor: Colors.deepPurpleAccent),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: InkWell(
                        onTap: _showHonestDayDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getMoodString(),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit, size: 12, color: Colors.grey[500]),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernButtonContent(BuildContext context, {required IconData icon, required String label, required Color iconColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: isDark ? Border.all(color: Colors.white10) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 20),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
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

class _BouncingButtonState extends State<_BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { if (mounted) _controller.forward(); },
      onTap: () { widget.onTap(); },
      onTapUp: (_) { if (mounted) _controller.reverse(); },
      onTapCancel: () { if (mounted) _controller.reverse(); },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}