import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/streak_service.dart';
import '../services/task_service.dart';
import '../repositories/task_repository.dart';
import '../utils/subject_color_helper.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  // Architecture Services
  final StreakService _streakService = StreakService();
  final TaskService _taskService = TaskService();
  final TaskRepository _taskRepo = TaskRepository();

  // State
  List<Task> _allTodayTasks = [];
  bool _isLoading = true;
  bool _isLowEnergyMode = false;

  // View Controllers
  SortOption _currentSort = SortOption.creation;
  String _currentFilter = "All Subjects";
  bool _isGrouped = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _streakService.init();

    // Clean expired tasks via Service
    int removed = await _taskService.removeExpiredTasks();
    if (removed > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$removed expired task(s) removed."),
          duration: const Duration(seconds: 4)));
    }

    await _loadTasks();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadTasks() async {
    try {
      List<Task> allLoaded = await _taskRepo.getTasks();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      List<Task> todays = allLoaded.where((t) {
        return _isSameDay(t.date, now) || t.date.isAfter(todayStart);
      }).toList();

      List<Task> pendingOld = allLoaded.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        return tDate.isBefore(todayStart) && t.status != TaskStatus.completed;
      }).toList();

      String todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      int rating = _streakService.dailyRatings[todayStr] ?? 0;

      if (mounted) {
        setState(() {
          _allTodayTasks = todays;
          _isLowEnergyMode = rating == 2 || rating == 3;
          _isLoading = false;
        });
      }

      if (pendingOld.isNotEmpty && mounted) {
        Future.delayed(Duration.zero, () {
          if (mounted) _showCarryForwardDialog(pendingOld);
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Discard", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final now = DateTime.now();
              List<Task> fullDb = await _taskRepo.getTasks();

              for (var pt in pendingTasks) {
                int idx = fullDb.indexWhere((t) => t.id == pt.id);
                if (idx != -1) {
                  fullDb[idx].date = now;
                }
              }
              await _taskRepo.saveTasks(fullDb);
              Navigator.pop(context);
              _loadTasks();
            },
            child: const Text("Carry Forward"),
          ),
        ],
      ),
    );
  }

  Future<void> _addTask(String title, String? subject, String note,
      TaskEffort effort, DateTime? deadline) async {
    if (title.trim().isEmpty) return;

    Task newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      subject: subject?.trim().isEmpty ?? true ? null : subject!.trim(),
      date: DateTime.now(),
      note: note.trim(),
      effort: effort,
      deadline: deadline,
      isTemporary: deadline != null,
    );

    List<Task> fullDb = await _taskRepo.getTasks();
    fullDb.add(newTask);
    await _taskRepo.saveTasks(fullDb);
    _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    List<Task> fullDb = await _taskRepo.getTasks();
    fullDb.removeWhere((t) => t.id == task.id);
    await _taskRepo.saveTasks(fullDb);
    _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    List<Task> fullDb = await _taskRepo.getTasks();
    int idx = fullDb.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      bool isNowCompleted = fullDb[idx].status != TaskStatus.completed;
      fullDb[idx].status =
          isNowCompleted ? TaskStatus.completed : TaskStatus.active;
      fullDb[idx].isCompleted = isNowCompleted; // Legacy sync
      fullDb[idx].completedAt = isNowCompleted ? DateTime.now() : null;

      await _taskRepo.saveTasks(fullDb);
      _loadTasks();

      if (isNowCompleted) {
        await _streakService.markActionTaken();
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          if (_streakService.isSilentMode) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Task completed"),
                duration: Duration(seconds: 1)));
          } else {
            String msg =
                "Streak Active! You are a ${_streakService.getDisciplineIdentity()}";
            if (task.isTemporary && task.deadline != null)
              msg = "Completed before deadline! Great focus.";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(msg),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2)));
          }
        }
      }
    }
  }

  void _showFilterSortMenu() {
    List<String> subjects = _taskService.getUniqueSubjects(_allTodayTasks);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text("View Options",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(),

                  // Grouping Toggle
                  SwitchListTile(
                    title: const Text("Group by Subject",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Organize tasks by category"),
                    value: _isGrouped,
                    onChanged: (val) {
                      setState(() => _isGrouped = val);
                      setModalState(() {});
                    },
                  ),
                  const Divider(),

                  // Subject Filter
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("Filter Subject",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _currentFilter,
                          items: subjects
                              .map((sub) => DropdownMenuItem(
                                  value: sub, child: Text(sub)))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _currentFilter = val!);
                            setModalState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sort Options
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("Sort By",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                  RadioListTile<SortOption>(
                    title: const Text("Default (Creation Time)"),
                    value: SortOption.creation,
                    groupValue: _currentSort,
                    onChanged: (val) {
                      setState(() => _currentSort = val!);
                      setModalState(() {});
                    },
                  ),
                  RadioListTile<SortOption>(
                    title: const Text("Priority: High to Low"),
                    value: SortOption.highToLow,
                    groupValue: _currentSort,
                    onChanged: (val) {
                      setState(() => _currentSort = val!);
                      setModalState(() {});
                    },
                  ),
                  RadioListTile<SortOption>(
                    title: const Text("Priority: Low to High"),
                    value: SortOption.lowToHigh,
                    groupValue: _currentSort,
                    onChanged: (val) {
                      setState(() => _currentSort = val!);
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  right: 20),
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
                          hintText: "What needs to be done?",
                          border: OutlineInputBorder()),
                      onChanged: (val) => title = val),
                  const SizedBox(height: 12),
                  TextField(
                      decoration: const InputDecoration(
                          hintText: "Subject / Tag (Optional)",
                          prefixIcon: Icon(Icons.bookmark_border),
                          border: OutlineInputBorder()),
                      onChanged: (val) => subject = val),
                  const SizedBox(height: 12),
                  TextField(
                      decoration: const InputDecoration(
                          hintText: "Add a note (Optional)",
                          prefixIcon: Icon(Icons.notes),
                          border: OutlineInputBorder()),
                      onChanged: (val) => note = val),
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
                                DateTime.now().add(const Duration(days: 30)));
                        if (date != null) {
                          final time = await showTimePicker(
                              context: context, initialTime: TimeOfDay.now());
                          if (time != null)
                            setSheetState(() {
                              selectedDate = date;
                              selectedTime = time;
                            });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(deadlineText,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500))
                        ]),
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
                                selectedTime!.minute);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Apply Service Logic
    List<Task> filtered =
        _taskService.filterTasks(_allTodayTasks, _currentFilter);
    List<Task> displayTasks = _taskService.sortTasks(filtered, _currentSort);

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
              Text(_streakService.getDisciplineIdentity().toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
                _currentFilter == "All Subjects" && !_isGrouped
                    ? Icons.filter_list
                    : Icons.filter_list_alt,
                color: _currentFilter == "All Subjects" && !_isGrouped
                    ? Colors.grey
                    : Colors.blue),
            onPressed: _showFilterSortMenu,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allTodayTasks.isEmpty
              ? _buildEmptyState(theme)
              : _isGrouped
                  ? _buildGroupedList(displayTasks, theme, isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                      itemCount: displayTasks.length,
                      itemBuilder: (c, i) =>
                          _buildModernTaskCard(displayTasks[i], theme, isDark),
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

  // --- SMART GROUPING VIEW ---
  Widget _buildGroupedList(List<Task> tasks, ThemeData theme, bool isDark) {
    if (tasks.isEmpty)
      return const Center(child: Text("No tasks match filter."));

    Map<String, List<Task>> groups = _taskService.groupTasksBySubject(tasks);
    List<String> keys = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        String subject = keys[index];
        List<Task> groupTasks = groups[subject]!;
        Color subColor = SubjectColorHelper.getColor(subject);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
              child: Row(
                children: [
                  Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                          color: subColor,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text(subject,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: subColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text("${groupTasks.length}",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: subColor)),
                  )
                ],
              ),
            ),
            ...groupTasks.map((t) => _buildModernTaskCard(t, theme, isDark)),
          ],
        );
      },
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
                color: (_isLowEnergyMode ? Colors.teal : Colors.blue)
                    .withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.assignment_add,
                size: 80,
                color: (_isLowEnergyMode ? Colors.teal : Colors.blue)
                    .withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(_isLowEnergyMode ? "No pressure." : "Ready to focus?",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }

  Widget _buildModernTaskCard(Task task, ThemeData theme, bool isDark) {
    final bool isDone = task.status == TaskStatus.completed;
    final cardColor = theme.cardColor;

    Color effortColor = task.effort == TaskEffort.quick
        ? Colors.amber
        : task.effort == TaskEffort.medium
            ? Colors.blue
            : Colors.deepPurple;
    String effortText = task.effort == TaskEffort.quick
        ? "Quick"
        : task.effort == TaskEffort.medium
            ? "Medium"
            : "Deep";

    // NEW: Subject Color
    Color subjectColor = SubjectColorHelper.getColor(task.subject);

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _toggleTask(task),
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
                            width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: isDone
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Text(task.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDone
                                ? Colors.grey
                                : theme.textTheme.bodyLarge?.color,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null)),
                  ),
                  InkWell(
                      onTap: () => _deleteTask(task),
                      child: Icon(Icons.close,
                          size: 20, color: Colors.grey.shade400))
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (task.subject != null &&
                        task.subject!.isNotEmpty &&
                        !_isGrouped)
                      _buildMiniChip(
                          text: task.subject!,
                          icon: Icons.bookmark,
                          color: subjectColor,
                          isDark: isDark,
                          isFilled: true),
                    _buildMiniChip(
                        text: effortText,
                        icon: Icons.bolt,
                        color: effortColor,
                        isDark: isDark),
                    if (task.sessionsCompleted > 0)
                      _buildMiniChip(
                          text: "${task.sessionsCompleted}",
                          icon: Icons.local_fire_department,
                          color: Colors.deepOrange,
                          isDark: isDark),
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
              if (task.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(task.note,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
            ? color.withOpacity(0.15)
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
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isFilled
                      ? (isDark
                          ? color.withOpacity(0.9)
                          : color.withOpacity(1.0))
                      : Colors.grey.shade500)),
        ],
      ),
    );
  }
}
