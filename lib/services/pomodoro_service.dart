import '../models/pomodoro_session.dart';
import '../repositories/pomodoro_repository.dart';

class PomodoroService {
  final PomodoroRepository _repo = PomodoroRepository();

  /// Logs a completed Pomodoro session.
  /// If [subject] is null or empty, it is considered "General Focus".
  Future<void> logSession({required int duration, String? subject}) async {
    final session = PomodoroSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      durationMinutes: duration,
      subject: subject?.trim().isEmpty ?? true ? null : subject!.trim(),
      timestamp: DateTime.now(),
    );
    await _repo.saveSession(session);
  }

  /// Retrieves the total focus time (in minutes) per subject over the last [days].
  Future<Map<String, int>> getSubjectFocusStats({int days = 7}) async {
    List<PomodoroSession> allSessions = await _repo.getSessions();
    final cutoff = DateTime.now().subtract(Duration(days: days));

    Map<String, int> stats = {};

    for (var session in allSessions) {
      if (session.timestamp.isAfter(cutoff)) {
        String key = session.subject ?? "General";
        stats[key] = (stats[key] ?? 0) + session.durationMinutes;
      }
    }

    return stats;
  }

  /// Retrieves the total focus time (in minutes) across all subjects for today.
  Future<int> getTodayTotalFocusMinutes() async {
    List<PomodoroSession> allSessions = await _repo.getSessions();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    int total = 0;
    for (var session in allSessions) {
      if (session.timestamp.isAfter(todayStart) ||
          session.timestamp.isAtSameMomentAs(todayStart)) {
        total += session.durationMinutes;
      }
    }
    return total;
  }
}
