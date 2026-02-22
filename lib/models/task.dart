import 'dart:convert';

enum TaskEffort { quick, medium, deep }

enum TaskStatus { active, completed, expired }

class Task {
  String id;
  String title;
  bool isCompleted; // Kept for legacy support
  DateTime date;

  String note;
  TaskEffort effort;
  int sessionsCompleted;

  String? subject;
  DateTime? deadline;
  bool isTemporary;

  // --- NEW: PREMIUM ARCHITECTURE FIELDS ---
  TaskStatus status;
  DateTime createdAt;
  DateTime? completedAt;

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
    this.subject,
    this.deadline,
    this.isTemporary = false,
    this.status = TaskStatus.active,
    DateTime? createdAt,
    this.completedAt,
    this.label = 'General',
    this.colorValue = 0xFF2196F3,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'date': date.toIso8601String(),
      'note': note,
      'effort': effort.index,
      'sessionsCompleted': sessionsCompleted,
      'subject': subject,
      'deadline': deadline?.toIso8601String(),
      'isTemporary': isTemporary,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'label': label,
      'colorValue': colorValue,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    TaskEffort parseEffort(dynamic mapVal) {
      if (mapVal != null &&
          mapVal is int &&
          mapVal >= 0 &&
          mapVal < TaskEffort.values.length) {
        return TaskEffort.values[mapVal];
      }
      return TaskEffort.medium;
    }

    bool legacyIsCompleted = map['isCompleted'] == true;
    TaskStatus parseStatus() {
      if (map['status'] != null && map['status'] is int) {
        return TaskStatus.values[map['status']];
      }
      return legacyIsCompleted ? TaskStatus.completed : TaskStatus.active;
    }

    DateTime parsedDate = map['date'] != null
        ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
        : DateTime.now();

    return Task(
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? 'Untitled Task',
      isCompleted: legacyIsCompleted,
      date: parsedDate,
      note: map['note']?.toString() ?? '',
      effort: parseEffort(map['effort']),
      sessionsCompleted: (map['sessionsCompleted'] is num)
          ? (map['sessionsCompleted'] as num).toInt()
          : 0,
      subject: map['subject']?.toString(),
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'].toString())
          : null,
      isTemporary: map['isTemporary'] == true,
      status: parseStatus(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : parsedDate, // Fallback to old date
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
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
      if (decoded is Map<String, dynamic>) return Task.fromMap(decoded);
    } catch (_) {}
    return Task(
        id: DateTime.now().toString(),
        title: 'Error loading task',
        date: DateTime.now());
  }
}
