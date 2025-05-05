import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:medicineproject/main.dart'; // Access navigatorKey
import 'package:medicineproject/screens/reminder.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationHelper {
  static final _notification = FlutterLocalNotificationsPlugin();

  // --- ADD: Method to get launch details ---
  // Call this in main() BEFORE runApp
  static Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    try {
      final details = await _notification.getNotificationAppLaunchDetails();
      if (details != null) {
        print(
          "Notification launch details found: didLaunch=${details.didNotificationLaunchApp}",
        );
      } else {
        print("Notification launch details are null.");
      }
      return details;
    } catch (e) {
      print("Error getting notification launch details: $e");
      return null;
    }
  }
  // --- END ADD ---

  // Initialize plugin basics - context is not needed here for navigation
  static Future<void> init() async {
    print("NotificationHelper: Initializing...");
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(/*...*/); // Configure as needed

    tz.initializeTimeZones();
    // Optional: tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    // Initialize WITHOUT the onDidReceiveNotificationResponse here initially
    // We handle navigation later or use the getLaunchDetails
    await _notification.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      // This callback handles taps when app is *already running* (foreground/background)
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _requestPermissions();
    print("NotificationHelper: Initialization complete.");
  }

  // --- NEW: Separate navigation logic ---
  // Call this either from _onNotificationTap OR from main/HomeScreen after checking launch details
  static void navigateToReminderFromPayload(String payload) {
    print("Attempting navigation with payload: $payload");
    try {
      final Map<String, dynamic> payloadData = jsonDecode(payload);
      final String medicineId = payloadData['id'] ?? '';
      final String medicineName = payloadData['name'] ?? 'Unknown Medicine';
      final String description = payloadData['description'] ?? '';
      final String quantity = payloadData['quantity']?.toString() ?? '';
      final String unit = payloadData['unit'] ?? '';
      final int notificationId = payloadData['notificationId'] ?? 0;

      if (medicineId.isEmpty || notificationId == 0) {
        print(
          "Error: Payload missing required fields (id or notificationId). Cannot navigate.",
        );
        return;
      }

      // Use GlobalKey for Navigation
      // Add null check for safety
      if (navigatorKey.currentState != null) {
        print("Navigator state found, pushing ReminderPage...");
        navigatorKey.currentState!.push(
          // Use ! because we checked for null
          MaterialPageRoute(
            builder:
                (_) => ReminderPage(
                  medicineId: medicineId,
                  medicineName: medicineName,
                  description: description,
                  quantity: quantity,
                  unit: unit,
                  notificationId: notificationId,
                ),
          ),
        );
        print("Pushed ReminderPage.");
      } else {
        print(
          "Error: navigatorKey.currentState is null. Cannot navigate immediately.",
        );
        // Possible scenario: App just launched, navigator not ready yet.
        // Handling in _handleNotificationLaunch using addPostFrameCallback should cover this.
      }
    } catch (e) {
      print(
        "Error decoding payload or navigating in navigateToReminderFromPayload: $e",
      );
    }
  }
  // --- END Separate navigation logic ---

  // Tap handler called by the plugin when app is in foreground/background
  static void _onNotificationTap(NotificationResponse response) {
    print(
      "Notification tapped while app running. Payload: ${response.payload}",
    );
    if (response.payload == null || response.payload!.isEmpty) {
      print("Error: Cannot navigate - payload missing on tap.");
      return;
    }
    // Call the reusable navigation logic
    navigateToReminderFromPayload(response.payload!);
  }

  static Future<void> _requestPermissions() async {
    /* ... keep as is ... */
    final androidPlugin =
        _notification
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      final p1 = await androidPlugin.requestNotificationsPermission();
      print("Granted Notifications: $p1");
      final p2 = await androidPlugin.requestExactAlarmsPermission();
      print("Granted Exact Alarms: $p2");
    }
  }

  static Future<void> scheduleSingleMedicineNotification({
    /* ... keep as is ... */
    required int notificationId,
    required String medicineId,
    required String medicineName,
    required String quantity,
    required String unit,
    required String description,
    required TimeOfDay time,
  }) async {
    final tz.TZDateTime scheduledDateTime = _nextInstanceOfTime(time);
    const androidDetails = AndroidNotificationDetails(
      'medicine_channel_id_01',
      'Medicine Reminders',
      channelDescription: 'Channel for medicine reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final String payload = jsonEncode({
      'id': medicineId,
      'name': medicineName,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'notificationId': notificationId,
    });
    try {
      /*print("Payload being attached: $payload");*/
      print(
        'Scheduling notification ID $notificationId for "$medicineName" at $scheduledDateTime',
      );
      await _notification.zonedSchedule(
        notificationId,
        'Medication Reminder',
        'Time to take $quantity ${unit ?? ''} of $medicineName.',
        scheduledDateTime,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print("Successfully scheduled notification ID: $notificationId");
    } catch (e) {
      print("Error scheduling notification ID $notificationId: $e");
    }
  }

  static Future<void> scheduleSnoozeNotification({
    /* ... keep as is ... */ required int notificationId,
    required String medicineName,
    required String quantity,
    required String unit,
    required String payload,
  }) async {
    final tz.TZDateTime snoozeDateTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(minutes: 5));  // 5 minutes
    const androidDetails = AndroidNotificationDetails(
      'medicine_channel_id_01',
      'Medicine Reminders',
      channelDescription: 'Channel for medicine reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    print(
      'Scheduling SNOOZE notification ID $notificationId for "$medicineName" at $snoozeDateTime',
    );
    try {
      await _notification.zonedSchedule(
        notificationId,
        'Snoozed Reminder',
        'Time to take $quantity ${unit ?? ''} of $medicineName.',
        snoozeDateTime,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print("Successfully scheduled SNOOZE notification ID: $notificationId");
    } catch (e) {
      print("Error scheduling SNOOZE notification ID $notificationId: $e");
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    /* ... keep as is ... */
    final location = tz.getLocation('Asia/Bangkok');
    final tz.TZDateTime now = tz.TZDateTime.now(location);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> cancelNotification(int notificationId) async {
    /* ... keep as is ... */
    try {
      await _notification.cancel(notificationId);
      print('Cancelled notification ID $notificationId');
    } catch (e) {
      print("Error cancelling notification ID $notificationId: $e");
    }
  }

  static Future<void> cancelAllNotifications() async {
    /* ... keep as is ... */
    try {
      await _notification.cancelAll();
      print('Cancelled all notifications.');
    } catch (e) {
      print("Error cancelling all notifications: $e");
    }
  }
}
