import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  // Storage Keys
  static const String _keyCurrentStreak = 'streak_current';
  static const String _keyBestStreak = 'streak_best';
  static const String _keyLastActionDate = 'streak_last_date';
  static const String _keyShields = 'streak_shields';

  // State Variables
  int currentStreak = 0;
  int bestStreak = 0;
  int shields = 0;
  bool hasActionToday = false;

  // Singleton Pattern
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  /// Initialize and run daily checks
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
    bestStreak = prefs.getInt(_keyBestStreak) ?? 0;
    shields = prefs.getInt(_keyShields) ?? 0;

    String? lastDate = prefs.getString(_keyLastActionDate);
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    if (lastDate == todayStr) {
      hasActionToday = true;
    } else {
      hasActionToday = false;
      await _checkMissedDays(prefs, lastDate, todayStr);
    }
  }

  /// CRITICAL: Handles missed days and Streak Protection
  Future<void> _checkMissedDays(
      SharedPreferences prefs, String? lastDate, String todayStr) async {
    if (lastDate == null) return; // New user, nothing to check

    final last = DateTime.parse(lastDate); // e.g. 2023-10-01
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate difference in days (ignoring time)
    final difference = today.difference(last).inDays;

    if (difference == 1) {
      // User was active yesterday. Streak is safe.
      return;
    }

    if (difference > 1) {
      // User MISSED at least one day.
      if (shields > 0) {
        // PROTECTION ACTIVATED
        shields--; // Consume shield
        await prefs.setInt(_keyShields, shields);

        // We pretend they were active yesterday to save the streak
        // But we don't increment the count, just keep it alive.
        // We update the "last date" to yesterday so the chain isn't broken logic-wise.
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayStr =
            "${yesterday.year}-${yesterday.month}-${yesterday.day}";
        await prefs.setString(_keyLastActionDate, yesterdayStr);

        debugPrint("🛡️ Streak Shield Used! Streak saved at $currentStreak");
      } else {
        // STREAK BROKEN - Compassionate Reset
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
          await prefs.setInt(_keyBestStreak, bestStreak);
        }
        currentStreak = 0;
        await prefs.setInt(_keyCurrentStreak, 0);
        debugPrint("💔 Streak broken. Reset to 0.");
      }
    }
  }

  /// MVP ACTION TRIGGER: Call this when Task or Pomodoro is done
  Future<bool> markActionTaken() async {
    if (hasActionToday) return false; // Already counted today

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    // 1. Increment Streak
    currentStreak++;
    hasActionToday = true;

    // 2. Check for Shield Reward (Every 7 days)
    if (currentStreak > 0 && currentStreak % 7 == 0) {
      if (shields < 1) {
        // Max 1 shield
        shields++;
        await prefs.setInt(_keyShields, shields);
      }
    }

    // 3. Save Data
    await prefs.setInt(_keyCurrentStreak, currentStreak);
    await prefs.setString(_keyLastActionDate, todayStr);

    // Update best streak dynamically
    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
      await prefs.setInt(_keyBestStreak, bestStreak);
    }

    return true; // Return true to signal UI update
  }

  /// IDENTITY LABELS (Phase 2)
  String getIdentityLabel() {
    if (currentStreak == 0) return "Fresh Start";
    if (currentStreak < 3) return "Getting Started";
    if (currentStreak < 7) return "Momentum Builder";
    if (currentStreak < 14) return "Consistent Learner";
    if (currentStreak < 30) return "Disciplined Mind";
    if (currentStreak < 60) return "Exam Warrior";
    return "Legendary";
  }

  /// USER FACING MESSAGE
  String getStreakMessage() {
    if (currentStreak == 0) return "Do one small thing today.";
    if (hasActionToday) return "Great work today! 🔥";
    if (shields > 0) return "Streak protected. Keep it up! 🛡️";
    return "Keep the momentum going!";
  }
}
