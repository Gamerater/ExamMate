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
        return TaskEffort.values[mapVal];
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
      sessionsCompleted:
          map['sessionsCompleted'] is int ? map['sessionsCompleted'] : 0,
      label: map['label']?.toString() ?? 'General',
      colorValue: (map['colorValue'] is int) ? map['colorValue'] : 0xFF2196F3,
    );
  }

  String toJson() => json.encode(toMap());
  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}
