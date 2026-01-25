import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
// 1. Import the new quotes file
import '../utils/motivation_quotes.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  int _streak = 0;
  int _completedCount = 0;
  int _totalCount = 0;
  bool _isLoading = true;

  // 2. Variable to store the daily quote
  String _dailyQuote = "Loading motivation...";

  late AnimationController _controller;
  late Animation<double> _animation;
  double _targetProgress = 0.0;

  @override
  void initState() {
    super.initState();

    // FIX 2: Initialize Quote Synchronously (No "Loading..." flash)
    // We fetch a quote immediately. It will update correctly if streak changes later.
    _dailyQuote = MotivationQuotes.getQuote(0);

    _controller = AnimationController(
      vsync: this,
      // FIX 3: Dynamic Animation Setup (default duration; updated on load)
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _loadStatistics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final int streak = prefs.getInt('current_streak') ?? 0;
    final String? tasksString = prefs.getString('tasks_data');
    List<Task> tasks = [];

    if (tasksString != null) {
      final List<dynamic> decodedList = jsonDecode(tasksString);
      tasks = decodedList.map((item) => Task.fromMap(item)).toList();
    }

    int total = tasks.length;
    int completed = tasks.where((t) => t.isCompleted).length;
    double newProgress = total == 0 ? 0.0 : (completed / total);

    // 3. Get the quote based on the loaded streak
    final String quote = MotivationQuotes.getQuote(streak);

    if (mounted) {
      setState(() {
        _streak = streak;
        _totalCount = total;
        _completedCount = completed;
        _targetProgress = newProgress;
        _dailyQuote = quote; // Store it
        _isLoading = false;

        // FIX 3 (Continued): Dynamic Duration based on travel distance
        // Logic: Small progress change = fast animation. Large change = slower animation.
        final double travel = (_targetProgress - _animation.value).abs();
        final int durationMs = (travel * 1500).toInt().clamp(800, 2000);
        _controller.duration = Duration(milliseconds: durationMs);

        _animation =
            Tween<double>(begin: _animation.value, end: _targetProgress)
                .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
        );
        _controller.forward(from: 0.0);
      });
    }
  }

  Color _getColorForProgress(double value) {
    if (value < 0.5) {
      return Color.lerp(Colors.red[400], Colors.amber[400], value * 2)!;
    } else {
      return Color.lerp(
          Colors.amber[400], Colors.green[400], (value - 0.5) * 2)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Progress',
          style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Streak Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.orange.withOpacity(isDark ? 0.05 : 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: Colors.deepOrange, size: 56),
                            const SizedBox(height: 10),
                            Text(
                              '$_streak Day Streak!',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _streak > 0
                                  ? 'You are on fire! Keep it up.'
                                  : 'Complete all tasks to start a streak.',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      'Daily Goal Completion',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color),
                    ),
                    const SizedBox(height: 15),

                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _animation.value,
                                minHeight: 25,
                                backgroundColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    _getColorForProgress(_animation.value)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$_completedCount / $_totalCount Tasks',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${(_animation.value * 100).toInt()}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: theme.textTheme.bodyLarge?.color),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // 4. Motivation Card with Dynamic Quote
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child:
                                const Icon(Icons.lightbulb, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _dailyQuote, // Display the stored quote
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: theme.textTheme.bodyLarge?.color,
                                height: 1.4,
                                fontSize: 15, // Slightly larger for readability
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
