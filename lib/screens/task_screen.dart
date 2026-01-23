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

  @override
  void initState() {
    super.initState();
    _loadAndResetTasks();
  }

  // --- LOGIC: LOAD & DAILY RESET ---

  Future<void> _loadAndResetTasks() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load the Tasks
    final String? tasksString = prefs.getString('tasks_data');
    if (tasksString != null) {
      final List<dynamic> decodedList = jsonDecode(tasksString);
      _tasks = decodedList.map((item) => Task.fromMap(item)).toList();
    }

    // 2. Check the Date
    final String? lastOpenDate = prefs.getString('last_open_date');
    // Get today's date strictly as YYYY-MM-DD (ignoring time)
    final String today = DateTime.now().toString().split(' ')[0];

    bool needsSave = false;

    if (lastOpenDate != today) {
      // It is a NEW DAY! Reset all tasks.
      for (var task in _tasks) {
        task.isCompleted = false;
      }
      // Update the date to today
      await prefs.setString('last_open_date', today);
      needsSave = true;

      // Optional: Show a little message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('It\'s a new day! Tasks have been reset.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    }

    // 3. Update State & Save if needed
    setState(() {}); // Refresh UI

    if (needsSave) {
      _saveTasks();
    }
  }

  // --- EXISTING SAVE LOGIC ---

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> mapList =
        _tasks.map((t) => t.toMap()).toList();
    await prefs.setString('tasks_data', jsonEncode(mapList));
  }

  // --- CRUD OPERATIONS (Unchanged) ---

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
      appBar: AppBar(title: const Text('Daily Tasks')),
      body: _tasks.isEmpty
          ? const Center(
              child: Text(
                'No tasks yet.\nTap the + button to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
