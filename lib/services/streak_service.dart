import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  // Storage Keys
  static const String _keyCurrentStreak = 'streak_current';
  static const String _keyBestStreak = 'streak_best';
  static const String _keyLastActionDate = 'streak_last_date';
  static const String _keyShields = 'streak_shields';
  static const String _keyHistory =
      'streak_history'; // NEW: Stores date -> count

  // State Variables
  int currentStreak = 0;
  int bestStreak = 0;
  int shields = 0;
  bool hasActionToday = false;

  // NEW: History Data (Format: "YYYY-MM-DD" -> ActionCount)
  Map<String, int> history = {};

  // Singleton
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  /// Initialize and run daily checks
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
    bestStreak = prefs.getInt(_keyBestStreak) ?? 0;
    shields = prefs.getInt(_keyShields) ?? 0;

    // Load History
    final String? historyJson = prefs.getString(_keyHistory);
    if (historyJson != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(historyJson);
        history = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        debugPrint("Error loading history: $e");
        history = {};
      }
    }

    String? lastDate = prefs.getString(_keyLastActionDate);
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    if (lastDate == todayStr) {
      hasActionToday = true;
    } else {
      hasActionToday = false;
      await _checkMissedDays(prefs, lastDate, todayStr);
    }
  }

  Future<void> _checkMissedDays(
      SharedPreferences prefs, String? lastDate, String todayStr) async {
    if (lastDate == null) return;

    final last = DateTime.parse(lastDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final difference = today.difference(last).inDays;

    if (difference == 1) return; // Safe

    if (difference > 1) {
      if (shields > 0) {
        shields--;
        await prefs.setInt(_keyShields, shields);
        // Save streak using yesterday's date
        final yesterday = today.subtract(const Duration(days: 1));
        await prefs.setString(_keyLastActionDate, _formatDate(yesterday));
      } else {
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
          await prefs.setInt(_keyBestStreak, bestStreak);
        }
        currentStreak = 0;
        await prefs.setInt(_keyCurrentStreak, 0);
      }
    }
  }

  /// MVP ACTION TRIGGER
  /// Returns true if UI needs update
  Future<bool> markActionTaken() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    // 1. Update History (The Heatmap Data)
    int currentCount = history[todayStr] ?? 0;
    history[todayStr] = currentCount + 1;
    await prefs.setString(_keyHistory, jsonEncode(history));

    // 2. Handle Streak Logic (Only once per day)
    if (hasActionToday) {
      return true; // Just updated heatmap, streak already done
    }

    currentStreak++;
    hasActionToday = true;

    if (currentStreak > 0 && currentStreak % 7 == 0) {
      if (shields < 1) {
        shields++;
        await prefs.setInt(_keyShields, shields);
      }
    }

    await prefs.setInt(_keyCurrentStreak, currentStreak);
    await prefs.setString(_keyLastActionDate, todayStr);

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
      await prefs.setInt(_keyBestStreak, bestStreak);
    }

    return true;
  }

  // Helper
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // ... (Keep getIdentityLabel and getStreakMessage same as before) ...
  String getIdentityLabel() {
    if (currentStreak == 0) return "Fresh Start";
    if (currentStreak < 3) return "Getting Started";
    if (currentStreak < 7) return "Momentum Builder";
    if (currentStreak < 14) return "Consistent Learner";
    if (currentStreak < 30) return "Disciplined Mind";
    return "Exam Warrior";
  }
}
