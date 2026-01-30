import 'dart:convert';

// NEW: Enum for Effort Level
enum TaskEffort { quick, medium, deep }

class Task {
  // --- CORE FIELDS ---
  String id; // NEW: Unique ID for safer deletes/updates
  String title;
  bool isCompleted;
  DateTime date; // NEW: Required for "Carry Forward" logic

  // --- NEW FEATURES ---
  String note; // NEW: For extra details
  TaskEffort effort; // NEW: Replaces 'priority' logic visually

  // --- EXISTING FIELDS (Kept for compatibility) ---
  String label;
  int colorValue;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.date,
    this.note = '',
    this.effort = TaskEffort.medium,
    this.label = 'General',
    this.colorValue = 0xFF2196F3, // Default Blue
  });

  // Convert to Map (Saving)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'date': date.toIso8601String(),
      'note': note,
      'effort': effort.index, // Save Enum as int (0, 1, 2)
      // Save existing fields
      'label': label,
      'colorValue': colorValue,
    };
  }

  // Convert from Map (Loading)
  factory Task.fromMap(Map<String, dynamic> map) {
    // Helper: Smartly map old 'priority' strings to new 'effort' enum
    TaskEffort parseEffort(dynamic mapVal, String? oldPriority) {
      if (mapVal != null && mapVal is int) {
        return TaskEffort.values[mapVal];
      }
      // Migration Fallback: Map old Priority strings to new Effort
      if (oldPriority == 'High') return TaskEffort.deep;
      if (oldPriority == 'Low') return TaskEffort.quick;
      return TaskEffort.medium;
    }

    return Task(
      // FIX 1: Generate ID if missing (for old tasks)
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),

      title: map['title']?.toString() ?? 'Untitled Task',

      isCompleted: map['isCompleted'] == true,

      // FIX 2: If date is missing (old tasks), assume they belong to Today
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),

      note: map['note']?.toString() ?? '',

      // FIX 3: Smart Effort Mapping
      effort: parseEffort(map['effort'], map['priority']?.toString()),

      // Existing fields preserved
      label: map['label']?.toString() ?? 'General',
      colorValue: (map['colorValue'] is int) ? map['colorValue'] : 0xFF2196F3,
    );
  }

  String toJson() => json.encode(toMap());
  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}
