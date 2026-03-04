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
          debugPrint("🔔 Notification Tapped: ${response.payload}");
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
        return granted ?? false; 
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

    return tz.TZDateTime.from(scheduledLocal.toUtc(), tz.UTC);
  }

  /// Schedule a daily repeating reminder
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    try {
      // 1. Generate Context-Aware Message (Async)
      final Map<String, String> messageData = await _generateContextualMessage();

      // 2. Calculate Time (UTC)
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

      // 3. Define Notification Details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'daily_reminder_channel_v5', // Iterated ID to force update
        'Daily Study Reminder',
        channelDescription: 'Reminds you to study every day based on your tasks',
        importance: Importance.max, 
        priority: Priority.high,
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      // 4. Cancel existing notification to avoid duplicates
      await flutterLocalNotificationsPlugin.cancel(0);

      // 5. Schedule
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        messageData['title'],
        messageData['body'],
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // REPEATS DAILY
      );

      debugPrint("✅ Notification Scheduled: $scheduledDate (UTC) -> Title: ${messageData['title']}");
    } catch (e) {
      debugPrint("🚨 Error scheduling notification: $e");
    }
  }

  /// Generates a Title and Body based on the user's task status for the day.
  Future<Map<String, String>> _generateContextualMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? tasksString = prefs.getString('tasks_data');

      int totalToday = 0;
      int completedToday = 0;

      // Parse JSON string into task maps
      if (tasksString != null && tasksString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(tasksString);
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        for (var item in decoded) {
          // Check task date
          DateTime tDate = DateTime.now();
          if (item['date'] != null) {
             tDate = DateTime.tryParse(item['date'].toString()) ?? DateTime.now();
          }
          DateTime cleanDate = DateTime(tDate.year, tDate.month, tDate.day);

          // Only count tasks that are for today or rolled over to today
          if (cleanDate.isAtSameMomentAs(todayStart) || cleanDate.isAfter(todayStart)) {
            totalToday++;
            
            // Check completion status (legacy 'isCompleted' or new 'status' enum)
            bool isDone = (item['isCompleted'] == true) || (item['status'] == 1); 
            if (isDone) {
              completedToday++;
            }
          }
        }
      }

      int remainingTasks = totalToday - completedToday;

      // CASE 1: No tasks exist
      if (totalToday == 0) {
        return {
          'title': 'Plan your study',
          'body': 'Add tasks to start building your streak.'
        };
      }

      // CASE 2: All tasks completed
      if (remainingTasks <= 0) {
        return {
          'title': 'Nice work today',
          'body': 'Momentum secured. See you tomorrow.'
        };
      }

      // CASE 3: Tasks remaining
      return {
        'title': 'Keep the streak alive',
        'body': 'You still have $remainingTasks task(s) left today.'
      };

    } catch (e) {
      debugPrint("🚨 Message gen error: $e");
      
      // Safe Fallback if parsing fails
      return {
        'title': 'ExamMate 🎓',
        'body': 'Consistency beats intensity. Time for a quick session.'
      };
    }
  }

  /// Cancel all notifications
  Future<void> cancelNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint("🚫 All notifications cancelled");
    } catch (e) {
      debugPrint("🚨 Error cancelling notifications: $e");
    }
  }
}