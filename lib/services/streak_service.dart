import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  // Storage Keys
  static const String _keyCurrentStreak = 'streak_current';
  static const String _keyBestStreak = 'streak_best';
  static const String _keyLastActionDate = 'streak_last_date';
  static const String _keyShields = 'streak_shields';
  static const String _keyHistory = 'streak_history';

  // NEW KEYS
  static const String _keySilentMode = 'pref_silent_mode';
  static const String _keyUserWhy = 'pref_user_why';
  static const String _keyDailyRatings = 'streak_daily_ratings';

  // State Variables
  int currentStreak = 0;
  int bestStreak = 0;
  int shields = 0;
  bool hasActionToday = false;
  Map<String, int> history = {};

  // Feature State
  bool isSilentMode = false;
  String userWhy = "";
  Map<String, int> dailyRatings = {};

  // Singleton
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
    bestStreak = prefs.getInt(_keyBestStreak) ?? 0;
    shields = prefs.getInt(_keyShields) ?? 0;
    isSilentMode = prefs.getBool(_keySilentMode) ?? false;
    userWhy = prefs.getString(_keyUserWhy) ?? "";

    // Load History
    final String? historyJson = prefs.getString(_keyHistory);
    if (historyJson != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(historyJson);
        history = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        history = {};
      }
    }

    // Load Ratings
    final String? ratingsJson = prefs.getString(_keyDailyRatings);
    if (ratingsJson != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(ratingsJson);
        dailyRatings = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        dailyRatings = {};
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

  Future<void> logDailyRating(int rating) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _formatDate(DateTime.now());

    dailyRatings[todayStr] = rating;
    await prefs.setString(_keyDailyRatings, jsonEncode(dailyRatings));
    await markActionTaken();
  }

  // --- Feature 2: Discipline Identity (Smart) ---
  String getDisciplineIdentity() {
    if (currentStreak == 0 && bestStreak == 0) return "Aspiring Builder";
    if (currentStreak > 30) return "Deep Rooted Habit";
    if (currentStreak > 7) return "Quiet Consistency";
    if (currentStreak < 3 && bestStreak > 5) return "Resilient Restarter";
    return "Momentum Builder";
  }

  // --- Legacy Compatibility (Simple) ---
  String getIdentityLabel() {
    if (currentStreak == 0) return "Fresh Start";
    if (currentStreak < 3) return "Getting Started";
    if (currentStreak < 7) return "Momentum Builder";
    if (currentStreak < 14) return "Consistent Learner";
    if (currentStreak < 30) return "Disciplined Mind";
    return "Exam Warrior";
  }

  Future<void> toggleSilentMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    isSilentMode = value;
    await prefs.setBool(_keySilentMode, value);
  }

  Future<void> saveUserWhy(String why) async {
    final prefs = await SharedPreferences.getInstance();
    userWhy = why;
    await prefs.setString(_keyUserWhy, why);
  }

  Future<bool> markActionTaken() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    int currentCount = history[todayStr] ?? 0;
    history[todayStr] = currentCount + 1;
    await prefs.setString(_keyHistory, jsonEncode(history));

    if (hasActionToday) return true;

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

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
