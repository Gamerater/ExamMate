import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/task.dart';
import '../services/streak_service.dart';
import '../services/pomodoro_service.dart';
import '../utils/subject_color_helper.dart'; // IMPORT COLOR SYSTEM

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  // --- CONSTANTS ---
  static const Color defaultWorkColor = Colors.deepPurpleAccent;
  static const Color breakColor = Colors.green;

  // --- STATE ---
  late AnimationController _controller;
  bool _isWorkMode = true;
  bool _isRunning = false;

  int _workDuration = 25;
  int _breakDuration = 5;

  bool _enableSound = true;
  bool _enableVibration = true;
  bool _cancelFeedback = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final PomodoroService _pomoService = PomodoroService();

  // Task & Subject State
  Task? _linkedTask;
  List<Task> _todaysTasks = [];
  List<String> _availableSubjects = ["General Focus"];
  String _selectedSubject = "General Focus";

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(minutes: 25));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) _handleTimerComplete();
    });

    _loadSettings();
    _loadTodaysTasks();
  }

  @override
  void dispose() {
    _stopFeedback();
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTodaysTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('tasks_data');
    if (tasksString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tasksString);
        final allTasks = decoded.map((e) => Task.fromMap(e)).toList();
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        Set<String> uniqueSubjects = {"General Focus"};

        if (mounted) {
          setState(() {
            _todaysTasks = allTasks.where((t) {
              final tDate = DateTime(t.date.year, t.date.month, t.date.day);
              if (!t.isCompleted &&
                  (tDate.isAtSameMomentAs(todayStart) ||
                      tDate.isAfter(todayStart))) {
                if (t.subject != null && t.subject!.trim().isNotEmpty) {
                  uniqueSubjects.add(t.subject!.trim());
                }
                return true;
              }
              return false;
            }).toList();

            _availableSubjects = uniqueSubjects.toList();
          });
        }
      } catch (e) {
        debugPrint("Error loading tasks: $e");
      }
    }
  }

  Future<void> _updateTaskProgress(
      {required bool markCompleted, required bool incrementSession}) async {
    if (_linkedTask == null) return;
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('tasks_data');
    if (tasksString != null) {
      final List<dynamic> decoded = jsonDecode(tasksString);
      List<Task> allTasks = decoded.map((e) => Task.fromMap(e)).toList();
      final index = allTasks.indexWhere((t) => t.id == _linkedTask!.id);
      if (index != -1) {
        if (incrementSession) allTasks[index].sessionsCompleted += 1;
        if (markCompleted) {
          allTasks[index].status = TaskStatus.completed;
          allTasks[index].isCompleted = true; // Legacy
        }
        await prefs.setString(
            'tasks_data', json.encode(allTasks.map((e) => e.toMap()).toList()));
        _loadTodaysTasks();
      }
    }
  }

  void _handleTimerComplete() async {
    setState(() => _isRunning = false);
    _triggerFeedback();

    if (_isWorkMode) {
      await StreakService().markActionTaken(); // MVP action

      // LOG SESSION BY SUBJECT
      String? loggedSubject =
          _selectedSubject == "General Focus" ? null : _selectedSubject;
      await _pomoService.logSession(
          duration: _workDuration, subject: loggedSubject);
    }

    if (!mounted) return;
    _showCompletionDialog();
  }

  Future<void> _triggerFeedback() async {
    _cancelFeedback = false;
    if (_enableSound) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('sounds/bell.mp3'));
      } catch (e) {}
    }
    if (_enableVibration) {
      for (int i = 0; i < 4; i++) {
        if (_cancelFeedback || !mounted) break;
        try {
          await HapticFeedback.vibrate();
        } catch (_) {}
        if (_cancelFeedback || !mounted) break;
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }

  Future<void> _stopFeedback() async {
    _cancelFeedback = true;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _workDuration = prefs.getInt('pomo_work_minutes') ?? 25;
        _breakDuration = prefs.getInt('pomo_break_minutes') ?? 5;
        _enableSound = prefs.getBool('pomo_sound_enabled') ?? true;
        _enableVibration = prefs.getBool('pomo_vibration_enabled') ?? true;
        _updateControllerDuration();
      });
    }
  }

  void _updateControllerDuration() {
    int minutes = _isWorkMode ? _workDuration : _breakDuration;
    _controller.duration = Duration(minutes: minutes);
    _controller.value = 1.0;
  }

  void _toggleTimer() {
    if (_controller.isAnimating) {
      _controller.stop();
      setState(() => _isRunning = false);
    } else {
      _controller.reverse(
          from: _controller.value == 0.0 ? 1.0 : _controller.value);
      setState(() => _isRunning = true);
    }
  }

  void _resetTimer() {
    _stopFeedback();
    _controller.stop();
    _controller.value = 1.0;
    setState(() => _isRunning = false);
  }

  Future<void> _confirmSwitch(bool isWork) async {
    if (!_isRunning) {
      _switchMode(isWork);
      return;
    }
    final bool? shouldSwitch = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Stop Timer?"),
        content: const Text("Switching modes will stop the current timer."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Stop & Switch",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldSwitch == true) {
      _resetTimer();
      _switchMode(isWork);
    }
  }

  void _switchMode(bool isWork) {
    if (_isWorkMode == isWork) return;
    setState(() {
      _isWorkMode = isWork;
      _updateControllerDuration();
    });
  }

  void _showCompletionDialog() {
    if (_isWorkMode && _linkedTask != null) {
      _updateTaskProgress(markCompleted: false, incrementSession: true);
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(_isWorkMode ? "Great Focus!" : "Break Over!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_isWorkMode
                  ? "Time to take a break?"
                  : "Ready to get back to work?"),
              if (_isWorkMode && _linkedTask != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text("You were working on:",
                          style:
                              TextStyle(fontSize: 12, color: Colors.blue[800])),
                      const SizedBox(height: 4),
                      Text(_linkedTask!.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                              onPressed: () {
                                _stopFeedback();
                                Navigator.pop(context);
                                _switchMode(!_isWorkMode);
                              },
                              child: const Text("Not Done")),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green),
                              onPressed: () {
                                _updateTaskProgress(
                                    markCompleted: true,
                                    incrementSession: false);
                                _stopFeedback();
                                Navigator.pop(context);
                                _switchMode(!_isWorkMode);
                              },
                              child: const Text("Mark Done",
                                  style: TextStyle(color: Colors.white))),
                        ],
                      )
                    ],
                  ),
                )
              ]
            ],
          ),
          actions: (_isWorkMode && _linkedTask != null)
              ? null
              : [
                  TextButton(
                      onPressed: () {
                        _stopFeedback();
                        Navigator.pop(context);
                        _switchMode(!_isWorkMode);
                      },
                      child: const Text("Switch Mode")),
                  TextButton(
                      onPressed: () {
                        _stopFeedback();
                        Navigator.pop(context);
                      },
                      child: const Text("Stay Here")),
                ],
        );
      },
    );
  }

  void _showTaskSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            children: [
              const Text("Select a Task",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: _todaysTasks.isEmpty
                    ? const Center(
                        child: Text("No incomplete tasks for today!",
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _todaysTasks.length,
                        itemBuilder: (context, index) {
                          final task = _todaysTasks[index];
                          return ListTile(
                            leading: const Icon(Icons.circle_outlined),
                            title: Text(task.title),
                            subtitle: task.subject != null
                                ? Text(task.subject!)
                                : null,
                            onTap: () {
                              setState(() {
                                _linkedTask = task;
                                // Auto-select subject if task has one
                                if (task.subject != null &&
                                    _availableSubjects.contains(task.subject)) {
                                  _selectedSubject = task.subject!;
                                }
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final int m = totalSeconds ~/ 60;
    final int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildModeButton(String label, bool isWork, Color color) {
    final bool isSelected = _isWorkMode == isWork;
    return GestureDetector(
      onTap: () => _confirmSwitch(isWork),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(25)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic Work Color based on selected Subject
    Color activeWorkColor = _selectedSubject == "General Focus"
        ? defaultWorkColor
        : SubjectColorHelper.getColor(_selectedSubject);

    final currentColor = _isWorkMode ? activeWorkColor : breakColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Pomodoro",
            style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: theme.iconTheme,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            // --- SUBJECT SELECTOR ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSubject,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  items: _availableSubjects.map((String subject) {
                    bool isGen = subject == "General Focus";
                    Color sc = isGen
                        ? Colors.grey
                        : SubjectColorHelper.getColor(subject);
                    return DropdownMenuItem<String>(
                      value: subject,
                      child: Row(
                        children: [
                          Icon(isGen ? Icons.adjust : Icons.bookmark,
                              size: 14, color: sc),
                          const SizedBox(width: 8),
                          Text(subject,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: theme.textTheme.bodyLarge?.color)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isRunning
                      ? null
                      : (String? newValue) {
                          if (newValue != null)
                            setState(() => _selectedSubject = newValue);
                        },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- MODE SWITCHER ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(30)),
              child: Row(
                children: [
                  Expanded(
                      child: _buildModeButton("Work", true, activeWorkColor)),
                  Expanded(child: _buildModeButton("Break", false, breakColor)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            if (_isWorkMode)
              InkWell(
                onTap: _isRunning ? null : _showTaskSelector,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _linkedTask != null
                        ? currentColor.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            _linkedTask != null ? currentColor : Colors.grey),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          _linkedTask != null
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color:
                              _linkedTask != null ? currentColor : Colors.grey),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text(_linkedTask?.title ?? "Link a Task",
                              style: TextStyle(
                                  color: _linkedTask != null
                                      ? currentColor
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // --- TIMER VISUALIZATION ---
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final count =
                    _controller.duration!.inSeconds * _controller.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: _controller.value,
                        strokeWidth: 20,
                        color: currentColor,
                        backgroundColor: currentColor.withOpacity(0.1),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatTime(count.ceil()),
                            style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                        Text(
                            _isWorkMode
                                ? (_selectedSubject == "General Focus"
                                    ? "Focus Time"
                                    : _selectedSubject)
                                : "Rest Time",
                            style: TextStyle(
                                fontSize: 18,
                                color: currentColor,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                );
              },
            ),

            const Spacer(),

            // --- CONTROLS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    iconSize: 32,
                    color: Colors.grey),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: _toggleTimer,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: currentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: currentColor.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5))
                        ]),
                    child: Icon(_isRunning ? Icons.pause : Icons.play_arrow,
                        color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(width: 80),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
