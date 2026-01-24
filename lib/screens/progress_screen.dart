import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _streak = 0;
  double _progressValue = 0.0;
  int _completedCount = 0;
  int _totalCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
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
    double progress = total == 0 ? 0.0 : (completed / total);

    if (mounted) {
      setState(() {
        _streak = streak;
        _totalCount = total;
        _completedCount = completed;
        _progressValue = progress;
        _isLoading = false;
      });
    }
  }

  // --- COLOR TRANSITION LOGIC ---
  // 0% - 50%: Red to Yellow
  // 50% - 100%: Yellow to Green
  Color _getColorForProgress(double value) {
    if (value < 0.5) {
      // Normalize value to 0.0 - 1.0 range for the first half
      return Color.lerp(Colors.redAccent, Colors.amber, value * 2)!;
    } else {
      // Normalize value to 0.0 - 1.0 range for the second half
      return Color.lerp(Colors.amber, Colors.green, (value - 0.5) * 2)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Progress',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Streak Card (Unchanged)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.deepOrange,
                              size: 56,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '$_streak Day Streak!',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _streak > 0
                                  ? 'You are on fire! Keep it up.'
                                  : 'Complete all tasks to start a streak.',
                              style: TextStyle(color: Colors.grey[700]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Progress Section
                    const Text(
                      'Daily Goal Completion',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),

                    // --- ANIMATED PROGRESS BAR ---
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: _progressValue),
                        duration: const Duration(
                            seconds: 1, milliseconds: 200), // 1.2 seconds
                        curve:
                            Curves.easeOutCubic, // Smooth slowdown at the end
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 25,
                            backgroundColor: Colors.grey[300],
                            // Dynamic color based on current animated value
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getColorForProgress(value),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Stats Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_completedCount / $_totalCount Tasks',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold),
                        ),
                        // Animated Percentage Text
                        TweenAnimationBuilder<int>(
                          tween: IntTween(
                              begin: 0, end: (_progressValue * 100).toInt()),
                          duration:
                              const Duration(seconds: 1, milliseconds: 200),
                          builder: (context, value, _) {
                            return Text(
                              '$value%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Quote (Unchanged)
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child:
                                const Icon(Icons.lightbulb, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              '"Success is the sum of small efforts, repeated day in and day out."',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.black87,
                                height: 1.4,
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
