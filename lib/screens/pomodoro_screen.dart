import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // Required for FontFeature

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
        setState(() => _isRunning = false);
        _showCompletionDialog();
      }
    });

    _loadSettings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- LOGIC: SETTINGS & PERSISTENCE ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _workDuration = prefs.getInt('pomo_work_minutes') ?? 25;
        _breakDuration = prefs.getInt('pomo_break_minutes') ?? 5;
        _updateControllerDuration();
      });
    }
  }

  Future<void> _saveSettings(int work, int breakTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomo_work_minutes', work);
    await prefs.setInt('pomo_break_minutes', breakTime);

    if (mounted) {
      setState(() {
        _workDuration = work;
        _breakDuration = breakTime;
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
    final TextEditingController workController =
        TextEditingController(text: _workDuration.toString());
    final TextEditingController breakController =
        TextEditingController(text: _breakDuration.toString());

    bool isSmartMode = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void updateSmartBreak(String value) {
              if (isSmartMode) {
                int? workTime = int.tryParse(value);
                if (workTime != null && workTime > 0) {
                  int smartBreak = (workTime / 5).round();
                  if (smartBreak < 1) smartBreak = 1;
                  breakController.text = smartBreak.toString();
                }
              }
            }

            return AlertDialog(
              title: const Text("Timer Settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSmartMode
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSmartMode
                          ? Border.all(color: Colors.blue.withOpacity(0.3))
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 18,
                                color: isSmartMode ? Colors.blue : Colors.grey),
                            const SizedBox(width: 8),
                            Text("Smart Break",
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSmartMode
                                        ? Colors.blue
                                        : (isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700]))),
                          ],
                        ),
                        Switch(
                          value: isSmartMode,
                          activeColor: Colors.blue,
                          onChanged: (val) {
                            setStateDialog(() {
                              isSmartMode = val;
                              if (val) updateSmartBreak(workController.text);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: workController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Study Duration (minutes)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work, color: workColor),
                    ),
                    onChanged: (val) => updateSmartBreak(val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: breakController,
                    keyboardType: TextInputType.number,
                    enabled: !isSmartMode,
                    decoration: InputDecoration(
                      labelText: isSmartMode
                          ? "Auto-Calculated Break"
                          : "Break Duration",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.coffee, color: breakColor),
                      filled: isSmartMode,
                      // FIX: Dark mode specific fill color
                      fillColor: isSmartMode
                          ? (isDark ? Colors.grey[800] : Colors.grey[100])
                          : null,
                    ),
                  ),
                  if (isSmartMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Break adjusted automatically (1:5 ratio)",
                        style: TextStyle(fontSize: 12, color: Colors.blue[300]),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final int? w = int.tryParse(workController.text);
                    final int? b = int.tryParse(breakController.text);
                    if (w != null && b != null && w > 0 && b > 0) {
                      _saveSettings(w, b);
                      Navigator.pop(context);
                    }
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
            icon: const Icon(Icons.edit),
            onPressed: _showSettingsDialog,
            tooltip: "Edit Durations",
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TOGGLE BUTTONS
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

            // CIRCULAR TIMER - ANIMATED BUILDER FOR SMOOTHNESS
            GestureDetector(
              onTap: _showSettingsDialog,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Calculate time based on controller value
                  // controller goes 1.0 -> 0.0
                  // Duration * value = remaining time
                  final count =
                      _controller.duration!.inSeconds * _controller.value;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: CircularProgressIndicator(
                          value:
                              _controller.value, // Smooth float value (60fps)
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
                            _formatTime(
                                count.ceil()), // Rounds up for timer display
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
      onTap: () => _switchMode(isWork),
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
