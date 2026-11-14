import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_enums.dart';
import '../models/notification_payload.dart';
import 'notification_defer_manager.dart';
import 'notification_snooze_manager.dart';

typedef NavigationCallback = void Function(String route, {Object? extra});
typedef ActionPromptCallback = void Function(String actionType, NotificationPayload payload);

class NotificationActionHandler {
  static final NotificationActionHandler _instance = NotificationActionHandler._internal();
  factory NotificationActionHandler() => _instance;
  NotificationActionHandler._internal();

  NotificationSnoozeManager? _snoozeManager;
  NotificationDeferManager? _deferManager;
  NotificationDeferManager? get deferManager => _deferManager;
  NavigationCallback? _navigationHandler;
  ActionPromptCallback? _actionPromptHandler;

  void configure({
    required NotificationSnoozeManager snoozeManager,
    required NotificationDeferManager deferManager,
    NavigationCallback? navigationHandler,
    ActionPromptCallback? actionPromptHandler,
  }) {
    _snoozeManager = snoozeManager;
    _deferManager = deferManager;
    _navigationHandler = navigationHandler;
    _actionPromptHandler = actionPromptHandler;
  }

  /// Handles incoming notification response from FlutterLocalNotificationsPlugin.
  Future<void> handleResponse(NotificationResponse response) async {
    final rawPayload = response.payload;
    final actionId = response.actionId ?? 'OPEN';

    debugPrint('Notification action triggered: $actionId, payload: $rawPayload');

    if (rawPayload == null || rawPayload.isEmpty) {
      if (_navigationHandler != null) {
        _navigationHandler!('/reminders');
      }
      return;
    }

    final payload = NotificationPayload.fromJsonString(rawPayload);
    await processAction(actionId: actionId, payload: payload);
  }

  /// Processes notification action directly.
  Future<void> processAction({
    required String actionId,
    required NotificationPayload payload,
    String userId = '',
  }) async {
    final cleanAction = actionId.toUpperCase().trim();

    switch (cleanAction) {
      // 1. Quick Snooze 10 Minutes
      case 'SNOOZE_10M':
        if (_snoozeManager != null) {
          await _snoozeManager!.snoozeNotification(
            userId: userId,
            recordId: payload.recordId,
            moduleId: payload.moduleId,
            categoryId: payload.categoryId,
            eventType: payload.eventType,
            originalDueDate: payload.dueDate,
            title: payload.title,
            originalBody: payload.body,
            preset: SnoozePreset.tenMinutes,
            isAlreadyOverdue: payload.isOverdue,
            occurrenceId: payload.occurrenceId,
          );
        }
        break;

      // 2. Quick Snooze 1 Hour
      case 'SNOOZE_1H':
        if (_snoozeManager != null) {
          await _snoozeManager!.snoozeNotification(
            userId: userId,
            recordId: payload.recordId,
            moduleId: payload.moduleId,
            categoryId: payload.categoryId,
            eventType: payload.eventType,
            originalDueDate: payload.dueDate,
            title: payload.title,
            originalBody: payload.body,
            preset: SnoozePreset.oneHour,
            isAlreadyOverdue: payload.isOverdue,
            occurrenceId: payload.occurrenceId,
          );
        }
        break;

      // 3. Quick Snooze Tomorrow Morning
      case 'SNOOZE_TOMORROW':
        if (_snoozeManager != null) {
          await _snoozeManager!.snoozeNotification(
            userId: userId,
            recordId: payload.recordId,
            moduleId: payload.moduleId,
            categoryId: payload.categoryId,
            eventType: payload.eventType,
            originalDueDate: payload.dueDate,
            title: payload.title,
            originalBody: payload.body,
            preset: SnoozePreset.tomorrowMorning,
            isAlreadyOverdue: payload.isOverdue,
            occurrenceId: payload.occurrenceId,
          );
        }
        break;

      // 4. More Snooze Options (Opens app snooze selector)
      case 'SNOOZE_MORE':
      case 'SNOOZE':
        if (_actionPromptHandler != null) {
          _actionPromptHandler!('SNOOZE', payload);
        } else if (_navigationHandler != null) {
          _navigationHandler!('/reminders', extra: payload.toMap());
        }
        break;

      // 5. Defer Options (Opens app defer selector)
      case 'DEFER':
        if (_actionPromptHandler != null) {
          _actionPromptHandler!('DEFER', payload);
        } else if (_navigationHandler != null) {
          _navigationHandler!('/reminders', extra: payload.toMap());
        }
        break;

      // 6. Paid (Requires confirmation before marking financial record)
      case 'PAID':
        if (_actionPromptHandler != null) {
          _actionPromptHandler!('PAID', payload);
        } else if (_navigationHandler != null) {
          final route = payload.actionRoute ?? '/payments';
          _navigationHandler!(route, extra: payload.toMap());
        }
        break;

      // 7. Complete
      case 'COMPLETE':
        if (_actionPromptHandler != null) {
          _actionPromptHandler!('COMPLETE', payload);
        } else if (_navigationHandler != null) {
          _navigationHandler!('/reminders', extra: payload.toMap());
        }
        break;

      // 8. Open
      case 'OPEN':
      default:
        if (_navigationHandler != null) {
          final route = payload.actionRoute ?? _resolveDefaultRoute(payload.moduleId);
          _navigationHandler!(route, extra: payload.toMap());
        }
        break;
    }
  }

  String _resolveDefaultRoute(String moduleId) {
    switch (moduleId.toLowerCase().trim()) {
      case 'bills':
        return '/bills';
      case 'vehicle':
        return '/vehicle';
      case 'warranty':
        return '/warranty';
      case 'school_fees':
      case 'schoolfees':
        return '/school-fees';
      case 'finance':
        return '/finance';
      case 'household':
        return '/household';
      case 'domestic_help':
      case 'domestichelp':
        return '/domestic-help';
      case 'property':
        return '/property';
      case 'personal':
        return '/personal';
      default:
        return '/reminders';
    }
  }
}
