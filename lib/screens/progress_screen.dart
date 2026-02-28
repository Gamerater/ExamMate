import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/streak_service.dart';
import '../services/pomodoro_service.dart';
import '../utils/subject_color_helper.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _streakCount = 0;
  int _bestStreak = 0;
  bool _isStreakActive = false;
  int _completedTasks = 0;
  int _totalTasks = 0;
  int _focusMinutes = 0;
  bool _isLoading = true;

  Map<String, int> _subjectStats = {};

  final StreakService _streakService = StreakService();
  final PomodoroService _pomoService = PomodoroService();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await _streakService.init();
      final streak = _streakService.currentStreak;
      final best = _streakService.bestStreak;
      final isActive = _streakService.hasActionToday;

      final String? tasksString = prefs.getString('tasks_data');
      int completed = 0;
      int total = 0;
      int totalSessions = 0;

      if (tasksString != null) {
        final List<dynamic> decoded = jsonDecode(tasksString);
        final allTasks = decoded.map((e) => Task.fromMap(e)).toList();
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        final todaysTasks = allTasks.where((t) {
          final tDate = DateTime(t.date.year, t.date.month, t.date.day);
          return tDate.isAtSameMomentAs(todayStart) ||
              tDate.isAfter(todayStart);
        }).toList();

        total = todaysTasks.length;
        completed = todaysTasks
            .where((t) => t.isCompleted || t.status == TaskStatus.completed)
            .length;
        for (var t in todaysTasks) {
          totalSessions += t.sessionsCompleted;
        }
      }

      int workDuration = prefs.getInt('pomo_work_minutes') ?? 25;
      int minutes = totalSessions * workDuration;

      final stats = await _pomoService.getSubjectFocusStats(days: 7);

      if (mounted) {
        setState(() {
          _streakCount = streak;
          _bestStreak = best;
          _isStreakActive = isActive;
          _completedTasks = completed;
          _totalTasks = total;
          _focusMinutes = minutes;
          _subjectStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DYNAMIC TEXT HELPERS ---

  String _getStreakMessage() {
    if (_streakCount == 0) return "Start your momentum.";
    if (_streakCount == 1) return "Momentum starts small.";
    if (_streakCount >= 2 && _streakCount <= 6) return "Keep showing up.";
    return "Consistency is forming.";
  }

  String _getEffortHeader() {
    if (_totalTasks == 0) return "Let's begin today.";
    if (_completedTasks == _totalTasks && _totalTasks > 0)
      return "You showed up today.";
    int remaining = _totalTasks - _completedTasks;
    return "$remaining task(s) remaining.";
  }

  String _getStatusText() {
    if (_completedTasks > 0 || _focusMinutes > 0 || _isStreakActive) {
      return "🟢 Momentum intact";
    }
    return "🟡 Momentum at risk";
  }

  int _getActiveDaysThisWeek() {
    int count = 0;
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      DateTime d = now.subtract(Duration(days: i));
      String key =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      if ((_streakService.history[key] ?? 0) > 0) count++;
    }
    return count;
  }

  // --- HEATMAP INTERACTION ---

  Future<void> _onDayTapped(DateTime date, int tasksDone) async {
    // Quickly fetch focus minutes for this specific day
    int focusMins = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('pomodoro_sessions_data');
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        for (var item in decoded) {
          DateTime ts = DateTime.parse(item['timestamp']);
          if (ts.year == date.year &&
              ts.month == date.month &&
              ts.day == date.day) {
            focusMins += (item['durationMinutes'] as int? ?? 0);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching day stats: $e");
    }

    if (!mounted) return;

    final String dateStr =
        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildModalStatRow(Icons.check_circle_outline, Colors.blue,
                  "Tasks Completed", "$tasksDone tasks"),
              const SizedBox(height: 12),
              _buildModalStatRow(Icons.timer_outlined, Colors.purple,
                  "Focus Time", "$focusMins minutes"),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    foregroundColor:
                        Theme.of(context).textTheme.bodyLarge?.color,
                    elevation: 0,
                  ),
                  child: const Text("Close"),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalStatRow(
      IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStreakCard(theme, isDark),
                  const SizedBox(height: 24),

                  _buildProgressCard(theme, isDark, progress),
                  const SizedBox(height: 24),

                  _buildExpandedHeatmap(isDark),

                  if (_subjectStats.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text("Subject Focus (Last 7 Days)",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600])),
                    const SizedBox(height: 12),
                    _buildSubjectStatsRow(isDark),
                  ],

                  // INTENTIONAL QUOTE
                  const SizedBox(height: 30),
                  Center(
                    child: Text(
                      "Progress compounds quietly.",
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
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

  Widget _buildSubjectStatsRow(bool isDark) {
    List<MapEntry<String, int>> sortedStats = _subjectStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedStats.length,
        itemBuilder: (context, index) {
          final stat = sortedStats[index];
          Color color = SubjectColorHelper.getColor(stat.key);

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200),
                right: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200),
                bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200),
                left: BorderSide(color: color, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(stat.key,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("${stat.value} mins",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UPGRADED STREAK CARD ---
  Widget _buildStreakCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.deepOrange.shade900, Colors.deepOrange.shade700]
              : [Colors.orange.shade100, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            "$_streakCount",
            style: TextStyle(
              fontSize: 64,
              height: 1.0,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.deepOrange[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Day Streak",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.deepOrange[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getStreakMessage(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.orange[100] : Colors.deepOrange[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Longest streak: $_bestStreak days",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.deepOrange[400],
            ),
          ),
        ],
      ),
    );
  }

  // --- UPGRADED EFFORT CARD ---
  Widget _buildProgressCard(ThemeData theme, bool isDark, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_getEffortHeader(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text("${(progress * 100).toInt()}%",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 24),

          // Meaningful Feedback Rows
          _buildFeedbackRow(
            icon: Icons.check_circle_outline,
            color: Colors.blue,
            text: "$_completedTasks of $_totalTasks tasks completed",
          ),
          const SizedBox(height: 12),
          _buildFeedbackRow(
            icon: Icons.timer_outlined,
            color: Colors.purple,
            text: _focusMinutes == 0
                ? "No focus sessions yet"
                : "$_focusMinutes minutes focused",
          ),
          const SizedBox(height: 12),
          Text(
            _getStatusText(),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackRow(
      {required IconData icon, required Color color, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // --- UPGRADED GITHUB-STYLE HEATMAP ---
  Widget _buildExpandedHeatmap(bool isDark) {
    const int weeksToShow = 10; // Slightly more weeks for a denser look
    const int daysToShow = weeksToShow * 7;
    final int activeDays = _getActiveDaysThisWeek();

    final now = DateTime.now();
    final List<DateTime> dates = List.generate(daysToShow, (index) {
      return now.subtract(Duration(days: (daysToShow - 1) - index));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Consistency Graph",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600])),
            Text("This week: $activeDays/7",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  double availableWidth = constraints.maxWidth;
                  // Compact sizing
                  double cellSize =
                      (availableWidth - (weeksToShow * 4)) / weeksToShow;
                  if (cellSize > 16)
                    cellSize = 16; // Max size to keep it looking like a grid

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(weeksToShow, (weekIndex) {
                      return Column(
                        children: List.generate(7, (dayIndex) {
                          final int dateIndex = (weekIndex * 7) + dayIndex;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildHeatmapCell(
                                dates[dateIndex], isDark, cellSize),
                          );
                        }),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Last 70 Days",
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),

                  // Clean Legend
                  Row(
                    children: [
                      Text("Less ",
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500])),
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[200],
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 2),
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 2),
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(2))),
                      Text(" More",
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapCell(DateTime date, bool isDark, double size) {
    final String dateKey =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final int effort = _streakService.history[dateKey] ?? 0;

    Color color;
    if (effort == 0) {
      color = isDark ? Colors.white10 : Colors.grey[200]!;
    } else if (effort <= 2) {
      color = Colors.green.withOpacity(0.4);
    } else if (effort <= 5) {
      color = Colors.green.withOpacity(0.7);
    } else {
      color = Colors.green;
    }

    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return GestureDetector(
      onTap: () => _onDayTapped(date, effort),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: isToday
              ? Border.all(
                  color: Colors.blueAccent.withOpacity(0.8), width: 1.5)
              : null,
        ),
      ),
    );
  }
}
