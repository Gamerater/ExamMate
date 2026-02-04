import 'dart:convert';

// Enum for Effort Level
enum TaskEffort { quick, medium, deep }

class Task {
  // --- CORE FIELDS ---
  String id;
  String title;
  bool isCompleted;
  DateTime date;

  // --- NEW FEATURES ---
  String note;
  TaskEffort effort;

  // Track focus sessions (Simple counter)
  int sessionsCompleted;

  // --- EXISTING FIELDS ---
  String label;
  int colorValue;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.date,
    this.note = '',
    this.effort = TaskEffort.medium,
    this.sessionsCompleted = 0,
    this.label = 'General',
    this.colorValue = 0xFF2196F3,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'date': date.toIso8601String(),
      'note': note,
      'effort': effort.index,
      'sessionsCompleted': sessionsCompleted,
      'label': label,
      'colorValue': colorValue,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    TaskEffort parseEffort(dynamic mapVal, String? oldPriority) {
      if (mapVal != null && mapVal is int) {
        // FIX: Bounds check to prevent RangeError crash
        if (mapVal >= 0 && mapVal < TaskEffort.values.length) {
          return TaskEffort.values[mapVal];
        }
      }
      if (oldPriority == 'High') return TaskEffort.deep;
      if (oldPriority == 'Low') return TaskEffort.quick;
      return TaskEffort.medium;
    }

    return Task(
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? 'Untitled Task',
      isCompleted: map['isCompleted'] == true,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      note: map['note']?.toString() ?? '',
      effort: parseEffort(map['effort'], map['priority']?.toString()),
      // FIX: Use 'num' to handle both int and double from JSON, then cast safely
      sessionsCompleted: (map['sessionsCompleted'] is num)
          ? (map['sessionsCompleted'] as num).toInt()
          : 0,
      label: map['label']?.toString() ?? 'General',
      // FIX: Use 'num' for safety, fallback to default blue if parsing fails
      colorValue: (map['colorValue'] is num)
          ? (map['colorValue'] as num).toInt()
          : 0xFF2196F3,
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) {
    // FIX: Try/Catch to prevent crash on malformed JSON or empty strings
    try {
      final decoded = json.decode(source);
      if (decoded is Map<String, dynamic>) {
        return Task.fromMap(decoded);
      }
    } catch (e) {
      // Log error internally if needed, but do not crash UI
      // print('Error parsing Task: $e');
    }

    // Return a safe fallback task to keep app alive
    return Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Error loading task',
      date: DateTime.now(),
    );
  }
}
