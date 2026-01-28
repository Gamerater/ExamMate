import 'package:flutter/material.dart';

class Task {
  String title;
  bool isCompleted;

  // --- NEW FIELDS ---
  String priority; // e.g., 'High', 'Medium', 'Low'
  String label; // e.g., 'Physics', 'Math', 'General'
  int colorValue; // We store colors as Integers (0xFF...) for JSON

  Task({
    required this.title,
    this.isCompleted = false,
    // Defaults ensure backward compatibility for new fields
    this.priority = 'Medium',
    this.label = 'General',
    this.colorValue = 0xFF2196F3, // Default Blue
  });

  // Convert to Map (Saving)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      // Save new fields
      'priority': priority,
      'label': label,
      'colorValue': colorValue,
    };
  }

  // Convert from Map (Loading)
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      // FIX 1: Defensive coding for title.
      // Prevents crash if 'title' is null or missing in JSON.
      title: map['title']?.toString() ?? 'Untitled Task',

      // FIX 2: Safer boolean check.
      // Handles nulls and type mismatches (like 0/1 from SQLite) gracefully.
      isCompleted: map['isCompleted'] == true,

      // --- MIGRATION LOGIC ---
      // FIX 3: Added toString() to string fields to prevent type casting errors.
      priority: map['priority']?.toString() ?? 'Medium',
      label: map['label']?.toString() ?? 'General',

      // FIX 4: Type check for integer.
      // If data is corrupted (e.g. String instead of int), fallback to default color rather than crash.
      colorValue: (map['colorValue'] is int) ? map['colorValue'] : 0xFF2196F3,
    );
  }
}
