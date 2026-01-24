import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _examName = "Loading...";
  int _daysLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadExamData();
  }

  Future<void> _loadExamData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedExam = prefs.getString('selected_exam') ?? "General Exam";

    // Dynamic date lookup
    final DateTime targetDate =
        AppConstants.examDates[savedExam] ?? DateTime(2026, 5, 20);

    final now = DateTime.now();
    final difference = targetDate.difference(now).inDays;

    if (mounted) {
      setState(() {
        _examName = savedExam;
        _daysLeft = difference > 0 ? difference : 0; // Prevent negative days
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'Target: $_examName',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 10),
                    const Text('Time Remaining',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 5),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_daysLeft',
                            style: const TextStyle(
                              fontSize: 48, 
                              fontWeight: FontWeight.w900, 
                              color: Colors.blueAccent,
                            ),
                          ),
                          const TextSpan(
                            text: ' Days',
                            style: TextStyle(
                              fontSize: 18, 
                              color: Colors.grey, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text('Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildActionButton(
              icon: Icons.check_circle_outline,
              label: 'Daily Tasks',
              color: Colors.green,
              onTap: () => Navigator.pushNamed(context, '/tasks'),
            ),
            const SizedBox(height: 15),
            _buildActionButton(
              icon: Icons.bar_chart,
              label: 'My Progress',
              color: Colors.purple,
              onTap: () => Navigator.pushNamed(context, '/progress'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 28, color: Colors.white),
      label: Text(label,
          style: const TextStyle(fontSize: 18, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
