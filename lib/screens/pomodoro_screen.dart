import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import '../models/task.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  // --- CONSTANTS ---
  static const Color workColor = Colors.deepPurpleAccent;
  static const Color breakColor = Colors.green;

  // --- STATE ---
  late AnimationController _controller;
  bool _isWorkMode = true;
  bool _isRunning = false;

  // Configuration (Default)
  int _workDuration = 25;
  int _breakDuration = 5;

  // Preferences
  bool _enableSound = true;
  bool _enableVibration = true;
  bool _isSmartBreak = false;
  bool _cancelFeedback = false;

  // Dependencies
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Task Linking
  Task? _linkedTask;
  List<Task> _todaysTasks = [];

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 25),
    );

    // Listen for timer completion
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _handleTimerComplete();
      }
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

  // --- 1. DATA LOGIC ---

  Future<void> _loadTodaysTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('tasks_data');
    if (tasksString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tasksString);
        final allTasks = decoded.map((e) => Task.fromMap(e)).toList();
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        if (mounted) {
          setState(() {
            _todaysTasks = allTasks.where((t) {
              final tDate = DateTime(t.date.year, t.date.month, t.date.day);
              // Filter: Not completed AND (Today OR Future)
              return !t.isCompleted &&
                  (tDate.isAtSameMomentAs(todayStart) ||
                      tDate.isAfter(todayStart));
            }).toList();
          });
        }
      } catch (e) {
        debugPrint("Error loading tasks: $e");
      }
    }
  }

  /// Updates task stats safely.
  /// [markCompleted]: Sets isCompleted to true.
  /// [incrementSession]: Adds +1 to the session counter (Use false if only marking done).
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
        if (incrementSession) {
          allTasks[index].sessionsCompleted += 1;
        }
        if (markCompleted) {
          allTasks[index].isCompleted = true;
        }

        final String data =
            json.encode(allTasks.map((e) => e.toMap()).toList());
        await prefs.setString('tasks_data', data);

        // Refresh UI
        _loadTodaysTasks();
      }
    }
  }

  // --- 2. TIMER LOGIC & FEEDBACK ---

  void _handleTimerComplete() {
    setState(() => _isRunning = false);
    _triggerFeedback();
    _showCompletionDialog();
  }

  Future<void> _triggerFeedback() async {
    _cancelFeedback = false; // Reset cancellation flag

    // Play Sound
    if (_enableSound) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('sounds/bell.mp3'));
      } catch (e) {
        debugPrint("Error playing sound: $e");
      }
    }

    // Vibrate Pattern (Loop 4 times)
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
    _cancelFeedback = true; // Stop the vibration loop
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  // --- 3. SETTINGS & PERSISTENCE ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _workDuration = prefs.getInt('pomo_work_minutes') ?? 25;
        _breakDuration = prefs.getInt('pomo_break_minutes') ?? 5;
        _enableSound = prefs.getBool('pomo_sound_enabled') ?? true;
        _enableVibration = prefs.getBool('pomo_vibration_enabled') ?? true;
        _isSmartBreak = prefs.getBool('pomo_smart_break') ?? false;

        // Apply loaded settings to controller
        _updateControllerDuration();
      });
    }
  }

  Future<void> _saveSettings(
      {required int work,
      required int breakTime,
      required bool sound,
      required bool vibration,
      required bool isSmart}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomo_work_minutes', work);
    await prefs.setInt('pomo_break_minutes', breakTime);
    await prefs.setBool('pomo_sound_enabled', sound);
    await prefs.setBool('pomo_vibration_enabled', vibration);
    await prefs.setBool('pomo_smart_break', isSmart);

    if (mounted) {
      setState(() {
        _workDuration = work;
        _breakDuration = breakTime;
        _enableSound = sound;
        _enableVibration = vibration;
        _isSmartBreak = isSmart;

        if (_isRunning) {
          _resetTimer(); // Reset if running to apply new time safely
        } else {
          _updateControllerDuration();
        }
      });
    }
  }

  void _updateControllerDuration() {
    int minutes = _isWorkMode ? _workDuration : _breakDuration;
    _controller.duration = Duration(minutes: minutes);
    _controller.value = 1.0; // Reset visual progress
  }

  // --- 4. CONTROLS ---

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
    // If stopped, just switch
    if (!_isRunning) {
      _switchMode(isWork);
      return;
    }
    // If running, ask confirmation
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Stop & Switch",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  // --- 5. UI COMPONENTS ---

  void _showSettingsDialog() {
    // Temporary variables for the dialog state
    int tempWork = _workDuration;
    int tempBreak = _breakDuration;
    bool tempSound = _enableSound;
    bool tempVibration = _enableVibration;
    bool isSmartMode = _isSmartBreak;

    // Theme check for text colors
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Picker Logic
            Future<void> pickTime(bool isWork) async {
              int initialMin = isWork ? tempWork : tempBreak;
              if (initialMin < 1) initialMin = 1;

              final int h = (initialMin ~/ 60).clamp(0, 23);
              final int m = (initialMin % 60).clamp(0, 59);

              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: h, minute: m),
                initialEntryMode:
                    TimePickerEntryMode.input, // Input first for speed
                helpText: isWork ? "SET WORK DURATION" : "SET BREAK DURATION",
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                setStateDialog(() {
                  int totalMinutes = (picked.hour * 60) + picked.minute;
                  if (totalMinutes < 1) totalMinutes = 1;

                  if (isWork) {
                    tempWork = totalMinutes;
                    if (isSmartMode) {
                      tempBreak = (tempWork / 5).round().clamp(1, 60);
                    }
                  } else {
                    tempBreak = totalMinutes;
                  }
                });
              }
            }

            return AlertDialog(
              title: const Text("Timer Settings"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text("Smart Break"),
                      subtitle: const Text("1:5 Ratio (Auto)"),
                      value: isSmartMode,
                      onChanged: (val) {
                        setStateDialog(() {
                          isSmartMode = val;
                          if (val)
                            tempBreak = (tempWork / 5).round().clamp(1, 60);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTimePickerField(
                      context: context,
                      label: "Study Duration",
                      minutes: tempWork,
                      enabled: true,
                      onTap: () => pickTime(true),
                    ),
                    const SizedBox(height: 16),
                    _buildTimePickerField(
                      context: context,
                      label: "Break Duration",
                      minutes: tempBreak,
                      enabled: !isSmartMode,
                      onTap: () => pickTime(false),
                    ),
                    const Divider(height: 32),
                    SwitchListTile(
                        title: const Text("Sound"),
                        value: tempSound,
                        onChanged: (v) => setStateDialog(() => tempSound = v)),
                    SwitchListTile(
                        title: const Text("Vibrate"),
                        value: tempVibration,
                        onChanged: (v) =>
                            setStateDialog(() => tempVibration = v)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    _saveSettings(
                        work: tempWork,
                        breakTime: tempBreak,
                        sound: tempSound,
                        vibration: tempVibration,
                        isSmart: isSmartMode);
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimePickerField({
    required BuildContext context,
    required String label,
    required int minutes,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    String text = h > 0 ? "${h}h ${m}m" : "${m}m";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: !enabled,
          fillColor:
              enabled ? null : (isDark ? Colors.white10 : Colors.grey[200]),
          suffixIcon: const Icon(Icons.touch_app, size: 20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Theme.of(context).disabledColor, // Correct disabled color
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showCompletionDialog() {
    // 1. Record session automatically (Increment Only)
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text("You were working on:",
                          style:
                              TextStyle(fontSize: 12, color: Colors.blue[800])),
                      const SizedBox(height: 4),
                      Text(
                        _linkedTask!.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                            child: const Text("Not Done"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            onPressed: () {
                              // 2. Mark done only (No increment)
                              _updateTaskProgress(
                                  markCompleted: true, incrementSession: false);
                              _stopFeedback();
                              Navigator.pop(context);
                              _switchMode(!_isWorkMode);
                            },
                            child: const Text("Mark Done",
                                style: TextStyle(color: Colors.white)),
                          ),
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
                    child: const Text("Switch Mode"),
                  ),
                  TextButton(
                    onPressed: () {
                      _stopFeedback();
                      Navigator.pop(context);
                    },
                    child: const Text("Stay Here"),
                  ),
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
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.task_alt,
                                size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text(
                              "No incomplete tasks for today!",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _todaysTasks.length,
                        itemBuilder: (context, index) {
                          final task = _todaysTasks[index];
                          return ListTile(
                            leading: const Icon(Icons.circle_outlined),
                            title: Text(task.title),
                            onTap: () {
                              setState(() => _linkedTask = task);
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

  Widget _buildModeButton(String label, bool isWork) {
    final bool isSelected = _isWorkMode == isWork;
    return GestureDetector(
      onTap: () => _confirmSwitch(isWork),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isWork ? workColor : breakColor)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentColor = _isWorkMode ? workColor : breakColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Pomodoro Timer",
            style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: theme.iconTheme,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings), onPressed: _showSettingsDialog)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildModeButton("Work", true)),
                  Expanded(child: _buildModeButton("Break", false)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // LINKED TASK INDICATOR (Safe & Interactive)
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
                        child: Text(
                          _linkedTask?.title ?? "Link a Task",
                          style: TextStyle(
                              color: _linkedTask != null
                                  ? currentColor
                                  : Colors.grey,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // TIMER VISUALIZATION
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
                        Text(
                          _formatTime(count.ceil()),
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          _isWorkMode ? "Focus Time" : "Rest Time",
                          style: TextStyle(
                              fontSize: 18,
                              color: currentColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const Spacer(),

            // CONTROLS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh),
                  iconSize: 32,
                  color: Colors.grey,
                ),
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
                            offset: const Offset(0, 5)),
                      ],
                    ),
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
