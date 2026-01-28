import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ExamSelectionScreen extends StatefulWidget {
  const ExamSelectionScreen({super.key});

  @override
  State<ExamSelectionScreen> createState() => _ExamSelectionScreenState();
}

class _ExamSelectionScreenState extends State<ExamSelectionScreen> {
  final List<String> _exams = [...AppConstants.availableExams, 'Other'];

  String? _selectedExam;
  DateTime? _selectedDate;

  final TextEditingController _customExamController = TextEditingController();
  bool _isOtherSelected = false;
  String? _customNameError;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedExam = prefs.getString('selected_exam');
      final String? storedDate = prefs.getString('exam_date');

      if (storedExam != null && storedDate != null) {
        // FIX: Use tryParse to prevent crash if data is corrupted
        final parsedDate = DateTime.tryParse(storedDate);

        if (mounted && parsedDate != null) {
          setState(() {
            _selectedDate = parsedDate;

            if (_exams.contains(storedExam)) {
              _selectedExam = storedExam;
              _isOtherSelected = false;
            } else {
              _selectedExam = 'Other';
              _isOtherSelected = true;
              _customExamController.text = storedExam;
            }
          });
        }
      }
    } catch (e) {
      // Safely ignore storage errors - app will just show empty state
      debugPrint("Error loading existing data: $e");
    }
  }

  @override
  void dispose() {
    _customExamController.dispose();
    super.dispose();
  }

  // --- NEW HELPER: HUMAN READABLE DATE ---
  // Converts "2026-05-10" to "10 May 2026"
  String _formatDate(DateTime date) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _validateCustomExamName(String value) {
    String trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() => _customNameError = "Exam name cannot be empty");
      return;
    }

    if (trimmed.length > 30) {
      setState(() => _customNameError = "Keep it under 30 characters");
      return;
    }

    final validCharacters = RegExp(r'^[a-zA-Z0-9 .-]+$');
    if (!validCharacters.hasMatch(trimmed)) {
      setState(() => _customNameError = "No special characters (@, #, etc.)");
      return;
    }

    setState(() => _customNameError = null);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // FIX: Strip time to ensure clean comparisons and UI behavior
    final firstDate = DateTime(now.year, now.month, now.day);

    // FIX: Ensure lastDate is valid relative to firstDate
    // If we pass 2030, this dynamic check prevents a crash.
    DateTime lastDate = DateTime(2030);
    if (lastDate.isBefore(firstDate)) {
      lastDate = firstDate.add(const Duration(days: 365 * 5));
    }

    // FIX: Calculate initialDate carefully to avoid "initialDate must be on or after firstDate" crash
    // If saved date is in the past, reset picker to today.
    DateTime initialDate =
        _selectedDate ?? firstDate.add(const Duration(days: 90));

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }
    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white)
                : const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool get _isFormValid {
    if (_selectedDate == null) return false;
    if (_selectedExam == null) return false;

    if (_isOtherSelected) {
      return _customExamController.text.trim().isNotEmpty &&
          _customNameError == null;
    }

    return true;
  }

  Future<void> _saveAndContinue() async {
    // Defensive check
    if (_selectedExam == null) return;

    if (_isOtherSelected) {
      _validateCustomExamName(_customExamController.text);
      if (_customNameError != null) return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      String finalExamName = _selectedExam!;

      if (_isOtherSelected) {
        finalExamName = _customExamController.text.trim();
      }

      await prefs.setString('selected_exam', finalExamName);

      // _selectedDate is checked in _isFormValid, but purely safe coding:
      if (_selectedDate != null) {
        await prefs.setString('exam_date', _selectedDate!.toIso8601String());
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // Log error or show snackbar if needed
      debugPrint("Error saving data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Goal'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Which exam are you preparing for?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedExam,
                    hint: const Text('Choose an Exam'),
                    isExpanded: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                    dropdownColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    items: _exams.map((String exam) {
                      return DropdownMenuItem<String>(
                        value: exam,
                        child: Text(exam),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedExam = newValue;
                        _isOtherSelected = newValue == 'Other';
                        if (!_isOtherSelected) {
                          _customExamController.clear();
                          _customNameError = null;
                        }
                      });
                    },
                  ),
                ),
              ),
              if (_isOtherSelected) ...[
                const SizedBox(height: 15),
                TextField(
                  controller: _customExamController,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Enter Custom Exam Name',
                    hintText: 'e.g. CA Final, GATE 2026',
                    errorText: _customNameError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  onChanged: (value) {
                    _validateCustomExamName(value);
                  },
                ),
              ],
              const SizedBox(height: 30),
              const Text(
                'When is your exam?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: Icon(Icons.calendar_today,
                    color: Colors.blue.withOpacity(0.8), size: 22),
                label: Text(
                  _selectedDate == null
                      ? 'Select Exam Date'
                      : _formatDate(_selectedDate!), // USES NEW HELPER
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[200] : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  side: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isFormValid ? _saveAndContinue : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor:
                      isDark ? Colors.grey[800] : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Continue',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
