import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentExam = "Loading...";
  String _currentDateDisplay = "";

  // Placeholder states for UI toggles
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
      _currentExam = prefs.getString('selected_exam') ?? "Not Selected";

      final String? dateStr = prefs.getString('exam_date');
      if (dateStr != null) {
        final date = DateTime.parse(dateStr);
        _currentDateDisplay = "${date.day}/${date.month}/${date.year}";
      } else {
        _currentDateDisplay = "Not Set";
      }
    });
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

      setState(() {
        _currentDateDisplay = "${picked.day}/${picked.month}/${picked.year}";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exam date updated!")),
        );
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
            child: ListBody(
              children: <Widget>[
                Text(content),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // --- SECTION 1: EXAM ---
          _buildSectionHeader(
            title: 'Exam Preferences',
            description: 'Manage your target goal and timeline',
          ),
          _buildSectionContainer(
            children: [
              _buildSettingsTile(
                icon: Icons.edit_calendar,
                iconColor: Colors.blue,
                title: 'Change Exam Goal',
                subtitle: _currentExam,
                onTap: () {
                  _showConfirmationDialog(
                    title: 'Change Exam?',
                    content:
                        'Changing your exam goal will update your dashboard target. Your current tasks will remain saved.',
                    onConfirm: () {
                      Navigator.pushNamed(context, '/exam');
                    },
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
                    content:
                        'This will recalculate the "Days Left" countdown on your dashboard.',
                    onConfirm: () {
                      _pickNewDate();
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- SECTION 2: APP PREFERENCES (PLACEHOLDERS) ---
          _buildSectionHeader(
            title: 'App Preferences',
            description: 'Customize behavior (Coming Soon)',
          ),
          _buildSectionContainer(
            children: [
              // 1. Notifications (Disabled)
              _buildSettingsTile(
                icon: Icons.notifications_active,
                iconColor: Colors.purple,
                title: 'Daily Reminders',
                showComingSoon: true, // Shows badge
                trailing: Switch(
                  value: false,
                  onChanged: null, // Disabled switch
                  activeColor: Colors.blue,
                ),
              ),
              _buildDivider(),

              // 2. Streak Toggle (UI Only)
              _buildSettingsTile(
                icon: Icons.local_fire_department,
                iconColor: Colors.deepOrange,
                title: 'Show Streak',
                showComingSoon: true,
                trailing: Switch(
                  value: _showStreak,
                  onChanged: (val) {
                    setState(() => _showStreak = val);
                    _showComingSoonToast();
                  },
                  activeColor: Colors.deepOrange,
                ),
              ),
              _buildDivider(),

              // 3. Dark Mode (UI Only)
              _buildSettingsTile(
                icon: Icons.dark_mode,
                iconColor: Colors.indigo,
                title: 'Dark Mode',
                showComingSoon: true,
                trailing: Switch(
                  value: _isDarkTheme,
                  onChanged: (val) {
                    setState(() => _isDarkTheme = val);
                    _showComingSoonToast();
                  },
                  activeColor: Colors.indigo,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- SECTION 3: ABOUT ---
          _buildSectionHeader(
            title: 'About',
            description: 'App info and legal',
          ),
          _buildSectionContainer(
            children: [
              _buildSettingsTile(
                icon: Icons.info,
                iconColor: Colors.teal,
                title: 'Version',
                trailing: const Text(
                  '1.0.0',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                onTap: null,
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.privacy_tip,
                iconColor: Colors.grey,
                title: 'Privacy Policy',
                onTap: () {
                  // TODO: Open Privacy Policy
                },
              ),
            ],
          ),

          const SizedBox(height: 40),

          const Center(
            child: Text(
              'Made with ❤️ for Students',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- UI HELPER METHODS ---

  void _showComingSoonToast() {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("This feature is coming soon!"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, String? description}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              letterSpacing: 1.2,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey[200],
      indent: 60,
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showComingSoon = false, // New parameter
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          if (showComingSoon) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: const Text(
                'SOON',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
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
