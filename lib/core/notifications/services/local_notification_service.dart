import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'notification_channel_manager.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    void Function(NotificationResponse)? onActionTapped,
  }) async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone initialization note: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (onActionTapped != null) {
          onActionTapped(response);
        }
      },
    );

    // Initialize notification channels on Android
    await NotificationChannelManager().initializeChannels(_plugin);

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    bool granted = false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final res = await android.requestNotificationsPermission();
      granted = res ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final res = await ios.requestPermissions(alert: true, badge: true, sound: true);
      granted = res ?? false;
    }

    return granted;
  }

  static int generateStableId(String input) {
    // Generate deterministic 31-bit positive int
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = (31 * hash + input.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }

  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required NotificationDetails details,
    String? payload,
  }) async {
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) {
      debugPrint('Skipping past notification schedule: $scheduledDate (Now: $now)');
      return false;
    }

    try {
      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

      // Attempt scheduling with exactAllowWhileIdle; catch permission exception if exact alarm restricted
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (exactError) {
        debugPrint('Exact alarm restricted, falling back to inexact: $exactError');
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Failed to schedule local notification: $e');
      return false;
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show instant notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Failed to cancel notification $id: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }
}
