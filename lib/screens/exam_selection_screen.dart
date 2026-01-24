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
  String? _customNameError; // Stores the error message

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedExam = prefs.getString('selected_exam');
    final String? storedDate = prefs.getString('exam_date');

    if (storedExam != null && storedDate != null) {
      if (mounted) {
        setState(() {
          _selectedDate = DateTime.parse(storedDate);

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
  }

  @override
  void dispose() {
    _customExamController.dispose();
    super.dispose();
  }

  // --- VALIDATION LOGIC ---
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

    // Allow alphanumeric, spaces, dashes, and periods.
    // Blocks emojis and special symbols that might break UI.
    final validCharacters = RegExp(r'^[a-zA-Z0-9 .-]+$');
    if (!validCharacters.hasMatch(trimmed)) {
      setState(() => _customNameError = "No special characters (@, #, etc.)");
      return;
    }

    // Valid
    setState(() => _customNameError = null);
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
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
      // Must be non-empty AND have no validation errors
      return _customExamController.text.trim().isNotEmpty &&
          _customNameError == null;
    }

    return true;
  }

  Future<void> _saveAndContinue() async {
    // Final check before saving
    if (_isOtherSelected) {
      _validateCustomExamName(_customExamController.text);
      if (_customNameError != null) return;
    }

    final prefs = await SharedPreferences.getInstance();

    String finalExamName = _selectedExam!;

    if (_isOtherSelected) {
      finalExamName = _customExamController.text.trim();
    }

    await prefs.setString('selected_exam', finalExamName);
    await prefs.setString('exam_date', _selectedDate!.toIso8601String());

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          _customNameError =
                              null; // Clear error if switching away
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
                  decoration: InputDecoration(
                    labelText: 'Enter Custom Exam Name',
                    hintText: 'e.g. CA Final, GATE 2026',
                    errorText: _customNameError, // Shows error message here
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  onChanged: (value) {
                    _validateCustomExamName(value); // Live validation
                  },
                ),
              ],
              const SizedBox(height: 30),
              const Text(
                'When is your exam?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, color: Colors.blue),
                label: Text(
                  _selectedDate == null
                      ? 'Select Exam Date'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isFormValid ? _saveAndContinue : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey.shade300,
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
