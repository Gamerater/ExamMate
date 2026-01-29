import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  // Constants
  static const Color workColor = Colors.deepPurpleAccent;
  static const Color breakColor = Colors.green;

  // State Variables
  Timer? _timer;
  bool _isWorkMode = true;
  bool _isRunning = false;

  // Durations (in minutes) - Default values
  int _workDuration = 25;
  int _breakDuration = 5;

  // Timer Logic
  int _remainingSeconds = 25 * 60;
  int _totalSeconds = 25 * 60;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LOGIC: SETTINGS & PERSISTENCE ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workDuration = prefs.getInt('pomo_work_minutes') ?? 25;
      _breakDuration = prefs.getInt('pomo_break_minutes') ?? 5;
      _resetTimer(); // Apply loaded settings
    });
  }

  Future<void> _saveSettings(int work, int breakTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomo_work_minutes', work);
    await prefs.setInt('pomo_break_minutes', breakTime);

    setState(() {
      _workDuration = work;
      _breakDuration = breakTime;
      _isRunning = false;
      _timer?.cancel();
      _resetTimer();
    });
  }

  // --- LOGIC: TIMER CONTROL ---
  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _timer?.cancel();
          setState(() => _isRunning = false);
          // Optional: Add simple vibration or sound logic here later
          _showCompletionDialog();
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      // Set time based on current mode
      int minutes = _isWorkMode ? _workDuration : _breakDuration;
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _switchMode(bool isWork) {
    if (_isWorkMode == isWork) return; // No change
    setState(() {
      _isWorkMode = isWork;
      _resetTimer();
    });
  }

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
              _switchMode(!_isWorkMode); // Auto-switch mode
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Timer Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: workController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Work Duration (minutes)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: breakController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Break Duration (minutes)",
                border: OutlineInputBorder(),
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
      ),
    );
  }

  String _formatTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentColor = _isWorkMode ? workColor : breakColor;
    final double progress =
        _totalSeconds == 0 ? 0 : _remainingSeconds / _totalSeconds;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. TOGGLE BUTTONS
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

            // 2. CIRCULAR TIMER
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: progress,
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
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ], // Keeps numbers width consistent
                      ),
                    ),
                    Text(
                      _isWorkMode ? "Focus Time" : "Relax Time",
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

            const Spacer(),

            // 3. CONTROLS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset Button
                IconButton(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh),
                  iconSize: 32,
                  color: Colors.grey,
                ),
                const SizedBox(width: 32),
                // Play/Pause Button
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
                const SizedBox(width: 80), // Balance the spacing
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
