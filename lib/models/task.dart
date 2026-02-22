import 'dart:convert';

// Enum for Effort Level
enum TaskEffort { quick, medium, deep }

class Task {
  // --- CORE FIELDS ---
  String id;
  String title;
  bool isCompleted;
  DateTime date;

  // --- METADATA ---
  String note;
  TaskEffort effort;
  int sessionsCompleted;

  // NEW: Subject Tag
  String? subject;

  // --- TIME-BOUND FEATURES ---
  DateTime? deadline;
  bool isTemporary;

  // --- LEGACY FIELDS ---
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
    this.subject, // New
    this.deadline,
    this.isTemporary = false,
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
      'subject': subject, // New
      'deadline': deadline?.toIso8601String(),
      'isTemporary': isTemporary,
      'label': label,
      'colorValue': colorValue,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    TaskEffort parseEffort(dynamic mapVal, String? oldPriority) {
      if (mapVal != null && mapVal is int) {
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
      sessionsCompleted: (map['sessionsCompleted'] is num)
          ? (map['sessionsCompleted'] as num).toInt()
          : 0,

      // NEW: Safely parse subject (backward compatible)
      subject: map['subject']?.toString(),

      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'].toString())
          : null,
      isTemporary: map['isTemporary'] == true,

      label: map['label']?.toString() ?? 'General',
      colorValue: (map['colorValue'] is num)
          ? (map['colorValue'] as num).toInt()
          : 0xFF2196F3,
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) {
    try {
      final decoded = json.decode(source);
      if (decoded is Map<String, dynamic>) {
        return Task.fromMap(decoded);
      }
    } catch (e) {
      // Fallback
    }

    return Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Error loading task',
      date: DateTime.now(),
    );
  }
}
