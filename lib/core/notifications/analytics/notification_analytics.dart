import 'package:flutter/foundation.dart';

class NotificationAnalytics {
  static final NotificationAnalytics _instance = NotificationAnalytics._internal();
  factory NotificationAnalytics() => _instance;
  NotificationAnalytics._internal();

  final List<Map<String, dynamic>> _inMemoryEvents = [];
  List<Map<String, dynamic>> get loggedEvents => List.unmodifiable(_inMemoryEvents);

  void logEvent(String eventName, [Map<String, dynamic>? parameters]) {
    final sanitizedParams = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      if (parameters != null) ...parameters,
    };

    // Strip any sensitive fields (e.g. account numbers, raw financial values)
    sanitizedParams.remove('accountNumber');
    sanitizedParams.remove('creditCardNumber');
    sanitizedParams.remove('pin');

    _inMemoryEvents.add({
      'event': eventName,
      'params': sanitizedParams,
    });

    if (kDebugMode) {
      debugPrint('[Analytics] $eventName: $sanitizedParams');
    }
  }

  void logScheduled({required String moduleId, required String eventType, required int intervalsCount}) {
    logEvent('notification_scheduled', {
      'module_id': moduleId,
      'event_type': eventType,
      'intervals_count': intervalsCount,
    });
  }

  void logCancelled({required String moduleId, required String recordId}) {
    logEvent('notification_cancelled', {
      'module_id': moduleId,
      'record_id': recordId,
    });
  }

  void logDisplayed({required String moduleId, required String scheduleId}) {
    logEvent('notification_displayed', {
      'module_id': moduleId,
      'schedule_id': scheduleId,
    });
  }

  void logOpened({required String moduleId, required String recordId}) {
    logEvent('notification_opened', {
      'module_id': moduleId,
      'record_id': recordId,
    });
  }

  void logSnoozed({required String moduleId, required int snoozeCount, required int durationMinutes}) {
    logEvent('notification_snoozed', {
      'module_id': moduleId,
      'snooze_count': snoozeCount,
      'duration_minutes': durationMinutes,
    });
  }

  void logDeferred({required String moduleId, required String mode, required int daysDeferred}) {
    logEvent('notification_deferred', {
      'module_id': moduleId,
      'mode': mode,
      'days_deferred': daysDeferred,
    });
  }

  void logCompleted({required String moduleId, required String recordId}) {
    logEvent('reminder_completed', {
      'module_id': moduleId,
      'record_id': recordId,
    });
  }

  void logOverdue({required String moduleId, required int overdueDays}) {
    logEvent('reminder_overdue', {
      'module_id': moduleId,
      'overdue_days': overdueDays,
    });
  }

  void logPermission(bool granted) {
    logEvent(
      granted ? 'notification_permission_granted' : 'notification_permission_denied',
    );
  }

  void logRecoveryCompleted(int recoveredCount, int cleanedCount) {
    logEvent('notification_recovery_completed', {
      'recovered_count': recoveredCount,
      'cleaned_count': cleanedCount,
    });
  }
}
