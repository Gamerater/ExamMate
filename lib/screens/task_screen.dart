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

  // --- LOGIC SECTION (Unchanged) ---

  Future<void> _loadAndCheckDailyProgress() async {
    final prefs = await SharedPreferences.getInstance();

    final String? tasksString = prefs.getString('tasks_data');
    if (tasksString != null) {
      final List<dynamic> decodedList = jsonDecode(tasksString);
      _tasks = decodedList.map((item) => Task.fromMap(item)).toList();
    }

    _currentStreak = prefs.getInt('current_streak') ?? 0;

    final String? lastOpenDate = prefs.getString('last_open_date');
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];

    bool needsSave = false;

    if (lastOpenDate != today) {
      if (lastOpenDate == yesterday) {
        bool allDone = _tasks.isNotEmpty && _tasks.every((t) => t.isCompleted);
        if (allDone) {
          _currentStreak++;
          _showStreakMessage("🔥 Streak Increased! Day $_currentStreak");
        } else {
          _currentStreak = 0;
          _showStreakMessage("Streak Reset. Don't give up!");
        }
      } else {
        if (lastOpenDate != null) {
          _currentStreak = 0;
          _showStreakMessage("You missed a day. Streak Reset.");
        }
      }

      await prefs.setInt('current_streak', _currentStreak);

      for (var task in _tasks) {
        task.isCompleted = false;
      }

      await prefs.setString('last_open_date', today);
      needsSave = true;
    }

    setState(() {});

    if (needsSave) {
      _saveTasks();
    }
  }

  void _showStreakMessage(String message) {
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

  // --- UI SECTION (Improved) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Lighter background
      appBar: AppBar(
        title: const Text(
          'Daily Tasks',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade100),
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
          ? _buildEmptyState() // Extracted to a clean helper method
          : ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 80),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return _buildTaskCard(
                    task, index); // Extracted for better styling
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        // improved FAB
        onPressed: _showAddTaskDialog,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Task", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_add,
                size: 80, color: Colors.blue.shade200),
          ),
          const SizedBox(height: 20),
          const Text(
            'No tasks for today',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
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

  Widget _buildTaskCard(Task task, int index) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: task.isCompleted,
            onChanged: (value) => _toggleTask(index),
            activeColor: Colors.blue,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            color: task.isCompleted ? Colors.grey : Colors.black87,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
          onPressed: () => _deleteTask(index),
        ),
      ),
    );
  }
}
