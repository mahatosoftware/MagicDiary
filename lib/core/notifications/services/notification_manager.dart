import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../analytics/notification_analytics.dart';
import '../models/notification_enums.dart';
import '../models/notification_schedule.dart';
import '../models/time_of_day_dto.dart';
import '../repositories/notification_repository.dart';
import 'local_notification_service.dart';
import 'notification_action_handler.dart';
import 'notification_channel_manager.dart';
import 'notification_defer_manager.dart';
import 'notification_fcm_service.dart';
import 'notification_history_manager.dart';
import 'notification_preference_manager.dart';
import 'notification_recovery_manager.dart';
import 'notification_scheduler.dart';
import 'notification_snooze_manager.dart';
import 'notification_template_manager.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  // Internal component services
  late final NotificationRepository repository;
  late final NotificationTemplateManager templateManager;
  late final NotificationPreferenceManager preferenceManager;
  late final NotificationChannelManager channelManager;
  late final LocalNotificationService localNotificationService;
  late final NotificationScheduler scheduler;
  late final NotificationSnoozeManager snoozeManager;
  late final NotificationDeferManager deferManager;
  late final NotificationActionHandler actionHandler;
  late final NotificationHistoryManager historyManager;
  late final NotificationRecoveryManager recoveryManager;
  late final NotificationFcmService fcmService;
  late final NotificationAnalytics analytics;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize({
    String? currentUserId,
    NavigationCallback? navigationHandler,
    ActionPromptCallback? actionPromptHandler,
  }) async {
    if (_initialized) return;

    repository = NotificationRepository();
    templateManager = NotificationTemplateManager();
    preferenceManager = NotificationPreferenceManager(
      repository: repository,
      templateManager: templateManager,
    );
    channelManager = NotificationChannelManager();
    localNotificationService = LocalNotificationService();
    scheduler = NotificationScheduler(
      repository: repository,
      preferenceManager: preferenceManager,
      templateManager: templateManager,
      localNotificationService: localNotificationService,
    );
    snoozeManager = NotificationSnoozeManager(
      repository: repository,
      localNotificationService: localNotificationService,
    );
    deferManager = NotificationDeferManager(
      repository: repository,
      localNotificationService: localNotificationService,
    );
    actionHandler = NotificationActionHandler();
    historyManager = NotificationHistoryManager(repository: repository);
    recoveryManager = NotificationRecoveryManager(
      repository: repository,
      localNotificationService: localNotificationService,
    );
    fcmService = NotificationFcmService(
      repository: repository,
      scheduler: scheduler,
    );
    analytics = NotificationAnalytics();

    // 1. Initialize local notifications & channel manager
    await localNotificationService.initialize(
      onActionTapped: (response) {
        actionHandler.handleResponse(response);
      },
    );

    // 2. Configure action handler
    actionHandler.configure(
      snoozeManager: snoozeManager,
      deferManager: deferManager,
      navigationHandler: navigationHandler,
      actionPromptHandler: actionPromptHandler,
    );

    // 3. If user is currently signed in, reconcile startup & initialize FCM immediately
    final resolvedUid = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : FirebaseAuth.instance.currentUser?.uid;

    if (resolvedUid != null && resolvedUid.isNotEmpty) {
      await recoveryManager.reconcile(userId: resolvedUid);
      await fcmService.initialize(resolvedUid);
    }

    // 4. Listen to auth state to automatically handle login/logout transitions
    _startAutoRegistration();

    _initialized = true;
    debugPrint('NotificationManager successfully initialized.');
  }

  StreamSubscription<User?>? _authSubscription;

  void _startAutoRegistration() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && user.uid.isNotEmpty) {
        if (fcmService.initializedUserId != user.uid) {
          debugPrint('[NotificationManager] Auth state changed: auto-registering device for UID ${user.uid}');
          try {
            await fcmService.initialize(user.uid);
          } catch (e) {
            debugPrint('[NotificationManager] Auto-registration note: $e');
          }
        }
      } else {
        await fcmService.onUserLoggedOut();
      }
    });
  }

  // =========================================================================
  // SCHEDULING OPERATIONS
  // =========================================================================

  Future<List<NotificationSchedule>> scheduleForRecord({
    required String userId,
    required String recordId,
    required String moduleId,
    required String categoryId,
    required String eventType,
    required String title,
    required DateTime dueDate,
    double? amount,
    String currency = 'INR',
    String? actionRoute,
    String occurrenceId = 'occ_default',
    Map<String, dynamic> tokenData = const {},
  }) async {
    final schedules = await scheduler.scheduleRecordReminders(
      userId: userId,
      recordId: recordId,
      moduleId: moduleId,
      categoryId: categoryId,
      eventType: eventType,
      title: title,
      dueDate: dueDate,
      amount: amount,
      currency: currency,
      actionRoute: actionRoute,
      occurrenceId: occurrenceId,
      tokenData: tokenData,
    );

    analytics.logScheduled(
      moduleId: moduleId,
      eventType: eventType,
      intervalsCount: schedules.length,
    );

    return schedules;
  }

  Future<void> cancelForRecord({
    required String userId,
    required String recordId,
    String moduleId = 'general',
  }) async {
    await scheduler.cancelRecordReminders(userId, recordId);
    analytics.logCancelled(moduleId: moduleId, recordId: recordId);
  }

  Future<void> onRecordPaidOrCompleted({
    required String userId,
    required String recordId,
    String moduleId = 'general',
  }) async {
    await scheduler.onRecordPaidOrCompleted(userId, recordId);
    await snoozeManager.onRecordCompletedOrDeleted(userId, recordId);
    analytics.logCompleted(moduleId: moduleId, recordId: recordId);
  }

  // =========================================================================
  // SNOOZE OPERATIONS
  // =========================================================================

  Future<SnoozeResult> snoozeNotification({
    required String userId,
    required String recordId,
    required String moduleId,
    required String categoryId,
    required String eventType,
    required DateTime originalDueDate,
    required String title,
    required String originalBody,
    required SnoozePreset preset,
    DateTime? customDateTime,
    TimeOfDayDto preferredTime = TimeOfDayDto.defaultPreferred,
    int maxSnoozeCount = 5,
    int? currentSnoozeCount,
    bool isAlreadyOverdue = false,
    String? occurrenceId,
    Map<String, dynamic>? extraPayload,
  }) async {
    final result = await snoozeManager.snoozeNotification(
      userId: userId,
      recordId: recordId,
      moduleId: moduleId,
      categoryId: categoryId,
      eventType: eventType,
      originalDueDate: originalDueDate,
      title: title,
      originalBody: originalBody,
      preset: preset,
      customDateTime: customDateTime,
      preferredTime: preferredTime,
      maxSnoozeCount: maxSnoozeCount,
      currentSnoozeCount: currentSnoozeCount,
      isAlreadyOverdue: isAlreadyOverdue,
      occurrenceId: occurrenceId,
      extraPayload: extraPayload,
    );

    if (result.isSuccess) {
      analytics.logSnoozed(
        moduleId: moduleId,
        snoozeCount: (currentSnoozeCount ?? 0) + 1,
        durationMinutes: result.snoozedUntil?.difference(DateTime.now()).inMinutes ?? 0,
      );
    }

    return result;
  }

  Future<void> cancelSnooze({
    required String userId,
    required String recordId,
  }) async {
    await snoozeManager.cancelSnooze(userId, recordId);
  }

  // =========================================================================
  // DEFER OPERATIONS
  // =========================================================================

  Future<DeferResult> deferNotificationOnly({
    required String userId,
    required String recordId,
    required String moduleId,
    required String categoryId,
    required String eventType,
    required DateTime originalDueDate,
    required DateTime newNotificationDate,
    required String title,
    String? reason,
    String? occurrenceId,
    Map<String, dynamic>? extraPayload,
  }) async {
    final res = await deferManager.deferNotificationOnly(
      userId: userId,
      recordId: recordId,
      moduleId: moduleId,
      categoryId: categoryId,
      eventType: eventType,
      originalDueDate: originalDueDate,
      newNotificationDate: newNotificationDate,
      title: title,
      reason: reason,
      occurrenceId: occurrenceId,
      extraPayload: extraPayload,
    );

    if (res.isSuccess) {
      analytics.logDeferred(
        moduleId: moduleId,
        mode: 'notification_only',
        daysDeferred: res.impactReport.daysDeferred,
      );
    }
    return res;
  }

  Future<DeferResult> deferUnderlyingEvent({
    required String userId,
    required String recordId,
    required String moduleId,
    required String categoryId,
    required String eventType,
    required DateTime originalDueDate,
    required DateTime newEventDueDate,
    required String title,
    bool updateRecurringSeries = false,
    String? reason,
    String? occurrenceId,
    required Future<void> Function(DateTime newDate) rescheduleCallback,
  }) async {
    final res = await deferManager.deferUnderlyingEvent(
      userId: userId,
      recordId: recordId,
      moduleId: moduleId,
      categoryId: categoryId,
      eventType: eventType,
      originalDueDate: originalDueDate,
      newEventDueDate: newEventDueDate,
      title: title,
      updateRecurringSeries: updateRecurringSeries,
      reason: reason,
      occurrenceId: occurrenceId,
      rescheduleCallback: rescheduleCallback,
    );

    if (res.isSuccess) {
      analytics.logDeferred(
        moduleId: moduleId,
        mode: 'underlying_event',
        daysDeferred: res.impactReport.daysDeferred,
      );
    }
    return res;
  }

  // =========================================================================
  // NOTIFICATION CENTRE HELPERS
  // =========================================================================

  Future<Map<String, List<NotificationSchedule>>> getCategorizedSchedules(String userId) async {
    final active = await repository.getActiveSchedules(userId);
    return historyManager.categorizeSchedules(active);
  }

  Future<List<NotificationSchedule>> getActiveSchedules(String userId) async {
    return await repository.getActiveSchedules(userId);
  }

  Future<List<DateTime>> previewSchedule({
    required String userId,
    required DateTime eventDate,
    String? moduleId,
    String? categoryId,
    String? recordId,
    String? eventType,
  }) async {
    return await preferenceManager.previewSchedule(
      userId: userId,
      eventDate: eventDate,
      moduleId: moduleId,
      categoryId: categoryId,
      recordId: recordId,
      eventType: eventType,
    );
  }
}
