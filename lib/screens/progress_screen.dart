import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/streak_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  // Stats State
  int _streakCount = 0;
  bool _isStreakActive = false;
  int _completedTasks = 0;
  int _totalTasks = 0;
  int _focusMinutes = 0;
  bool _isLoading = true;

  // Service
  final StreakService _streakService = StreakService();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Streak Data (Service handles history loading internally)
      await _streakService.init();
      final streak = _streakService.currentStreak;
      final isActive = _streakService.hasActionToday;

      // 2. Load Task Data (For counts & focus calculation)
      final String? tasksString = prefs.getString('tasks_data');
      int completed = 0;
      int total = 0;
      int totalSessions = 0;

      if (tasksString != null) {
        final List<dynamic> decoded = jsonDecode(tasksString);
        final allTasks = decoded.map((e) => Task.fromMap(e)).toList();

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        // Filter for Today only
        final todaysTasks = allTasks.where((t) {
          final tDate = DateTime(t.date.year, t.date.month, t.date.day);
          return tDate.isAtSameMomentAs(todayStart) ||
              tDate.isAfter(todayStart);
        }).toList();

        total = todaysTasks.length;
        completed = todaysTasks.where((t) => t.isCompleted).length;

        // Calculate total focus sessions for today
        for (var t in todaysTasks) {
          totalSessions += t.sessionsCompleted;
        }
      }

      // 3. Calculate Focus Minutes
      int workDuration = prefs.getInt('pomo_work_minutes') ?? 25;
      int minutes = totalSessions * workDuration;

      if (mounted) {
        setState(() {
          _streakCount = streak;
          _isStreakActive = isActive;
          _completedTasks = completed;
          _totalTasks = total;
          _focusMinutes = minutes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading progress: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPER: Get Identity Label ---
  String _getIdentityLabel(int streak) {
    if (streak == 0) return "Fresh Start";
    if (streak <= 3) return "Getting Started";
    if (streak <= 7) return "Momentum Builder";
    if (streak <= 14) return "Consistent Learner";
    if (streak <= 30) return "Disciplined Mind";
    return "Exam Warrior";
  }

  // --- HELPER: Get Context-Aware Quote ---
  String _getQuote() {
    if (_isStreakActive) {
      return "You showed up today. That's the victory.";
    } else if (_streakCount > 0) {
      return "Keep the chain alive. One small act is enough.";
    } else {
      return "The best time to start is now. No pressure.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate progress (prevent div by zero)
    double progress = _totalTasks == 0 ? 0.0 : _completedTasks / _totalTasks;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Your Growth",
            style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. STREAK IDENTITY CARD
                  _buildStreakCard(theme, isDark),

                  const SizedBox(height: 24),

                  // 2. DAILY GOAL PILLARS
                  Text("Today's Effort",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  _buildProgressCard(theme, isDark, progress),

                  const SizedBox(height: 24),

                  // 3. CONSISTENCY HEATMAP (UPDATED)
                  _buildConsistencyHeatmap(isDark),

                  const SizedBox(height: 24),

                  // 4. CONTEXT AWARE QUOTE
                  _buildQuoteCard(theme, isDark),

                  const SizedBox(height: 40),

                  // 5. CLOSURE FOOTER
                  Center(
                    child: Text(
                      "Progress compounds quietly.",
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildStreakCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.deepOrange.shade900, Colors.deepOrange.shade700]
              : [Colors.orange.shade100, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department,
                  size: 32, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Text(
                "$_streakCount Day Streak",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.deepOrange[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getIdentityLabel(_streakCount).toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? Colors.orange[100] : Colors.deepOrange[900],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Consistency beats intensity.",
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.orange[200] : Colors.deepOrange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme, bool isDark, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Completion",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text("${(progress * 100).toInt()}%",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                  progress == 1.0 ? Colors.green : Colors.blue),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatPillar("Tasks", "$_completedTasks/$_totalTasks",
                  Icons.check_circle_outline, Colors.blue),
              _buildStatPillar("Focus", "${_focusMinutes}m",
                  Icons.timer_outlined, Colors.purple),
              _buildStatPillar("Status", _isStreakActive ? "Active" : "Paused",
                  Icons.bolt, _isStreakActive ? Colors.orange : Colors.grey),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatPillar(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  // --- HEATMAP IMPLEMENTATION ---
  Widget _buildConsistencyHeatmap(bool isDark) {
    // Generate dates: Today -> 34 days ago (Total 35 days = 5 weeks)
    final now = DateTime.now();
    final List<DateTime> dates = List.generate(35, (index) {
      return now.subtract(Duration(days: (34 - index))); // Oldest first
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Consistency Over Time",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600])),
            Text("Last 30 Days",
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: GridView.builder(
            shrinkWrap: true, // Takes only needed space
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 35,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, // 7 days a week
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              return _buildHeatmapCell(dates[index], isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapCell(DateTime date, bool isDark) {
    // 1. Get formatted date key
    final String dateKey =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // 2. Get effort count from history
    final int effort = _streakService.history[dateKey] ?? 0;

    // 3. Determine Color Intensity
    Color color;
    if (effort == 0) {
      color = isDark ? Colors.white10 : Colors.grey[300]!; // Empty
    } else if (effort <= 2) {
      color = Colors.green.withValues(alpha: 0.4); // Light
    } else if (effort <= 5) {
      color = Colors.green.withValues(alpha: 0.7); // Medium
    } else {
      color = Colors.green; // Strong
    }

    // 4. Highlight Today
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: isToday ? Border.all(color: Colors.blueAccent, width: 2) : null,
      ),
    );
  }

  Widget _buildQuoteCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blueGrey.withValues(alpha: 0.2)
            : Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? Colors.blueGrey.withValues(alpha: 0.3)
                : Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote_rounded,
              color: isDark ? Colors.blue[200] : Colors.blue[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getQuote(),
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.blue[100] : Colors.blue[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
