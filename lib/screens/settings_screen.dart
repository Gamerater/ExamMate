import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../utils/constants.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentExam = "Loading...";
  String _currentDateDisplay = "";
  bool _isCustomExam = false;

  bool _isDarkTheme = false;
  bool _showStreak = true;
  bool _isReminderEnabled = false;

  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      final savedExam = prefs.getString('selected_exam') ?? "Not Selected";
      _currentExam = savedExam;
      _isCustomExam = !AppConstants.availableExams.contains(savedExam);

      final String? dateStr = prefs.getString('exam_date');
      if (dateStr != null) {
        final date = DateTime.parse(dateStr);
        _currentDateDisplay = "${date.day}/${date.month}/${date.year}";
      } else {
        _currentDateDisplay = "Not Set";
      }

      _isDarkTheme = prefs.getBool('is_dark_mode') ?? false;
      _showStreak = prefs.getBool('show_streak') ?? true;
      _isReminderEnabled = prefs.getBool('daily_reminder') ?? false;

      final int hour = prefs.getInt('reminder_hour') ?? 20;
      final int minute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);

    if (!mounted) return;
    setState(() => _isDarkTheme = isDark);
    ExamMateApp.themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // --- SAFE TOGGLE LOGIC ---
  Future<void> _toggleReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationService = NotificationService();

    if (value) {
      bool granted = await notificationService.requestPermissions();

      if (!mounted) return;

      if (granted) {
        try {
          await notificationService.scheduleDailyReminder(
              _reminderTime.hour, _reminderTime.minute);

          await prefs.setBool('daily_reminder', true);

          if (!mounted) return;
          setState(() => _isReminderEnabled = true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Reminder set for ${_reminderTime.format(context)} daily!"),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          debugPrint("Error scheduling reminder: $e");
          if (mounted) setState(() => _isReminderEnabled = false);
        }
      } else {
        setState(() => _isReminderEnabled = false);
        if (mounted) _showPermissionDeniedDialog();
      }
    } else {
      try {
        await notificationService.cancelNotifications();
      } catch (e) {
        debugPrint("Error cancelling notifications: $e");
      }

      await prefs.setBool('daily_reminder', false);

      if (!mounted) return;
      setState(() => _isReminderEnabled = false);
    }
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              dialHandColor: Colors.deepOrange,
              hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.deepOrange
                      : Colors.grey),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt('reminder_hour', picked.hour);
      await prefs.setInt('reminder_minute', picked.minute);

      if (!mounted) return;
      setState(() => _reminderTime = picked);

      if (_isReminderEnabled) {
        final service = NotificationService();
        try {
          await service.cancelNotifications();
          await service.scheduleDailyReminder(picked.hour, picked.minute);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Reminder rescheduled!")),
            );
          }
        } catch (e) {
          debugPrint("Error rescheduling reminder: $e");
        }
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications Disabled"),
        content: const Text(
          "To receive study reminders, please enable notifications for ExamMate in your phone settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickNewDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('exam_date', picked.toIso8601String());

      if (!mounted) return;
      setState(() {
        _currentDateDisplay = "${picked.day}/${picked.month}/${picked.year}";
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Exam date updated!")));
    }
  }

  // --- RESET LOGIC ---
  Future<void> _confirmReset() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Start Fresh?"),
          content: const Text(
              "This will clear your daily tasks, streak count, and history.\n\nYour exam goal and settings will be saved.\n\nThis action cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset Everything'),
              onPressed: () {
                Navigator.of(context).pop();
                _performReset();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performReset() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear specific keys (SAFE RESET)
    await prefs.remove('tasks_data');
    await prefs.remove('streak_current');
    await prefs.remove('streak_best');
    await prefs.remove('streak_last_date');
    await prefs.remove('streak_shields');
    await prefs.remove('streak_history');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You have a clean slate. Let's begin again."),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 3),
      ),
    );

    // Redirect to home/dashboard to refresh state
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  Future<void> _showConfirmationDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
              child: ListBody(children: <Widget>[Text(content)])),
          actions: <Widget>[
            TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
                child: const Text('Confirm'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final iconColor = theme.iconTheme.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: iconColor),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildSectionHeader(
              title: 'Exam Preferences',
              description: 'Manage your target goal'),
          _buildSectionContainer(
            children: [
              _buildSettingsTile(
                icon: Icons.edit_calendar,
                iconColor: Colors.blue,
                title: 'Change Exam Goal',
                subtitle:
                    _isCustomExam ? "$_currentExam (Custom)" : _currentExam,
                onTap: () {
                  _showConfirmationDialog(
                    title: 'Change Exam?',
                    content:
                        'Changing your exam goal will update your dashboard target.',
                    onConfirm: () => Navigator.pushNamed(context, '/exam'),
                  );
                },
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.event,
                iconColor: Colors.orange,
                title: 'Edit Exam Date',
                subtitle: _currentDateDisplay,
                onTap: () {
                  _showConfirmationDialog(
                    title: 'Update Deadline?',
                    content: 'This will recalculate the "Days Left" countdown.',
                    onConfirm: _pickNewDate,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
              title: 'App Preferences', description: 'Customize behavior'),
          _buildSectionContainer(
            children: [
              _buildSettingsTile(
                icon: Icons.notifications_active,
                iconColor: Colors.purple,
                title: 'Daily Reminders',
                trailing: Switch(
                  value: _isReminderEnabled,
                  onChanged: _toggleReminder,
                  activeThumbColor: Colors.purple,
                ),
              ),
              if (_isReminderEnabled) ...[
                Padding(
                  padding:
                      const EdgeInsets.only(left: 60, right: 16, bottom: 8),
                  child: GestureDetector(
                    onTap: _pickReminderTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Reminder Time",
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600])),
                          Row(
                            children: [
                              Text(_reminderTime.format(context),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor)),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit,
                                  size: 14, color: Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.local_fire_department,
                iconColor: Colors.deepOrange,
                title: 'Show Streak',
                showComingSoon: true,
                trailing: Switch(
                    value: _showStreak,
                    onChanged: (val) => setState(() => _showStreak = val),
                    activeThumbColor: Colors.deepOrange),
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.dark_mode,
                iconColor: Colors.indigo,
                title: 'Dark Mode',
                trailing: Switch(
                  value: _isDarkTheme,
                  onChanged: _toggleTheme,
                  activeThumbColor: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
              title: 'Data & Reset', description: 'Manage your progress'),
          _buildSectionContainer(
            children: [
              _buildSettingsTile(
                icon: Icons.refresh,
                iconColor: Colors.redAccent,
                title: 'Reset Tasks & Streak',
                onTap: _confirmReset,
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
              title: 'About', description: 'App info and legal'),
          _buildSectionContainer(
            children: [
              _buildSettingsTile(
                icon: Icons.info,
                iconColor: Colors.teal,
                title: 'Version',
                trailing: const Text('1.0.0',
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.w500)),
                onTap: null,
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.privacy_tip,
                iconColor: Colors.grey,
                title: 'Privacy Policy',
                onTap: () => Navigator.pushNamed(context, '/privacy'),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Center(
              child: Text('Made with ❤️ for Students',
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, String? description}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.2)),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400))
          ],
        ],
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    final theme = Theme.of(context);
    return Divider(
        height: 1, thickness: 0.5, color: theme.dividerColor, indent: 60);
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showComingSoon = false,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color)),
          if (showComingSoon) ...[
            const SizedBox(width: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade100)),
                child: const Text('SOON',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange)))
          ],
        ],
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))
          : null,
      trailing: trailing ??
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[300]),
      onTap: onTap,
    );
  }
}
