import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<Task> _tasks = [];
  final TextEditingController _taskController = TextEditingController();
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadAndCheckDailyProgress();
  }

  // 1. IMPROVED INIT LOGIC
  Future<void> _loadAndCheckDailyProgress() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Tasks
    final String? tasksString = prefs.getString('tasks_data');
    if (tasksString != null) {
      final List<dynamic> decodedList = jsonDecode(tasksString);
      _tasks = decodedList.map((item) => Task.fromMap(item)).toList();
    }

    // Load Streak Data
    _currentStreak = prefs.getInt('current_streak') ?? 0;
    final String? lastCompletionDate = prefs.getString('last_completion_date');
    final String? lastOpenDate = prefs.getString('last_open_date');

    final DateTime now = DateTime.now();
    final String todayKey =
        "${now.year}-${now.month}-${now.day}"; // Normalize to Day

    // CHECK FOR MISSED DAY (Reset Logic)
    if (lastOpenDate != null && lastOpenDate != todayKey) {
      // It's a new day. Did we complete yesterday?
      final DateTime yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      final String yesterdayKey =
          "${yesterday.year}-${yesterday.month}-${yesterday.day}";

      // If the last completion was NOT yesterday, reset streak to 0.
      if (lastCompletionDate != yesterdayKey) {
        _currentStreak = 0;
        await prefs.setInt('current_streak', 0);
      }

      // Reset checkmarks for the new day
      for (final t in _tasks) {
        t.isCompleted = false;
      }
      await _saveTasks();
    }

    // Save "Today" as the last opened date
    await prefs.setString('last_open_date', todayKey);

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> mapList =
        _tasks.map((t) => t.toMap()).toList();
    await prefs.setString('tasks_data', jsonEncode(mapList));
  }

  void _addTask() {
    if (_taskController.text.trim().isNotEmpty) {
      setState(() {
        _tasks.add(Task(title: _taskController.text.trim()));
      });
      _saveTasks();
      _taskController.clear();
      Navigator.of(context).pop();
    }
  }

  // 2. NEW COMPLETION CHECKER
  Future<void> _checkDailyCompletion() async {
    // 1. Safety Checks
    if (_tasks.isEmpty) return;

    // 2. Are ALL tasks done?
    final bool allDone = _tasks.every((t) => t.isCompleted);

    if (allDone) {
      final prefs = await SharedPreferences.getInstance();
      final String? lastCompletionDate =
          prefs.getString('last_completion_date');

      final DateTime now = DateTime.now();
      final String todayKey = "${now.year}-${now.month}-${now.day}";

      // 3. Prevent Double Counting
      if (lastCompletionDate != todayKey) {
        // INCREMENT STREAK!
        final int newStreak = _currentStreak + 1;
        await prefs.setInt('current_streak', newStreak);
        await prefs.setString('last_completion_date', todayKey);

        if (!mounted) return;
        setState(() {
          _currentStreak = newStreak;
        });

        // Optional: Celebration
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 Daily Goal Complete! Streak Increased!"),
          ),
        );
      }
    }
  }

  // 3. UPDATED TOGGLE METHOD
  void _toggleTask(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
    });
    _saveTasks();

    // TRIGGER THE CHECK IMMEDIATELY
    _checkDailyCompletion();
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  void _showAddTaskDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        // Fix: Use Theme dialog background
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            title: const Text('Add New Task'),
            content: SingleChildScrollView(
              child: TextField(
                controller: _taskController,
                decoration:
                    const InputDecoration(hintText: 'e.g., Solve 20 MCQs'),
                autofocus: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _taskController.clear();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(onPressed: _addTask, child: const Text('Add')),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Daily Tasks',
          style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: theme.iconTheme,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  // FIX: Use opacity for dark mode compatibility
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text("🔥 $_currentStreak",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange)),
              ),
            ),
          )
        ],
      ),
      body: _tasks.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 80),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                return _buildTaskCard(_tasks[index], index, theme, isDark);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Task", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              // FIX: Use opacity instead of .shade50
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_add,
                size: 80, color: Colors.blue.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            'No tasks for today',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the "+ New Task" button\nto start your daily goals!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, int index, ThemeData theme, bool isDark) {
    // FIX: Dynamic colors based on state and theme
    final cardColor = task.isCompleted
        ? (isDark ? Colors.grey[900] : Colors.grey[100])
        : theme.cardColor;

    final textColor =
        task.isCompleted ? Colors.grey : theme.textTheme.bodyLarge?.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                isDark ? 0.3 : 0.05), // Darker shadow for dark mode
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: task.isCompleted,
            onChanged: (value) => _toggleTask(index),
            activeColor: Colors.blue,
            // Ensure checkbox border is visible in dark mode
            side: BorderSide(
                color: isDark ? Colors.grey : Colors.black54, width: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        title: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: textColor,
            fontFamily: 'Poppins', // Explicitly keep font consistent
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            decorationColor: Colors.grey,
            decorationThickness: 2.0,
          ),
          child: Text(task.title),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
          onPressed: () => _deleteTask(index),
        ),
      ),
    );
  }
}
