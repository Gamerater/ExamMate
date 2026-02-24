import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pomodoro_session.dart';

class PomodoroRepository {
  static const String _keySessions = 'pomodoro_sessions_data';

  Future<List<PomodoroSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keySessions);

    if (data == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((item) => PomodoroSession.fromMap(item)).toList();
    } catch (e) {
      debugPrint("Error decoding sessions: $e");
      return [];
    }
  }

  Future<void> saveSession(PomodoroSession session) async {
    List<PomodoroSession> existing = await getSessions();
    existing.add(session);

    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> mapList =
        existing.map((s) => s.toMap()).toList();
    await prefs.setString(_keySessions, jsonEncode(mapList));
  }
}
