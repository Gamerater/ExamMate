import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/task.dart';
import '../services/streak_service.dart';
import '../services/pomodoro_service.dart';
import '../utils/subject_color_helper.dart';

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

  int _todaySessionCount = 0;
  int _todayFocusMinutes = 0;

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
    _loadTodaysStats();
  }

  @override
  void dispose() {
    _stopFeedback();
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- DATA LOADING ---

  Future<void> _loadTodaysStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('pomodoro_sessions_data');
      int count = 0;
      int minutes = 0;

      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        for (var item in decoded) {
          DateTime ts = DateTime.parse(item['timestamp']);
          if (ts.isAfter(todayStart) || ts.isAtSameMomentAs(todayStart)) {
            count++;
            minutes += (item['durationMinutes'] as int? ?? 0);
          }
        }
      }
      if (mounted) {
        setState(() {
          _todaySessionCount = count;
          _todayFocusMinutes = minutes;
        });
      }
    } catch (e) {
      debugPrint("Error loading today's stats: $e");
    }
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
              bool isDone = t.isCompleted || t.status == TaskStatus.completed;

              if (!isDone &&
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
          allTasks[index].isCompleted = true; // Legacy sync
          allTasks[index].completedAt = DateTime.now();
        }
        await prefs.setString(
            'tasks_data', json.encode(allTasks.map((e) => e.toMap()).toList()));
        _loadTodaysTasks();
      }
    }
  }

  // --- TIMER LOGIC ---

  void _handleTimerComplete() async {
    setState(() => _isRunning = false);
    _triggerFeedback();

    if (_isWorkMode) {
      await StreakService().markActionTaken();
      String? loggedSubject =
          _selectedSubject == "General Focus" ? null : _selectedSubject;
      await _pomoService.logSession(
          duration: _workDuration, subject: loggedSubject);
      await _loadTodaysStats();
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
      } catch (e) {
        debugPrint("Audio error: $e");
      }
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

  // --- SETTINGS & EDITING ---

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

  void _showTimerSettingsSheet() {
    int tempWork = _workDuration;
    int tempBreak = _breakDuration;
    bool tempSound = _enableSound;
    bool tempVib = _enableVibration;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return StatefulBuilder(builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Timer Settings",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  // Focus Duration Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Focus Duration",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text("$tempWork min",
                          style: TextStyle(
                              color: defaultWorkColor,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: tempWork.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: defaultWorkColor,
                    onChanged: (val) =>
                        setModalState(() => tempWork = val.toInt()),
                  ),
                  const SizedBox(height: 16),

                  // Break Duration Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Break Duration",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text("$tempBreak min",
                          style: TextStyle(
                              color: breakColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: tempBreak.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: breakColor,
                    onChanged: (val) =>
                        setModalState(() => tempBreak = val.toInt()),
                  ),

                  const Divider(height: 32),

                  // Toggles
                  SwitchListTile(
                    title: const Text("Sound Alerts",
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    contentPadding: EdgeInsets.zero,
                    value: tempSound,
                    activeColor: defaultWorkColor,
                    onChanged: (val) => setModalState(() => tempSound = val),
                  ),
                  SwitchListTile(
                    title: const Text("Vibration",
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    contentPadding: EdgeInsets.zero,
                    value: tempVib,
                    activeColor: defaultWorkColor,
                    onChanged: (val) => setModalState(() => tempVib = val),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('pomo_work_minutes', tempWork);
                        await prefs.setInt('pomo_break_minutes', tempBreak);
                        await prefs.setBool('pomo_sound_enabled', tempSound);
                        await prefs.setBool('pomo_vibration_enabled', tempVib);

                        setState(() {
                          _workDuration = tempWork;
                          _breakDuration = tempBreak;
                          _enableSound = tempSound;
                          _enableVibration = tempVib;
                          _updateControllerDuration();
                          if (_isRunning) _resetTimer();
                        });

                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: defaultWorkColor,
                      ),
                      child: const Text("Save Changes",
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            );
          });
        });
  }

  // --- CONTROLS ---

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

  // --- UI DIALOGS ---

  void _showCompletionDialog() {
    if (_isWorkMode && _linkedTask != null) {
      _updateTaskProgress(markCompleted: false, incrementSession: true);
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(_isWorkMode ? "Session Complete" : "Break Over",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (_isWorkMode) ...[
                const SizedBox(height: 8),
                Text("+$_workDuration minutes added",
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ],
              if (_isWorkMode && _linkedTask != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2))),
                  child: Column(
                    children: [
                      Text("You were working on:",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(_linkedTask!.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          textAlign: TextAlign.center,
                          maxLines: 2),
                      const SizedBox(height: 16),
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
                                  backgroundColor: Colors.blue, elevation: 0),
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
                      child: const Text("Stay Here",
                          style: TextStyle(fontWeight: FontWeight.bold))),
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
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select a Task",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Link a task to track your focus.",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 16),
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
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.circle_outlined,
                                color: Colors.blue),
                            title: Text(task.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            subtitle: task.subject != null
                                ? Text(task.subject!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500))
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        actions: [
          // FIX: Added settings gear back to the AppBar
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showTimerSettingsSheet,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // --- REFINED MODE SELECTOR & CONTEXT LINE ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Focus Mode",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSubject,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.grey, size: 20),
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
                const SizedBox(height: 8),

                // --- SUBTLE CONTEXT LINE ---
                GestureDetector(
                  onTap: _isRunning ? null : _showTaskSelector,
                  child: Row(
                    children: [
                      Icon(_linkedTask != null ? Icons.link : Icons.link_off,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _linkedTask != null
                              ? "Linked to: ${_linkedTask!.title}"
                              : "No task linked. Tap to attach.",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- MODE SWITCHER ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Expanded(
                      child: _buildModeButton("Work", true, activeWorkColor)),
                  Expanded(child: _buildModeButton("Break", false, breakColor)),
                ],
              ),
            ),

            const Spacer(),

            // --- TODAY'S SUMMARY ---
            Text(
              "Today: $_todaySessionCount session(s) • $_todayFocusMinutes min",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),

            // --- TIMER VISUALIZATION WITH TAPPABLE EDITING ---
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: _isRunning
                    ? [
                        BoxShadow(
                            color: currentColor.withOpacity(0.15),
                            blurRadius: 40,
                            spreadRadius: 5)
                      ]
                    : [],
              ),
              child: AnimatedBuilder(
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
                          strokeWidth: 16,
                          color: currentColor,
                          backgroundColor: currentColor.withOpacity(0.1),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_isWorkMode ? "Focus Session" : "Recovery Time",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: currentColor,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0)),
                          const SizedBox(height: 4),

                          // FIX: Made the time text tappable to open settings
                          GestureDetector(
                            onTap: _showTimerSettingsSheet,
                            child: Container(
                              color: Colors
                                  .transparent, // Increases tap target area safely
                              child: Text(_formatTime(count.ceil()),
                                  style: TextStyle(
                                      fontSize: 64,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ])),
                            ),
                          ),

                          Text("Remaining",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            const Spacer(),

            // --- BALANCED CONTROLS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: 0.6,
                  child: IconButton(
                      onPressed: _resetTimer,
                      icon: const Icon(Icons.refresh),
                      iconSize: 26,
                      color: Colors.grey),
                ),
                const SizedBox(width: 24),
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
                        color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(width: 74), // Balances the layout
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
