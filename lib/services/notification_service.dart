import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
      );
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  Future<void> scheduleServiceReturnNotification({
    required String itemId,
    required String itemName,
    required DateTime expectedDate,
  }) async {
    if (kIsWeb) return;
    try {
      final int notificationId = itemId.hashCode;

      // Schedule notification at 9:00 AM on the expected return date.
      DateTime scheduleTime = DateTime(
        expectedDate.year,
        expectedDate.month,
        expectedDate.day,
        9,
        0,
      );

      if (scheduleTime.isBefore(DateTime.now())) {
        // If the scheduled time is in the past, schedule it 5 seconds from now for testing/instant alert
        scheduleTime = DateTime.now().add(const Duration(seconds: 5));
      }

      final tz.TZDateTime tzScheduleTime = tz.TZDateTime.from(scheduleTime, tz.local);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'mtc_service_alerts',
        'MTC Service Return Alerts',
        channelDescription: 'Alerts when serviced items are expected back',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Service Return Due',
        'Asset "$itemName" ($itemId) is expected back from service today.',
        tzScheduleTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Error scheduling service return notification: $e');
    }
  }

  Future<void> cancelScheduledNotification(String itemId) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(itemId.hashCode);
    } catch (e) {
      debugPrint('Error canceling scheduled notification: $e');
    }
  }
}

