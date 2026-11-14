import 'package:flutter/foundation.dart';
import '../models/notification_enums.dart';
import '../repositories/notification_repository.dart';
import 'local_notification_service.dart';
import 'notification_channel_manager.dart';

class RecoveryResult {
  final int recoveredCount;
  final int cleanedCount;
  final bool timezoneChanged;

  const RecoveryResult({
    required this.recoveredCount,
    required this.cleanedCount,
    required this.timezoneChanged,
  });
}

class NotificationRecoveryManager {
  final NotificationRepository _repository;
  final LocalNotificationService _localNotificationService;

  String? _lastKnownTimezone;

  NotificationRecoveryManager({
    NotificationRepository? repository,
    LocalNotificationService? localNotificationService,
  })  : _repository = repository ?? NotificationRepository(),
        _localNotificationService = localNotificationService ?? LocalNotificationService();

  /// Runs full reconciliation on application startup or device reboot.
  Future<RecoveryResult> reconcile({
    required String userId,
    String? currentTimezone,
  }) async {
    if (userId.isEmpty) {
      return const RecoveryResult(recoveredCount: 0, cleanedCount: 0, timezoneChanged: false);
    }

    final now = DateTime.now();
    bool tzChanged = false;

    // 1. Timezone change detection
    final currentTz = currentTimezone ?? DateTime.now().timeZoneName;
    if (_lastKnownTimezone != null && _lastKnownTimezone != currentTz) {
      debugPrint('Timezone change detected: $_lastKnownTimezone -> $currentTz');
      tzChanged = true;
    }
    _lastKnownTimezone = currentTz;

    // 2. Fetch all active schedules from Firestore / local cache
    final activeSchedules = await _repository.getActiveSchedules(userId);

    // 3. Query pending local notifications currently registered with OS
    final pendingLocalRequests = await _localNotificationService.getPendingNotifications();
    final pendingLocalIds = pendingLocalRequests.map((r) => r.id).toSet();

    var recoveredCount = 0;
    var cleanedCount = 0;

    for (final schedule in activeSchedules) {
      // Check for stale past schedules
      if (schedule.scheduledAt.isBefore(now)) {
        // Mark stale/displayed
        await _repository.updateScheduleStatus(
          userId,
          schedule.id,
          NotificationScheduleStatus.displayed,
        );
        cleanedCount++;
        continue;
      }

      // Check if local alarm is missing or if timezone changed
      final isLocallyMissing = !pendingLocalIds.contains(schedule.localNotificationId);
      if (isLocallyMissing || tzChanged) {
        // Reschedule local OS notification
        final payloadData = schedule.payload;
        final title = payloadData['title'] as String? ?? 'Reminder';
        final body = payloadData['body'] as String? ?? 'You have a scheduled commitment.';

        NotificationChannelType channelType = NotificationChannelType.generalReminders;
        if (schedule.isOverdueAlert) {
          channelType = NotificationChannelType.overdueAlerts;
        } else if (schedule.isSnoozed || schedule.isDeferred) {
          channelType = NotificationChannelType.snoozeDefer;
        }

        final details = NotificationChannelManager().buildNotificationDetails(
          channelType: channelType,
          soundEnabled: true,
          vibrationEnabled: true,
          privacyMode: PrivacyMode.detailed,
          actions: [
            NotificationActionType.markPaid,
            NotificationActionType.snooze,
            NotificationActionType.defer,
            NotificationActionType.open,
          ],
        );

        final success = await _localNotificationService.scheduleNotification(
          id: schedule.localNotificationId,
          title: title,
          body: body,
          scheduledDate: schedule.scheduledAt,
          details: details,
          payload: schedule.id,
        );

        if (success) {
          recoveredCount++;
        }
      }
    }

    debugPrint('Notification Recovery complete: $recoveredCount recovered, $cleanedCount cleaned.');
    return RecoveryResult(
      recoveredCount: recoveredCount,
      cleanedCount: cleanedCount,
      timezoneChanged: tzChanged,
    );
  }
}
