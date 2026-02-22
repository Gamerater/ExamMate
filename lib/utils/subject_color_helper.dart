import 'package:flutter/material.dart';

class SubjectColorHelper {
  // Common subjects get fixed premium colors
  static const Map<String, Color> _presetColors = {
    'physics': Colors.blue,
    'maths': Colors.purple,
    'math': Colors.purple,
    'mathematics': Colors.purple,
    'chemistry': Colors.green,
    'biology': Colors.teal,
    'history': Colors.brown,
    'geography': Colors.deepOrange,
    'english': Colors.indigo,
    'mock test': Colors.redAccent,
    'revision': Colors.blueGrey,
  };

  // Fallback palette for unknown subjects
  static const List<Color> _fallbackPalette = [
    Colors.pink,
    Colors.cyan,
    Colors.amber,
    Colors.lime,
    Colors.lightBlue,
    Colors.deepPurpleAccent,
  ];

  static Color getColor(String? subject) {
    if (subject == null || subject.trim().isEmpty) return Colors.grey;

    String normalized = subject.trim().toLowerCase();

    // 1. Check presets
    if (_presetColors.containsKey(normalized)) {
      return _presetColors[normalized]!;
    }

    // 2. Deterministic hash mapping for unknown subjects
    // Ensures 'Data Structures' always gets the same color on this device
    int hash = normalized.hashCode.abs();
    return _fallbackPalette[hash % _fallbackPalette.length];
  }
}
