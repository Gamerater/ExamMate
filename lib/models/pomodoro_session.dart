import 'dart:convert';

class PomodoroSession {
  final String id;
  final String? subject; // Null means 'General'
  final int durationMinutes;
  final DateTime timestamp;

  PomodoroSession({
    required this.id,
    this.subject,
    required this.durationMinutes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'durationMinutes': durationMinutes,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PomodoroSession.fromMap(Map<String, dynamic> map) {
    return PomodoroSession(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      subject: map['subject'],
      durationMinutes: map['durationMinutes'] ?? 25,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory PomodoroSession.fromJson(String source) =>
      PomodoroSession.fromMap(json.decode(source));
}
