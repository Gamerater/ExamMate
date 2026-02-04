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
    try {
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
    } catch (e) {
      debugPrint("Error initializing notifications: $e");
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();

        final bool? granted =
            await androidImplementation?.requestNotificationsPermission();
        // On Android < 13, this returns null but permissions are implicitly granted.
        return granted ?? true;
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>();

        final bool? granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint("Error requesting permissions: $e");
    }
    return false;
  }

  /// Calculates the next instance of a time, adjusting for the device's TimeZone
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    // 1. Get Current Local Time
    final DateTime nowLocal = DateTime.now();

    // 2. Create Target Local Time for Today
    DateTime scheduledLocal = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      hour,
      minute,
    );

    // 3. If that time has passed today, move to tomorrow
    if (scheduledLocal.isBefore(nowLocal)) {
      scheduledLocal = scheduledLocal.add(const Duration(days: 1));
    }

    // 4. Convert the correct Local time to UTC for the Notification Plugin
    // This bypasses the need for the 'flutter_timezone' package.
    final tz.TZDateTime scheduledUTC =
        tz.TZDateTime.from(scheduledLocal.toUtc(), tz.UTC);

    debugPrint("Scheduling Notification for Local: $scheduledLocal");
    debugPrint("Converted to UTC: $scheduledUTC");

    return scheduledUTC;
  }

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    try {
      // FIX: Generate message FIRST. This is async and takes time.
      final String smartBody = await _generateMotivationalMessage();

      // FIX: Calculate time AFTER the await.
      // This prevents the "scheduled time" from slipping into the past
      // if the data loading takes a few seconds.
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

      // FIX: Increment Channel ID to 'v3' to ensure settings update on release devices
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'daily_reminder_channel_v3', // ID Updated for Release
        'Daily Study Reminder',
        channelDescription: 'Reminds you to study every day',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Time to study!',
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      // Cancel old ID 0 before scheduling new one
      await flutterLocalNotificationsPlugin.cancel(0);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'ExamMate 🎓',
        smartBody,
        scheduledDate,
        platformDetails,
        // FIX: Inexact is safer for Android 12+ without special permissions
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint("✅ Notification Scheduled Successfully!");
    } catch (e) {
      debugPrint("Error scheduling notification: $e");
    }
  }

  Future<String> _generateMotivationalMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int streak = prefs.getInt('current_streak') ?? 0;
      final String? examDateStr = prefs.getString('exam_date');
      final List<String> tasks = prefs.getStringList('tasks') ?? [];

      int pendingCount = 0;
      for (var t in tasks) {
        try {
          final Map<String, dynamic> taskMap = jsonDecode(t);
          if (taskMap['isCompleted'] == false) pendingCount++;
        } catch (e) {
          // Ignore malformed tasks
        }
      }

      int daysLeft = 999;
      if (examDateStr != null) {
        try {
          final examDate = DateTime.parse(examDateStr);
          daysLeft = examDate.difference(DateTime.now()).inDays;
        } catch (e) {
          // Ignore invalid dates
        }
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
    } catch (e) {
      debugPrint("Message gen error: $e");
    }
    return "Consistency beats intensity. Time for a quick session.";
  }

  Future<void> cancelNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint("All notifications cancelled");
    } catch (e) {
      debugPrint("Error cancelling notifications: $e");
    }
  }
}
