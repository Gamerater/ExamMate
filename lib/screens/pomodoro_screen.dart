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

      // Load Subject Stats
      final stats = await _pomoService.getSubjectFocusStats(days: 7);

      if (mounted) {
        setState(() {
          _streakCount = streak;
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
                  Text("Today's Effort",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600])),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 40),
                  Center(
                      child: Text("Progress compounds quietly.",
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5))),
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

  Widget _buildStreakCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.deepOrange.shade900, Colors.deepOrange.shade700]
              : [Colors.orange.shade100, Colors.orange.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department,
                  size: 32, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Text("$_streakCount Day Streak",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.deepOrange[800])),
            ],
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
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200)),
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
          LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200]),
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
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildExpandedHeatmap(bool isDark) {
    const int weeksToShow = 7;
    const int daysToShow = weeksToShow * 7;

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
            Row(
              children: [
                Text("Less",
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                const SizedBox(width: 4),
                Container(
                    width: 8, height: 8, color: Colors.green.withOpacity(0.3)),
                const SizedBox(width: 2),
                Container(width: 8, height: 8, color: Colors.green),
                const SizedBox(width: 4),
                Text("More",
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            )
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
                  double cellSize =
                      (availableWidth - (weeksToShow * 4)) / weeksToShow;
                  if (cellSize > 24) cellSize = 24;

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
                  Text("Last 50 Days",
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  Text("Today",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent)),
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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: isToday ? Border.all(color: Colors.blueAccent, width: 2) : null,
      ),
    );
  }
}
