import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED for HapticFeedback
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // Required for FontFeature
import 'package:audioplayers/audioplayers.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  // Constants
  static const Color workColor = Colors.deepPurpleAccent;
  static const Color breakColor = Colors.green;

  // State Variables
  late AnimationController _controller;
  bool _isWorkMode = true;
  bool _isRunning = false;

  // Durations (in minutes)
  int _workDuration = 25;
  int _breakDuration = 5;

  // Feedback Preferences
  bool _enableSound = true;
  bool _enableVibration = true;

  // Audio Player
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Initialize controller (default 25 mins)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 25),
    );

    // Listen for timer finish
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        // Timer Finished Naturally
        setState(() => _isRunning = false);
        _triggerFeedback();
        _showCompletionDialog();
      }
    });

    _loadSettings();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- LOGIC: SETTINGS & PERSISTENCE ---
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

  Future<void> _saveSettings({
    required int work,
    required int breakTime,
    required bool sound,
    required bool vibration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomo_work_minutes', work);
    await prefs.setInt('pomo_break_minutes', breakTime);
    await prefs.setBool('pomo_sound_enabled', sound);
    await prefs.setBool('pomo_vibration_enabled', vibration);

    if (mounted) {
      setState(() {
        _workDuration = work;
        _breakDuration = breakTime;
        _enableSound = sound;
        _enableVibration = vibration;

        // If editing while running, stop and reset
        if (_isRunning) {
          _controller.stop();
          _isRunning = false;
        }
        _updateControllerDuration();
      });
    }
  }

  void _updateControllerDuration() {
    int minutes = _isWorkMode ? _workDuration : _breakDuration;
    _controller.duration = Duration(minutes: minutes);
    _controller.value = 1.0; // Reset progress to full
  }

  // --- LOGIC: FEEDBACK ---
  Future<void> _triggerFeedback() async {
    // 1. Vibration (Using Native HapticFeedback - Safe for Android Build)
    if (_enableVibration) {
      // "Heavy Impact" simulates a strong vibration tick
      // We trigger it twice for a distinct "alert" feel without external plugins
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    }

    // 2. Sound
    if (_enableSound) {
      try {
        // Ensure 'assets/sounds/bell.mp3' is in pubspec.yaml
        await _audioPlayer.play(AssetSource('sounds/bell.mp3'));
      } catch (e) {
        debugPrint("Error playing sound: $e");
      }
    }
  }

  // --- LOGIC: TIMER CONTROL ---
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
    _controller.stop();
    _controller.value = 1.0; // Reset visual progress
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
        content: const Text(
            "The timer is currently running. Switching modes will stop and reset it."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
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

  // --- DIALOGS ---
  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isWorkMode ? "Great Focus!" : "Break Over!"),
        content: Text(_isWorkMode
            ? "Time to take a break?"
            : "Ready to get back to work?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _switchMode(!_isWorkMode);
            },
            child: const Text("Switch Mode"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Stay Here"),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    int tempWork = _workDuration;
    int tempBreak = _breakDuration;
    bool tempSound = _enableSound;
    bool tempVibration = _enableVibration;

    bool isSmartMode = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Helper for picking time
            Future<void> pickDuration(bool forWork) async {
              final initialMinutes = forWork ? tempWork : tempBreak;
              final initialTime = TimeOfDay(
                  hour: initialMinutes ~/ 60, minute: initialMinutes % 60);

              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: initialTime,
                initialEntryMode: TimePickerEntryMode.input,
                helpText:
                    forWork ? "SELECT WORK DURATION" : "SELECT BREAK DURATION",
                hourLabelText: "Hours",
                minuteLabelText: "Minutes",
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

                  if (forWork) {
                    tempWork = totalMinutes;
                    if (isSmartMode) {
                      tempBreak = (tempWork / 5).round();
                      if (tempBreak < 1) tempBreak = 1;
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
                    // Smart Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSmartMode
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSmartMode
                            ? Border.all(color: Colors.blue.withOpacity(0.3))
                            : Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 20,
                                  color:
                                      isSmartMode ? Colors.blue : Colors.grey),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Smart Break",
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSmartMode
                                              ? Colors.blue
                                              : (isDark
                                                  ? Colors.grey[300]
                                                  : Colors.grey[700]))),
                                  if (isSmartMode)
                                    Text("1:5 Ratio (Auto)",
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue[300])),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: isSmartMode,
                            activeColor: Colors.blue,
                            onChanged: (val) {
                              setStateDialog(() {
                                isSmartMode = val;
                                if (val) {
                                  tempBreak = (tempWork / 5).round();
                                  if (tempBreak < 1) tempBreak = 1;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Duration Selectors
                    _buildDurationTile(
                        label: "Work Duration",
                        minutes: tempWork,
                        icon: Icons.work,
                        color: workColor,
                        onTap: () => pickDuration(true)),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: isSmartMode ? 0.5 : 1.0,
                      child: _buildDurationTile(
                          label: isSmartMode ? "Auto Break" : "Break Duration",
                          minutes: tempBreak,
                          icon: Icons.coffee,
                          color: breakColor,
                          onTap:
                              isSmartMode ? null : () => pickDuration(false)),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Sound & Vibration Toggles
                    SwitchListTile(
                      title: const Text("Play Sound"),
                      subtitle: const Text("When timer ends"),
                      value: tempSound,
                      activeColor: Colors.blue,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setStateDialog(() => tempSound = val),
                    ),
                    SwitchListTile(
                      title: const Text("Vibrate"),
                      subtitle: const Text("When timer ends"),
                      value: tempVibration,
                      activeColor: Colors.blue,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) =>
                          setStateDialog(() => tempVibration = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveSettings(
                      work: tempWork,
                      breakTime: tempBreak,
                      sound: tempSound,
                      vibration: tempVibration,
                    );
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

  Widget _buildDurationTile({
    required String label,
    required int minutes,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeString = "${hours}h ${mins}m";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: isDark ? Colors.grey[800] : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(timeString,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.edit, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final int m = totalSeconds ~/ 60;
    final int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentColor = _isWorkMode ? workColor : breakColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Pomodoro Timer",
          style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: theme.iconTheme,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: "Settings",
          )
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
            const Spacer(),
            GestureDetector(
              onTap: _showSettingsDialog,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final count =
                      _controller.duration!.inSeconds * _controller.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: CircularProgressIndicator(
                          value: _controller.value,
                          strokeWidth: 15,
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
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                _isWorkMode ? "Focus" : "Rest",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: currentColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const Spacer(),
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
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRunning ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
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
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
