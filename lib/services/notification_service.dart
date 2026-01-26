import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted =
          await androidImplementation?.requestNotificationsPermission();
      return granted ?? true;
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      final bool? granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final String smartBody = await _generateMotivationalMessage();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Study Reminder',
      channelDescription: 'Reminds you to study every day',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'ExamMate 🎓',
        smartBody,
        scheduledDate,
        platformDetails,
        // FIX: New syntax for latest package version
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint("Error scheduling notification: $e");
    }
  }

  Future<String> _generateMotivationalMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final int streak = prefs.getInt('current_streak') ?? 0;
    final String? examDateStr = prefs.getString('exam_date');
    final List<String> tasks = prefs.getStringList('tasks') ?? [];

    int pendingCount = 0;
    for (var t in tasks) {
      try {
        final Map<String, dynamic> taskMap = jsonDecode(t);
        if (taskMap['isCompleted'] == false) pendingCount++;
      } catch (e) {}
    }

    int daysLeft = 999;
    if (examDateStr != null) {
      final examDate = DateTime.parse(examDateStr);
      daysLeft = examDate.difference(DateTime.now()).inDays;
    }

    if (daysLeft > 0 && daysLeft <= 60) {
      return "$daysLeft days until the big day. Make a 1% improvement today.";
    }
    if (streak >= 3) {
      return "You're on a $streak-day streak! Don't break the chain now 🔥";
    }
    if (pendingCount > 0) {
      return "You have $pendingCount topics waiting. Knock one out tonight?";
    }
    return "Consistency beats intensity. Time for a quick session.";
  }

  Future<void> cancelNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint("Error cancelling notifications: $e");
    }
  }
}
