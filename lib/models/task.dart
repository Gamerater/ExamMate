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
      title: map['title'],
      isCompleted: map['isCompleted'] ?? false,

      // --- MIGRATION LOGIC ---
      // If 'priority' doesn't exist (old task), use 'Medium'
      priority: map['priority'] ?? 'Medium',

      // If 'label' doesn't exist, use 'General'
      label: map['label'] ?? 'General',

      // If 'colorValue' doesn't exist, use Blue (0xFF2196F3)
      colorValue: map['colorValue'] ?? 0xFF2196F3,
    );
  }
}
