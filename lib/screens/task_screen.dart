import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart'; // Ensure this model has id, date, note, effort

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<Task> _tasks = [];
  int _currentStreak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndCheckDailyProgress();
  }

  // --- 1. IMPROVED INIT & CARRY FORWARD LOGIC ---
  Future<void> _loadAndCheckDailyProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // A. Load Tasks
      final String? tasksString = prefs.getString('tasks_data');
      List<Task> allLoadedTasks = [];

      if (tasksString != null) {
        try {
          final List<dynamic> decodedList = jsonDecode(tasksString);
          allLoadedTasks =
              decodedList.map((item) => Task.fromMap(item)).toList();
        } catch (e) {
          debugPrint("Error decoding tasks: $e");
        }
      }

      // B. Filter Tasks (Today vs History)
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      List<Task> todaysTasks = allLoadedTasks.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        return tDate.isAtSameMomentAs(todayStart) || tDate.isAfter(todayStart);
      }).toList();

      List<Task> pendingOldTasks = allLoadedTasks.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        return tDate.isBefore(todayStart) && !t.isCompleted;
      }).toList();

      if (mounted) {
        setState(() {
          _tasks = todaysTasks;
          _isLoading = false;
        });
      }

      _handleStreakLogic(prefs, todayStart);

      if (pendingOldTasks.isNotEmpty && mounted) {
        Future.delayed(Duration.zero, () {
          _showCarryForwardDialog(pendingOldTasks);
        });
      }
    } catch (e) {
      debugPrint("Critical error loading data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStreakLogic(
      SharedPreferences prefs, DateTime todayDate) async {
    int streak = prefs.getInt('current_streak') ?? 0;
    final String? lastCompletionDate = prefs.getString('last_completion_date');
    final now = DateTime.now();
    final String todayKey = "${now.year}-${now.month}-${now.day}";

    if (lastCompletionDate != null) {
      try {
        final List<String> parts = lastCompletionDate.split('-');
        if (parts.length == 3) {
          final DateTime lastDate = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final int difference = todayDate.difference(lastDate).inDays;
          if (difference > 1) {
            streak = 0;
            await prefs.setInt('current_streak', 0);
          }
        }
      } catch (e) {
        streak = 0;
      }
    } else if (streak > 0) {
      streak = 0;
      await prefs.setInt('current_streak', 0);
    }

    await prefs.setString('last_open_date', todayKey);
    if (mounted) setState(() => _currentStreak = streak);
  }

  // --- 2. CARRY FORWARD DIALOG ---
  Future<void> _showCarryForwardDialog(List<Task> pendingTasks) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Plan Your Day"),
        content: Text(
            "You have ${pendingTasks.length} unfinished tasks from previous days.\n\nMove them to today?"),
        actions: [
          TextButton(
            onPressed: () {
              _saveTasks();
              Navigator.pop(context);
            },
            child: const Text("Discard", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                for (var task in pendingTasks) {
                  task.date = now;
                  _tasks.add(task);
                }
              });
              _saveTasks();
              Navigator.pop(context);
            },
            child: const Text("Carry Forward"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList =
          _tasks.map((t) => t.toMap()).toList();
      await prefs.setString('tasks_data', jsonEncode(mapList));
    } catch (e) {
      debugPrint("Error saving tasks: $e");
    }
  }

  // --- 3. ADD TASK ---
  void _addTask(String title, String note, TaskEffort effort) {
    if (title.trim().isNotEmpty) {
      setState(() {
        _tasks.add(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
          date: DateTime.now(),
          note: note.trim(),
          effort: effort,
        ));
      });
      _saveTasks();
    }
  }

  void _showAddTaskSheet() {
    String title = "";
    String note = "";
    TaskEffort selectedEffort = TaskEffort.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("New Task",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "e.g., Solve 20 MCQs",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => title = val,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "Add a note (optional)",
                      prefixIcon: Icon(Icons.notes),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => note = val,
                  ),
                  const SizedBox(height: 16),
                  const Text("Effort Level:",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEffortChip(TaskEffort.quick, selectedEffort,
                          (val) => setSheetState(() => selectedEffort = val)),
                      _buildEffortChip(TaskEffort.medium, selectedEffort,
                          (val) => setSheetState(() => selectedEffort = val)),
                      _buildEffortChip(TaskEffort.deep, selectedEffort,
                          (val) => setSheetState(() => selectedEffort = val)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (title.isNotEmpty) {
                          _addTask(title, note, selectedEffort);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("Add Task"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- FIX: VISUAL BUG FIX HERE ---
  Widget _buildEffortChip(
      TaskEffort value, TaskEffort groupValue, Function(TaskEffort) onSelect) {
    String label = value == TaskEffort.quick
        ? "Quick"
        : value == TaskEffort.medium
            ? "Medium"
            : "Deep Focus";
    Color color = value == TaskEffort.quick
        ? Colors.amber
        : value == TaskEffort.medium
            ? Colors.blue
            : Colors.deepPurple;
    bool isSelected = value == groupValue;

    // Detect Dark Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,

      // FIX: Use lighter text for unselected state in Dark Mode
      labelStyle: TextStyle(
          color:
              isSelected ? color : (isDark ? Colors.grey[300] : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),

      // FIX: Adjust border color for visibility in Dark Mode
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),

      onSelected: (_) => onSelect(value),
    );
  }

  // --- 4. TOGGLE & UNDO ---
  void _toggleTask(int index) {
    final task = _tasks[index];
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    _saveTasks();
    _checkDailyCompletion();

    if (task.isCompleted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Task completed"),
          action: SnackBarAction(
            label: "Undo",
            onPressed: () {
              setState(() {
                task.isCompleted = false;
              });
              _saveTasks();
            },
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkDailyCompletion() async {
    if (_tasks.isEmpty) return;
    final bool allDone = _tasks.every((t) => t.isCompleted);

    if (allDone) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? lastCompletionDate =
            prefs.getString('last_completion_date');
        final now = DateTime.now();
        final String todayKey = "${now.year}-${now.month}-${now.day}";

        if (lastCompletionDate != todayKey) {
          final int newStreak = _currentStreak + 1;
          await prefs.setInt('current_streak', newStreak);
          await prefs.setString('last_completion_date', todayKey);

          if (!mounted) return;
          setState(() => _currentStreak = newStreak);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("🎉 Daily Goal Complete! Streak Increased!")),
          );
        }
      } catch (e) {
        debugPrint("Error checking daily completion: $e");
      }
    }
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    _tasks.sort((a, b) => a.isCompleted == b.isCompleted
        ? 0
        : a.isCompleted
            ? 1
            : -1);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Daily Tasks',
            style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold)),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(_tasks[index], index, theme, isDark);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
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
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_add,
                size: 80, color: Colors.blue.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            'Ready to focus?',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 10),
          Text(
            'Add a task to start your streak!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, int index, ThemeData theme, bool isDark) {
    final cardColor = task.isCompleted
        ? (isDark ? Colors.grey[900] : Colors.grey[100])
        : theme.cardColor;
    final textColor =
        task.isCompleted ? Colors.grey : theme.textTheme.bodyLarge?.color;

    IconData effortIcon;
    Color effortColor;
    String effortText;
    switch (task.effort) {
      case TaskEffort.quick:
        effortIcon = Icons.bolt;
        effortColor = Colors.amber;
        effortText = "Quick";
        break;
      case TaskEffort.medium:
        effortIcon = Icons.timer;
        effortColor = Colors.blue;
        effortText = "Medium";
        break;
      case TaskEffort.deep:
        effortIcon = Icons.psychology;
        effortColor = Colors.deepPurple;
        effortText = "Deep";
        break;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Transform.scale(
          scale: 1.1,
          child: Checkbox(
            value: task.isCompleted,
            onChanged: (value) => _toggleTask(index),
            activeColor: Colors.blue,
            shape: const CircleBorder(),
            side: BorderSide(
                color: isDark ? Colors.grey : Colors.black54, width: 2),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: textColor,
            fontFamily: 'Poppins',
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(effortIcon, size: 14, color: effortColor),
            const SizedBox(width: 4),
            Text(effortText,
                style: TextStyle(
                    fontSize: 12,
                    color: effortColor,
                    fontWeight: FontWeight.bold)),
            if (task.note.isNotEmpty) ...[
              const SizedBox(width: 8),
              const Icon(Icons.notes, size: 14, color: Colors.grey),
            ]
          ],
        ),
        trailing: task.note.isNotEmpty
            ? const Icon(Icons.expand_more, color: Colors.grey)
            : IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
                onPressed: () => _deleteTask(index),
              ),
        children: task.note.isNotEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.note,
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteTask(index),
                      ),
                    ],
                  ),
                )
              ]
            : [],
      ),
    );
  }
}
