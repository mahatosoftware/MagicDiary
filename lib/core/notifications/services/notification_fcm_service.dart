import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_device.dart';
import '../models/notification_enums.dart';
import '../repositories/notification_repository.dart';
import 'local_notification_service.dart';
import 'notification_channel_manager.dart';
import 'notification_scheduler.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
}

class NotificationFcmService {
  final FirebaseMessaging _fcm;
  final NotificationRepository _repository;
  final NotificationScheduler _scheduler;
  final LocalNotificationService _localNotificationService;

  NotificationFcmService({
    FirebaseMessaging? fcm,
    NotificationRepository? repository,
    NotificationScheduler? scheduler,
    LocalNotificationService? localNotificationService,
  })  : _fcm = fcm ?? FirebaseMessaging.instance,
        _repository = repository ?? NotificationRepository(),
        _scheduler = scheduler ?? NotificationScheduler(),
        _localNotificationService = localNotificationService ?? LocalNotificationService();

  Future<void> initialize(String userId, {void Function(Map<String, dynamic> data)? onNotificationOpened}) async {
    if (userId.isEmpty) return;

    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 1. Immediately attempt direct token acquisition to register device instantly
        try {
          // ignore: deprecated_member_use
          final directToken = await _fcm.getToken();
          if (directToken != null && directToken.isNotEmpty) {
            debugPrint('FCM direct token acquired: $directToken');
            await registerDeviceToken(userId, directToken);
          }
        } catch (e) {
          debugPrint('FCM direct token note: $e');
        }

        // 2. Listen for modern FirebaseMessaging registration stream
        _fcm.onRegistered.listen((newToken) {
          debugPrint('FCM Token onRegistered received: $newToken');
          registerDeviceToken(userId, newToken);
        });

        // 3. Trigger registration
        try {
          await _fcm.register();
        } catch (e) {
          debugPrint('FCM register note: $e');
        }

        // 3. Listen for foreground FCM messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          handleIncomingMessage(userId, message);
        });

        // Listen for background message click
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          if (onNotificationOpened != null) {
            onNotificationOpened(message.data);
          }
        });

        // Check if launched from terminated state via push
        final initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null && onNotificationOpened != null) {
          onNotificationOpened(initialMessage.data);
        }
      }
    } catch (e) {
      debugPrint('FCM initialization note: $e');
    }
  }

  Future<void> registerDeviceToken(String userId, String token) async {
    final platform = kIsWeb
        ? 'web'
        : (Platform.isAndroid
            ? 'android'
            : (Platform.isIOS ? 'ios' : (Platform.isMacOS ? 'macos' : 'other')));
    final deviceId = 'dev_${token.hashCode.abs()}';

    final device = NotificationDevice(
      id: deviceId,
      userId: userId,
      fcmToken: token,
      platform: platform,
      deviceName: '$platform device',
      lastActiveAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await _repository.registerDevice(userId, device);

    // Also persist fcmToken directly on user profile for instant backend discovery
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'lastDeviceActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Subscribe to household topic for shared family updates without backend dependencies
  Future<void> subscribeToHousehold(String householdId) async {
    if (householdId.isEmpty) return;
    try {
      await _fcm.subscribeToTopic('household_$householdId');
      debugPrint('Subscribed to FCM topic: household_$householdId');
    } catch (e) {
      debugPrint('FCM subscribe topic error: $e');
    }
  }

  Future<void> unsubscribeFromHousehold(String householdId) async {
    if (householdId.isEmpty) return;
    try {
      await _fcm.unsubscribeFromTopic('household_$householdId');
      debugPrint('Unsubscribed from FCM topic: household_$householdId');
    } catch (e) {
      debugPrint('FCM unsubscribe topic error: $e');
    }
  }

  /// Handles incoming remote messages, especially cross-device synchronization and foreground alerts.
  Future<void> handleIncomingMessage(String userId, RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String? ?? '';
    final recordId = data['recordId'] as String? ?? '';

    debugPrint('FCM message received: type=$type, recordId=$recordId');

    // Cross-Device Sync: If user completed or paid on Device A, Device B receives push and cancels local alarm!
    if (type == 'RECORD_PAID' || type == 'RECORD_COMPLETED') {
      if (recordId.isNotEmpty) {
        await _scheduler.onRecordPaidOrCompleted(userId, recordId);
      }
      return;
    }

    // Display foreground push using local notification engine
    final notification = message.notification;
    final title = notification?.title ?? data['title'] as String? ?? 'Magic Diary Reminder';
    final body = notification?.body ?? data['body'] as String? ?? '';

    if (body.isNotEmpty || notification != null) {
      final channelType = type == 'OVERDUE_ALERT'
          ? NotificationChannelType.overdueAlerts
          : (type == 'FAMILY_SHARED_UPDATE'
              ? NotificationChannelType.generalReminders
              : NotificationChannelType.financialReminders);

      final details = NotificationChannelManager().buildNotificationDetails(
        channelType: channelType,
        soundEnabled: true,
        vibrationEnabled: true,
        privacyMode: PrivacyMode.detailed,
      );

      final notifId = LocalNotificationService.generateStableId('fcm_${message.messageId ?? DateTime.now().millisecondsSinceEpoch}');
      await _localNotificationService.showInstantNotification(
        id: notifId,
        title: title,
        body: body,
        details: details,
        payload: data.isNotEmpty ? data.toString() : null,
      );
    }
  }
}
