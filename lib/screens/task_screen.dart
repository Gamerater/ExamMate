import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/streak_service.dart';

// Sorting Options
enum SortOption { creation, highToLow, lowToHigh }

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<Task> _tasks = [];
  bool _isLoading = true;

  // Sorting State
  SortOption _currentSort = SortOption.creation;

  // Feature State
  final StreakService _streakService = StreakService();
  bool _isLowEnergyMode = false;

  @override
  void initState() {
    super.initState();
    _loadAndCheckDailyProgress();
  }

  Future<void> _loadAndCheckDailyProgress() async {
    try {
      await _streakService.init();

      final prefs = await SharedPreferences.getInstance();
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

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // 1. Filter for Today
      List<Task> todaysTasks = allLoadedTasks.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        return tDate.isAtSameMomentAs(todayStart) || tDate.isAfter(todayStart);
      }).toList();

      // 2. Check Deadlines (Feature 2)
      // Remove expired temporary tasks and notify user
      int removedCount = 0;
      todaysTasks.removeWhere((t) {
        if (t.isTemporary &&
            t.deadline != null &&
            t.deadline!.isBefore(now) &&
            !t.isCompleted) {
          removedCount++;
          return true; // Remove
        }
        return false; // Keep
      });

      if (removedCount > 0) {
        // Save the cleanup immediately
        final List<Map<String, dynamic>> mapList =
            todaysTasks.map((t) => t.toMap()).toList();
        await prefs.setString('tasks_data', jsonEncode(mapList));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "$removedCount expired task(s) removed. You can add them again if needed."),
            duration: const Duration(seconds: 4),
          ));
        }
      }

      List<Task> pendingOldTasks = allLoadedTasks.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        return tDate.isBefore(todayStart) && !t.isCompleted;
      }).toList();

      // Feature 3 from previous step: Low Energy Mode Check
      String todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      int rating = _streakService.dailyRatings[todayStr] ?? 0;
      bool lowEnergy = rating == 2 || rating == 3;

      if (mounted) {
        setState(() {
          _tasks = todaysTasks;
          _isLowEnergyMode = lowEnergy;
          _isLoading = false;
        });
        // Apply Sort immediately after loading
        _sortTasks();
      }

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

  // --- SORTING LOGIC ---
  void _sortTasks() {
    setState(() {
      _tasks.sort((a, b) {
        // 1. Completed tasks always at the bottom
        if (a.isCompleted && !b.isCompleted) return 1;
        if (!a.isCompleted && b.isCompleted) return -1;

        // 2. Sort based on selection
        switch (_currentSort) {
          case SortOption.highToLow:
            // Deep (2) > Medium (1) > Quick (0)
            return b.effort.index.compareTo(a.effort.index);
          case SortOption.lowToHigh:
            return a.effort.index.compareTo(b.effort.index);
          case SortOption.creation:
          default:
            return 0; // Keep original list order
        }
      });
    });
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Sort Tasks By",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text("Default (Creation Order)"),
                trailing: _currentSort == SortOption.creation
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _currentSort = SortOption.creation);
                  _sortTasks();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.priority_high),
                title: const Text("Priority: High to Low"),
                trailing: _currentSort == SortOption.highToLow
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _currentSort = SortOption.highToLow);
                  _sortTasks();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.low_priority),
                title: const Text("Priority: Low to High"),
                trailing: _currentSort == SortOption.lowToHigh
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _currentSort = SortOption.lowToHigh);
                  _sortTasks();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

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
              _sortTasks(); // Re-sort after adding
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

  void _addTask(
      String title, String note, TaskEffort effort, DateTime? deadline) {
    if (title.trim().isNotEmpty) {
      setState(() {
        _tasks.add(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
          date: DateTime.now(),
          note: note.trim(),
          effort: effort,
          deadline: deadline,
          isTemporary: deadline != null, // Auto-flag if deadline exists
        ));
      });
      _saveTasks();
      _sortTasks(); // Re-sort to place new task correctly
    }
  }

  void _showAddTaskSheet() {
    String title = "";
    String note = "";
    TaskEffort selectedEffort = TaskEffort.medium;

    // Deadline State
    bool hasDeadline = false;
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Helper to format deadline text
            String deadlineText = "Set Date & Time";
            if (selectedDate != null && selectedTime != null) {
              deadlineText =
                  "${selectedDate!.day}/${selectedDate!.month} at ${selectedTime!.format(context)}";
            }

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

                  // --- EFFORT SELECTION ---
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
                  const SizedBox(height: 16),

                  // --- DEADLINE TOGGLE ---
                  SwitchListTile(
                    title: const Text("Set Deadline"),
                    subtitle: const Text("Temporary task"),
                    value: hasDeadline,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setSheetState(() => hasDeadline = val),
                  ),

                  if (hasDeadline) ...[
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setSheetState(() {
                              selectedDate = date;
                              selectedTime = time;
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(deadlineText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (title.isNotEmpty) {
                          DateTime? finalDeadline;
                          // Combine Date + Time
                          if (hasDeadline &&
                              selectedDate != null &&
                              selectedTime != null) {
                            finalDeadline = DateTime(
                              selectedDate!.year,
                              selectedDate!.month,
                              selectedDate!.day,
                              selectedTime!.hour,
                              selectedTime!.minute,
                            );

                            // Prevent past deadlines
                            if (finalDeadline.isBefore(DateTime.now())) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Deadline cannot be in the past.")));
                              return;
                            }
                          }

                          _addTask(title, note, selectedEffort, finalDeadline);
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
          color:
              isSelected ? color : (isDark ? Colors.grey[300] : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
      onSelected: (_) => onSelect(value),
    );
  }

  Future<void> _toggleTask(int index) async {
    final task = _tasks[index];
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    _saveTasks();
    _sortTasks(); // Re-sort to move completed to bottom

    if (task.isCompleted) {
      bool updated = await _streakService.markActionTaken();
      if (updated && mounted) {
        setState(() {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Check Silent Mode
        if (_streakService.isSilentMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Task completed"),
                duration: Duration(seconds: 1)),
          );
        } else {
          // Customized message for deadline tasks
          String msg =
              "Streak Active! You are a ${_streakService.getDisciplineIdentity()}";
          if (task.isTemporary && task.deadline != null) {
            msg = "Completed before deadline! Great focus.";
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(_isLowEnergyMode ? "One Step at a Time" : "Daily Tasks",
                style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            if (_streakService.currentStreak > 0)
              Text(
                _streakService.getDisciplineIdentity().toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: theme.iconTheme,
        actions: [
          // SORT BUTTON
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortMenu,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20, left: 8),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _streakService.hasActionToday
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _streakService.hasActionToday
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 16,
                        color: _streakService.hasActionToday
                            ? Colors.deepOrange
                            : Colors.grey),
                    const SizedBox(width: 4),
                    Text("${_streakService.currentStreak}",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _streakService.hasActionToday
                                ? Colors.deepOrange
                                : Colors.grey)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
              children: [
                if (_tasks.isEmpty)
                  _buildEmptyState(theme)
                else
                  ..._tasks.asMap().entries.map((entry) {
                    return _buildTaskCard(
                        entry.value, entry.key, theme, isDark);
                  }).toList(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        backgroundColor: _isLowEnergyMode ? Colors.teal : Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(_isLowEnergyMode ? "Add 1 Thing" : "New Task",
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: (_isLowEnergyMode ? Colors.teal : Colors.blue)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_add,
                size: 80,
                color: (_isLowEnergyMode ? Colors.teal : Colors.blue)
                    .withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            _isLowEnergyMode ? "No pressure." : "Ready to focus?",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 10),
          Text(
            _isLowEnergyMode
                ? "Just add one small task today."
                : "Add a task to start your streak!",
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

    // Deadline Calculation
    String deadlineString = "";
    bool isUrgent = false;
    if (task.deadline != null && !task.isCompleted) {
      final diff = task.deadline!.difference(DateTime.now());
      if (diff.isNegative) {
        deadlineString = "Overdue";
      } else if (diff.inHours < 1) {
        deadlineString = "${diff.inMinutes}m left";
        isUrgent = true;
      } else if (diff.inHours < 24) {
        deadlineString = "${diff.inHours}h left";
      } else {
        deadlineString = "${diff.inDays}d left";
      }
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
        title: Row(
          children: [
            Expanded(
              child: Text(
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
            ),
            // DEADLINE INDICATOR
            if (task.deadline != null && !task.isCompleted)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: isUrgent
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isUrgent ? Colors.red : Colors.orange,
                        width: 0.5)),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 12, color: isUrgent ? Colors.red : Colors.orange),
                    const SizedBox(width: 4),
                    Text(deadlineString,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUrgent ? Colors.red : Colors.orange[800])),
                  ],
                ),
              )
          ],
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
            if (task.sessionsCompleted > 0) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        size: 12, color: Colors.deepOrange),
                    const SizedBox(width: 2),
                    Text("${task.sessionsCompleted}",
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange)),
                  ],
                ),
              ),
            ],
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
