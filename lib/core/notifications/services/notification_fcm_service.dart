import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _kInstallationIdKey = 'magic_diary_notification_installation_id';

  final FirebaseMessaging? _customFcm;
  FirebaseMessaging get _fcm => _customFcm ?? FirebaseMessaging.instance;
  final NotificationRepository _repository;
  final NotificationScheduler _scheduler;
  final LocalNotificationService _localNotificationService;

  String? _currentToken;
  String? _currentDeviceId;
  bool _isInitialized = false;
  String? _initializedUserId;
  Completer<void>? _initCompleter;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<String>? _onRegisteredSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  String? get currentToken => _currentToken;
  String? get currentDeviceId => _currentDeviceId;
  bool get isInitialized => _isInitialized;
  String? get initializedUserId => _initializedUserId;

  NotificationFcmService({
    FirebaseMessaging? fcm,
    NotificationRepository? repository,
    NotificationScheduler? scheduler,
    LocalNotificationService? localNotificationService,
  })  : _customFcm = fcm,
        _repository = repository ?? NotificationRepository(),
        _scheduler = scheduler ?? NotificationScheduler(),
        _localNotificationService = localNotificationService ?? LocalNotificationService();

  Future<String> getOrCreateInstallationId() async {
    if (_currentDeviceId != null && _currentDeviceId!.isNotEmpty) {
      return _currentDeviceId!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_kInstallationIdKey);
      if (id == null || id.isEmpty) {
        id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
        await prefs.setString(_kInstallationIdKey, id);
      }
      _currentDeviceId = id;
      return id;
    } catch (_) {
      final fallback = _currentDeviceId ?? 'dev_${DateTime.now().millisecondsSinceEpoch}';
      _currentDeviceId = fallback;
      return fallback;
    }
  }

  Future<void> initialize(
    String userId, {
    void Function(Map<String, dynamic> data)? onNotificationOpened,
    bool force = false,
  }) async {
    if (userId.isEmpty) return;

    // Mutex: Avoid concurrent initialization & permission requests
    if (_initCompleter != null) {
      debugPrint('[NotificationFcmService] Initialization already in progress, awaiting existing task.');
      return _initCompleter!.future;
    }

    if (!force && _isInitialized && _initializedUserId == userId) {
      debugPrint('[NotificationFcmService] Already initialized for UID $userId.');
      return;
    }

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      // 1. Query existing settings to prevent repeatedly prompting users or spamming dialogs
      NotificationSettings settings;
      try {
        final currentSettings = await _fcm.getNotificationSettings();
        if (currentSettings.authorizationStatus == AuthorizationStatus.notDetermined) {
          settings = await _fcm.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
        } else {
          settings = currentSettings;
        }
      } catch (e) {
        debugPrint('FCM getNotificationSettings error, requesting permission: $e');
        settings = await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 2. Fetch direct token to register device immediately
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

        // 3. Set up token refresh listeners idempotently (cancelling previous subscriptions)
        await _tokenRefreshSub?.cancel();
        // ignore: deprecated_member_use
        _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
          debugPrint('FCM Token onTokenRefresh received: $newToken');
          registerDeviceToken(userId, newToken);
        });

        await _onRegisteredSub?.cancel();
        _onRegisteredSub = _fcm.onRegistered.listen((newToken) {
          debugPrint('FCM Token onRegistered received: $newToken');
          registerDeviceToken(userId, newToken);
        });

        // 4. Trigger registration (wrapped safely for Firebase Installations API)
        try {
          await _fcm.register();
        } catch (e) {
          debugPrint('FCM register note: $e');
        }

        // 5. Message event listeners
        await _onMessageSub?.cancel();
        _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          handleIncomingMessage(userId, message);
        });

        await _onMessageOpenedAppSub?.cancel();
        _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          if (onNotificationOpened != null) {
            onNotificationOpened(message.data);
          }
        });

        // 6. Check if app launched from terminated state via push
        final initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null && onNotificationOpened != null) {
          onNotificationOpened(initialMessage.data);
        }
      } else {
        debugPrint('[NotificationFcmService] Notification permission not granted (${settings.authorizationStatus})');
      }

      _isInitialized = true;
      _initializedUserId = userId;
    } catch (e) {
      debugPrint('FCM initialization note: $e');
    } finally {
      _initCompleter = null;
      completer.complete();
    }
  }

  Future<void> registerDeviceToken(String userId, String token) async {
    if (userId.isEmpty || token.isEmpty) return;
    _currentToken = token;

    final platform = kIsWeb
        ? 'web'
        : (Platform.isAndroid
            ? 'android'
            : (Platform.isIOS ? 'ios' : (Platform.isMacOS ? 'macos' : 'other')));

    final deviceId = await getOrCreateInstallationId();
    _currentDeviceId = deviceId;

    final device = NotificationDevice(
      id: deviceId,
      userId: userId,
      fcmToken: token,
      platform: platform,
      deviceName: '$platform device',
      lastActiveAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    // Save device registration
    await _repository.registerDevice(userId, device);

    // Prune obsolete duplicate device records that have the exact same token under older IDs
    try {
      final existingDevices = await _repository.getDevices(userId);
      for (final existing in existingDevices) {
        if (existing.id != deviceId && existing.fcmToken == token) {
          debugPrint('Pruning obsolete device ${existing.id} with duplicate token');
          await _repository.deleteDevice(userId, existing.id);
        }
      }
    } catch (_) {}

    // Persist fcmToken directly on user profile for backend discovery
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'lastDeviceActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> onUserLoggedOut() async {
    _isInitialized = false;
    _initializedUserId = null;
    _currentToken = null;
    _currentDeviceId = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _onRegisteredSub?.cancel();
    _onRegisteredSub = null;
    await _onMessageSub?.cancel();
    _onMessageSub = null;
    await _onMessageOpenedAppSub?.cancel();
    _onMessageOpenedAppSub = null;
  }

  Future<void> deleteDevice(String userId, String deviceId) async {
    await _repository.deleteDevice(userId, deviceId);
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
