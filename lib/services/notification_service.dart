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

  /// Initialize the notification settings
  Future<void> init() async {
    try {
      // 1. Initialize Timezones (Critical for scheduling)
      tz.initializeTimeZones();

      // 2. Android Settings
      // NOTE: Ensure 'ic_launcher' exists in android/app/src/main/res/mipmap-*/
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. iOS Settings
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

      // 4. Initialize Plugin with Tap Handler
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap logic here
          debugPrint("🔔 Notification Tapped: ${response.payload}");
          // You can add navigation logic here using a GlobalKey or Navigator
        },
      );

      debugPrint("✅ Notification Service Initialized");
    } catch (e) {
      debugPrint("🚨 Error initializing notifications: $e");
    }
  }

  /// Request necessary permissions for Android 13+ and iOS
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();

        final bool? granted =
            await androidImplementation?.requestNotificationsPermission();
        return granted ?? false; // Safely return false if null
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
      debugPrint("🚨 Error requesting permissions: $e");
    }
    return false;
  }

  /// Calculate the next specific time (e.g., 8:00 PM) in UTC
  /// This ensures the notification triggers at the correct local time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final DateTime nowLocal = DateTime.now();

    DateTime scheduledLocal = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      hour,
      minute,
    );

    // If the time has passed for today, schedule for tomorrow
    if (scheduledLocal.isBefore(nowLocal)) {
      scheduledLocal = scheduledLocal.add(const Duration(days: 1));
    }

    // Convert to UTC for the plugin (Absolute Time Interpretation)
    return tz.TZDateTime.from(scheduledLocal.toUtc(), tz.UTC);
  }

  /// Schedule a daily repeating reminder
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    try {
      // 1. Generate Message (Async)
      final String smartBody = await _generateMotivationalMessage();

      // 2. Calculate Time (UTC)
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

      // 3. Define Notification Details
      // CRITICAL: ID changed to 'v4' to force update channel settings on devices
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'daily_reminder_channel_v4',
        'Daily Study Reminder',
        channelDescription: 'Reminds you to study every day',
        importance: Importance.max, // Max importance to show heads-up
        priority: Priority.high,
        ticker: 'Time to study!',
        // Optional: Add sound here if needed
        // sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      // 4. Cancel existing notification to avoid duplicates
      await flutterLocalNotificationsPlugin.cancel(0);

      // 5. Schedule
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'ExamMate 🎓',
        smartBody,
        scheduledDate,
        platformDetails,
        // Inexact is battery-friendly and doesn't require special permission
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // REPEATS DAILY
      );

      debugPrint(
          "✅ Notification Scheduled: $scheduledDate (UTC) with body: $smartBody");
    } catch (e) {
      debugPrint("🚨 Error scheduling notification: $e");
    }
  }

  Future<String> _generateMotivationalMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int streak = prefs.getInt('current_streak') ?? 0;
      final String? examDateStr = prefs.getString('exam_date');
      final List<String> tasks =
          prefs.getStringList('tasks_data') ?? []; // Fixed key name

      int pendingCount = 0;
      if (tasks.isNotEmpty) {
        // Simple check if list exists, detailed parsing might be overkill for just a count
        // Assuming json structure
        pendingCount = tasks.length;
      }

      int daysLeft = 0;
      if (examDateStr != null) {
        try {
          final examDate = DateTime.parse(examDateStr);
          daysLeft = examDate.difference(DateTime.now()).inDays;
        } catch (_) {}
      }

      if (daysLeft > 0 && daysLeft <= 60) {
        return "$daysLeft days left. Make today count.";
      }
      if (streak >= 3) {
        return "You're on a $streak-day streak! Keep it alive 🔥";
      }
      if (pendingCount > 0) {
        return "You have pending tasks waiting. Knock one out?";
      }
    } catch (e) {
      debugPrint("Message gen error: $e");
    }
    return "Consistency beats intensity. Time for a quick session.";
  }

  /// Cancel all notifications (e.g., when user disables toggle)
  Future<void> cancelNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint("🚫 All notifications cancelled");
    } catch (e) {
      debugPrint("🚨 Error cancelling notifications: $e");
    }
  }
}
