import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

// 1. Add SingleTickerProviderStateMixin for the AnimationController
class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  int _streak = 0;
  int _completedCount = 0;
  int _totalCount = 0;
  bool _isLoading = true;

  // 2. Explicit Animation Controller and Tween
  late AnimationController _controller;
  late Animation<double> _animation;
  double _targetProgress = 0.0;

  @override
  void initState() {
    super.initState();

    // Configure the controller for a "Calm" feel
    // Duration is longer (1.5s) to make it feel relaxed, not rushed.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Initialize with 0. We will update the 'end' value when data loads.
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
    // Calculate new target
    double newProgress = total == 0 ? 0.0 : (completed / total);

    if (mounted) {
      setState(() {
        _streak = streak;
        _totalCount = total;
        _completedCount = completed;
        _targetProgress = newProgress;
        _isLoading = false;

        // 3. Smooth Animation Logic
        // We create a new Tween starting from the CURRENT value (wherever the bar is now)
        // to the NEW target. This prevents jumping if the value updates mid-animation.
        _animation =
            Tween<double>(begin: _animation.value, end: _targetProgress)
                .animate(CurvedAnimation(
          parent: _controller,
          // easeOutQuart is a very strong "slow down" curve, feeling premium/calm
          curve: Curves.easeOutQuart,
        ));

        // Reset and start the animation
        _controller.forward(from: 0.0);
      });
    }
  }

  Color _getColorForProgress(double value) {
    if (value < 0.5) {
      return Color.lerp(Colors.redAccent, Colors.amber, value * 2)!;
    } else {
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
                    // Streak Card
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

                    const Text(
                      'Daily Goal Completion',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),

                    // 4. AnimatedBuilder handles the smooth rebuilds
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
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getColorForProgress(_animation.value),
                                ),
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Motivational Quote
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
