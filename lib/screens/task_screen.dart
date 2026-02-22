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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadAndCheckDailyProgress() async {
    try {
      await _streakService.init();

      final prefs = await SharedPreferences.getInstance();
      final String? tasksString = prefs.getString('tasks_data');
      List<Task> allLoadedTasks = [];

      if (tasksString != null) {
        try {
          final dynamic decoded = jsonDecode(tasksString);
          if (decoded is List) {
            allLoadedTasks = decoded.map((item) => Task.fromMap(item)).toList();
          }
        } catch (e) {
          debugPrint("Error decoding tasks: $e");
        }
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      List<Task> todaysTasks = allLoadedTasks.where((t) {
        return _isSameDay(t.date, now) || t.date.isAfter(todayStart);
      }).toList();

      // Deadlines
      int removedCount = 0;
      todaysTasks.removeWhere((t) {
        if (t.isTemporary &&
            t.deadline != null &&
            t.deadline!.isBefore(now) &&
            !t.isCompleted) {
          removedCount++;
          return true;
        }
        return false;
      });

      if (removedCount > 0) {
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
        _sortTasks();
      }

      if (pendingOldTasks.isNotEmpty && mounted) {
        Future.delayed(Duration.zero, () {
          if (mounted) _showCarryForwardDialog(pendingOldTasks);
        });
      }
    } catch (e) {
      debugPrint("Critical error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortTasks() {
    setState(() {
      _tasks.sort((a, b) {
        if (a.isCompleted && !b.isCompleted) return 1;
        if (!a.isCompleted && b.isCompleted) return -1;

        switch (_currentSort) {
          case SortOption.highToLow:
            return b.effort.index.compareTo(a.effort.index);
          case SortOption.lowToHigh:
            return a.effort.index.compareTo(b.effort.index);
          case SortOption.creation:
          default:
            return 0;
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
              _sortTasks();
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

  void _addTask(String title, String? subject, String note, TaskEffort effort,
      DateTime? deadline) {
    if (title.trim().isNotEmpty) {
      setState(() {
        _tasks.add(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
          subject: subject?.trim().isEmpty ?? true
              ? null
              : subject!.trim(), // Save subject
          date: DateTime.now(),
          note: note.trim(),
          effort: effort,
          deadline: deadline,
          isTemporary: deadline != null,
        ));
      });
      _saveTasks();
      _sortTasks();
    }
  }

  void _showAddTaskSheet() {
    String title = "";
    String subject = "";
    String note = "";
    TaskEffort selectedEffort = TaskEffort.medium;

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

                  // Title
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "What needs to be done?",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => title = val,
                  ),
                  const SizedBox(height: 12),

                  // Subject
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "Subject / Tag (Optional)",
                      prefixIcon: Icon(Icons.bookmark_border),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => subject = val,
                  ),
                  const SizedBox(height: 12),

                  // Note
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "Add a note (Optional)",
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
                  const SizedBox(height: 16),

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
                            if (finalDeadline.isBefore(DateTime.now())) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Deadline cannot be in the past.")));
                              return;
                            }
                          }
                          _addTask(title, subject, note, selectedEffort,
                              finalDeadline);
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
    _sortTasks();

    if (task.isCompleted) {
      bool updated = await _streakService.markActionTaken();
      if (updated && mounted) {
        setState(() {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (_streakService.isSilentMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Task completed"),
                duration: Duration(seconds: 1)),
          );
        } else {
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
                    return _buildModernTaskCard(
                        entry.value, entry.key, theme, isDark);
                  }),
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

  // --- MODERN CHIP-BASED TASK CARD ---
  Widget _buildModernTaskCard(
      Task task, int index, ThemeData theme, bool isDark) {
    final bool isDone = task.isCompleted;
    final cardColor = theme.cardColor;

    // Effort metadata
    Color effortColor;
    String effortText;
    switch (task.effort) {
      case TaskEffort.quick:
        effortColor = Colors.amber;
        effortText = "Quick";
        break;
      case TaskEffort.medium:
        effortColor = Colors.blue;
        effortText = "Medium";
        break;
      case TaskEffort.deep:
        effortColor = Colors.deepPurple;
        effortText = "Deep";
        break;
    }

    // Deadline Calculation
    String? deadlineString;
    bool isUrgent = false;
    if (task.deadline != null && !isDone) {
      final diff = task.deadline!.difference(DateTime.now());
      if (diff.isNegative) {
        deadlineString = "Overdue";
        isUrgent = true;
      } else if (diff.inHours < 1) {
        deadlineString = "${diff.inMinutes}m left";
        isUrgent = true;
      } else if (diff.inHours < 24) {
        deadlineString = "${diff.inHours}h left";
      } else {
        deadlineString = "${diff.inDays}d left";
      }
    }

    return Opacity(
      opacity: isDone ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: isDone || isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP ROW: Checkbox, Title, Delete Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _toggleTask(index),
                    child: Container(
                      margin: const EdgeInsets.only(top: 2, right: 12),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDone ? Colors.blue : Colors.transparent,
                        border: Border.all(
                          color: isDone
                              ? Colors.blue
                              : (isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400),
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: isDone
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? Colors.grey
                            : theme.textTheme.bodyLarge?.color,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _deleteTask(index),
                    child: Icon(Icons.close,
                        size: 20, color: Colors.grey.shade400),
                  )
                ],
              ),

              // BOTTOM ROW: Chips
              Padding(
                padding: const EdgeInsets.only(
                    left: 36, top: 8), // Align with text, skipping checkbox
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Subject Tag
                    if (task.subject != null && task.subject!.isNotEmpty)
                      _buildMiniChip(
                          text: task.subject!,
                          icon: Icons.bookmark,
                          color: Colors.grey,
                          isDark: isDark),

                    // Effort Tag
                    _buildMiniChip(
                        text: effortText,
                        icon: Icons.bolt,
                        color: effortColor,
                        isDark: isDark),

                    // Pomodoro Sessions Tag
                    if (task.sessionsCompleted > 0)
                      _buildMiniChip(
                          text: "${task.sessionsCompleted}",
                          icon: Icons.local_fire_department,
                          color: Colors.deepOrange,
                          isDark: isDark),

                    // Deadline Tag
                    if (deadlineString != null)
                      _buildMiniChip(
                          text: deadlineString,
                          icon: Icons.access_time,
                          color: isUrgent ? Colors.red : Colors.orange,
                          isDark: isDark,
                          isFilled: isUrgent),
                  ],
                ),
              ),

              // Note (If exists)
              if (task.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task.note,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
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

  // Helper to build modern, small chips
  Widget _buildMiniChip(
      {required String text,
      required IconData icon,
      required Color color,
      required bool isDark,
      bool isFilled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFilled
            ? color.withOpacity(0.1)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isFilled
                ? color.withOpacity(0.3)
                : (isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isFilled
                  ? color
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
