import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import main.dart to access themeNotifier
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentExam = "Loading...";
  String _currentDateDisplay = "";
  bool _isCustomExam = false;

  // State for toggles
  bool _isDarkTheme = false;
  bool _showStreak = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
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

      // Load Dark Mode State
      _isDarkTheme = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);

    setState(() {
      _isDarkTheme = isDark;
    });

    // Update the Global App Theme immediately
    ExamMateApp.themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // ... (Keep existing helpers: _pickNewDate, _showConfirmationDialog) ...
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
      setState(() {
        _currentDateDisplay = "${picked.day}/${picked.month}/${picked.year}";
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Exam date updated!")));
      }
    }
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
    // Access current theme colors for dynamic UI
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
          // --- SECTION 1 ---
          _buildSectionHeader(
              title: 'Exam Preferences',
              description: 'Manage your target goal and timeline'),
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

          // --- SECTION 2 ---
          _buildSectionHeader(
              title: 'App Preferences', description: 'Customize behavior'),
          _buildSectionContainer(
            children: [
              _buildSettingsTile(
                icon: Icons.notifications_active,
                iconColor: Colors.purple,
                title: 'Daily Reminders',
                showComingSoon: true, // Still coming soon
                trailing: Switch(
                    value: false, onChanged: null, activeColor: Colors.blue),
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.local_fire_department,
                iconColor: Colors.deepOrange,
                title: 'Show Streak',
                showComingSoon: true, // Still coming soon
                trailing: Switch(
                    value: _showStreak,
                    onChanged: (val) => setState(() => _showStreak = val),
                    activeColor: Colors.deepOrange),
              ),
              _buildDivider(),

              // --- DARK MODE (ACTIVE) ---
              _buildSettingsTile(
                icon: Icons.dark_mode,
                iconColor: Colors.indigo,
                title: 'Dark Mode',
                showComingSoon: false, // REMOVED BADGE
                trailing: Switch(
                  value: _isDarkTheme,
                  onChanged: _toggleTheme, // CONNECTED LOGIC
                  activeColor: Colors.indigo,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- SECTION 3 ---
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
                onTap: () {},
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

  // --- UI HELPER METHODS ---
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
        color: theme.cardColor, // Dynamic Background
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
                      color: Colors.orange)),
            ),
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
