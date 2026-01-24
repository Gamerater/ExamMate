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

  // Variable to keep track of current streak (for display only)
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadAndCheckDailyProgress();
  }

  // --- STREAK & RESET LOGIC ---

  Future<void> _loadAndCheckDailyProgress() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load stored Tasks
    final String? tasksString = prefs.getString('tasks_data');
    if (tasksString != null) {
      final List<dynamic> decodedList = jsonDecode(tasksString);
      _tasks = decodedList.map((item) => Task.fromMap(item)).toList();
    }

    // 2. Load stored Streak
    _currentStreak = prefs.getInt('current_streak') ?? 0;

    // 3. Date Logic
    final String? lastOpenDate = prefs.getString('last_open_date');
    final String today = DateTime.now().toIso8601String().split('T')[0];
    // Calculate yesterday's date string
    final String yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];

    bool needsSave = false;

    // If the app was NOT opened today (It's a New Day)
    if (lastOpenDate != today) {
      // LOGIC: Did we maintain the streak?
      if (lastOpenDate == yesterday) {
        // User opened app yesterday. Did they finish all tasks?
        // We ensure there was at least 1 task to avoid "free" streaks.
        bool allDone = _tasks.isNotEmpty && _tasks.every((t) => t.isCompleted);

        if (allDone) {
          _currentStreak++; // Success!
          _showStreakMessage("🔥 Streak Increased! Day $_currentStreak");
        } else {
          _currentStreak = 0; // Missed a task
          _showStreakMessage("Streak Reset. Don't give up!");
        }
      } else {
        // User skipped a day (or first install)
        if (lastOpenDate != null) {
          _currentStreak = 0; // Reset if it's not a fresh install
          _showStreakMessage("You missed a day. Streak Reset.");
        }
      }

      // 4. Save the new Streak
      await prefs.setInt('current_streak', _currentStreak);

      // 5. Reset Daily Tasks (Uncheck all)
      for (var task in _tasks) {
        task.isCompleted = false;
      }

      // 6. Update 'Last Open Date' to Today
      await prefs.setString('last_open_date', today);
      needsSave = true;
    }

    // 7. Update UI
    setState(() {});

    if (needsSave) {
      _saveTasks();
    }
  }

  void _showStreakMessage(String message) {
    // Wait for the build to finish before showing SnackBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.blueAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  // --- SAVE DATA HELPER ---

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> mapList =
        _tasks.map((t) => t.toMap()).toList();
    await prefs.setString('tasks_data', jsonEncode(mapList));
  }

  // --- CRUD OPERATIONS ---

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

  void _toggleTask(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Tasks'),
        actions: [
          // Optional: Show current streak in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text("🔥 $_currentStreak",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text(
                    'No tasks yet.\nTap the + button to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  elevation: 3, // Slight shadow
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Softer corners
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Better spacing
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (value) => _toggleTask(index),
                      activeColor: Colors.green,
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: task.isCompleted ? Colors.grey : Colors.black,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteTask(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
