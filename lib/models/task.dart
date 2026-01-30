import 'dart:convert';
import 'package:flutter/material.dart';

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

  // NEW: Track focus sessions for this task (Simple counter)
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
    this.sessionsCompleted = 0, // Default 0
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
      'sessionsCompleted': sessionsCompleted, // Save counter
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

      // Load sessions (Default to 0 if missing)
      sessionsCompleted:
          map['sessionsCompleted'] is int ? map['sessionsCompleted'] : 0,

      label: map['label']?.toString() ?? 'General',
      colorValue: (map['colorValue'] is int) ? map['colorValue'] : 0xFF2196F3,
    );
  }

  String toJson() => json.encode(toMap());
  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));
}

// Find the _buildEffortChip method and replace it with this:
Widget _buildEffortChip(
  BuildContext context,
  TaskEffort value,
  TaskEffort groupValue,
  Function(TaskEffort) onSelect,
) {
  String label = value == TaskEffort.quick
      ? "Quick"
      : value == TaskEffort.medium
          ? "Medium"
          : "Deep Focus";

  Color color = value == TaskEffort.quick
      ? Colors.amber
      : value == TaskEffort.medium
          ? Colors.blue
          : Colors.deepPurple;

  bool isSelected = value == groupValue;

  // Detect Dark Mode
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return FilterChip(
    label: Text(label),
    selected: isSelected,
    selectedColor: color.withOpacity(0.2),
    checkmarkColor: color,
    // FIX: Use lighter text for unselected state in Dark Mode
    labelStyle: TextStyle(
      color: isSelected
          ? color
          : (isDark ? Colors.grey[300] : Colors.black87), // <--- VISIBILITY FIX
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    ),
    // FIX: Adjust border color for visibility in Dark Mode
    side: isSelected
        ? BorderSide.none
        : BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
    onSelected: (_) => onSelect(value),
  );
}
