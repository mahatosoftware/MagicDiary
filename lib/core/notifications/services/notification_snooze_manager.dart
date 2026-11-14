import 'package:flutter/foundation.dart';
import '../models/notification_action_record.dart';
import '../models/notification_enums.dart';
import '../models/notification_schedule.dart';
import '../models/time_of_day_dto.dart';
import '../repositories/notification_repository.dart';
import 'local_notification_service.dart';
import 'notification_channel_manager.dart';

class SnoozeResult {
  final bool isSuccess;
  final String? errorMessage;
  final DateTime? snoozedUntil;
  final NotificationSchedule? schedule;

  const SnoozeResult({
    required this.isSuccess,
    this.errorMessage,
    this.snoozedUntil,
    this.schedule,
  });
}

class NotificationSnoozeManager {
  final NotificationRepository _repository;
  final LocalNotificationService _localNotificationService;

  NotificationSnoozeManager({
    NotificationRepository? repository,
    LocalNotificationService? localNotificationService,
  })  : _repository = repository ?? NotificationRepository(),
        _localNotificationService = localNotificationService ?? LocalNotificationService();

  /// Calculates target date for snooze based on chosen preset or custom duration.
  DateTime calculateSnoozeDate({
    required SnoozePreset preset,
    DateTime? customDateTime,
    TimeOfDayDto preferredTime = TimeOfDayDto.defaultPreferred,
    DateTime? fromTime,
  }) {
    final now = fromTime ?? DateTime.now();

    switch (preset) {
      case SnoozePreset.tenMinutes:
        return now.add(const Duration(minutes: 10));
      case SnoozePreset.thirtyMinutes:
        return now.add(const Duration(minutes: 30));
      case SnoozePreset.oneHour:
        return now.add(const Duration(hours: 1));
      case SnoozePreset.threeHours:
        return now.add(const Duration(hours: 3));
      case SnoozePreset.tomorrowMorning:
        final tomorrow = now.add(const Duration(days: 1));
        return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, preferredTime.hour, preferredTime.minute);
      case SnoozePreset.nextWorkingDay:
        var nextDay = now.add(const Duration(days: 1));
        while (nextDay.weekday == DateTime.saturday || nextDay.weekday == DateTime.sunday) {
          nextDay = nextDay.add(const Duration(days: 1));
        }
        return DateTime(nextDay.year, nextDay.month, nextDay.day, preferredTime.hour, preferredTime.minute);
      case SnoozePreset.custom:
        if (customDateTime != null) {
          return customDateTime;
        }
        return now.add(const Duration(hours: 1));
    }
  }

  /// Snoozes a notification for a record according to the 12 strict rules.
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
    final now = DateTime.now();
    final effectiveCount = (currentSnoozeCount ?? 0) + 1;

    // Rule 8: Max snooze count configurable by user
    if (effectiveCount > maxSnoozeCount) {
      return SnoozeResult(
        isSuccess: false,
        errorMessage: 'Maximum snooze limit ($maxSnoozeCount) reached for this reminder.',
      );
    }

    final targetSnoozeTime = calculateSnoozeDate(
      preset: preset,
      customDateTime: customDateTime,
      preferredTime: preferredTime,
      fromTime: now,
    );

    if (targetSnoozeTime.isBefore(now)) {
      return const SnoozeResult(
        isSuccess: false,
        errorMessage: 'Snooze target time must be in the future.',
      );
    }

    // Rule 4: Each snooze must have a unique schedule identifier
    final snoozeScheduleId = 'snooze_${recordId}_${now.millisecondsSinceEpoch}';
    final localId = LocalNotificationService.generateStableId(snoozeScheduleId);

    // Rule 5: Cancel any prior active snoozed local notifications for this record
    final existingSchedules = await _repository.getSchedulesForRecord(userId, recordId);
    for (final s in existingSchedules) {
      if (s.isSnoozed && s.isActive) {
        await _localNotificationService.cancelNotification(s.localNotificationId);
        await _repository.updateScheduleStatus(
          userId,
          s.id,
          NotificationScheduleStatus.cancelled,
        );
      }
    }

    // Rule 12: Preserve overdue status if snoozing an already overdue reminder
    final effectiveNotificationType = isAlreadyOverdue ? 'overdue' : 'snooze';

    final snoozeSchedule = NotificationSchedule(
      id: snoozeScheduleId,
      userId: userId,
      moduleId: moduleId,
      categoryId: categoryId,
      recordId: recordId,
      occurrenceId: occurrenceId ?? 'occ_default',
      eventType: eventType,
      notificationType: effectiveNotificationType,
      scheduledAt: targetSnoozeTime,
      originalScheduledAt: originalDueDate,
      reminderOffset: 'snooze_${preset.name}',
      status: NotificationScheduleStatus.snoozed,
      scheduleSource: ScheduleSource.snooze,
      isSnoozed: true,
      isDeferred: false,
      snoozeCount: effectiveCount,
      localNotificationId: localId,
      payload: {
        'recordId': recordId,
        'moduleId': moduleId,
        'title': title,
        'body': originalBody,
        'dueDate': originalDueDate.toIso8601String(),
        'snoozeCount': effectiveCount,
        'isOverdue': isAlreadyOverdue,
        ...?extraPayload,
      },
      createdAt: now,
      updatedAt: now,
    );

    // Persist schedule
    await _repository.saveSchedule(userId, snoozeSchedule);

    // Schedule local notification
    final details = NotificationChannelManager().buildNotificationDetails(
      channelType: NotificationChannelType.snoozeDefer,
      soundEnabled: true,
      vibrationEnabled: true,
      privacyMode: PrivacyMode.detailed,
      actions: [
        NotificationActionType.snooze,
        NotificationActionType.defer,
        NotificationActionType.markPaid,
        NotificationActionType.open,
      ],
    );

    final scheduled = await _localNotificationService.scheduleNotification(
      id: localId,
      title: 'Snoozed: $title',
      body: 'Postponed reminder now due. Original commitment: ${originalDueDate.day}/${originalDueDate.month}.',
      scheduledDate: targetSnoozeTime,
      details: details,
      payload: snoozeScheduleId,
    );

    if (!scheduled) {
      debugPrint('Warning: Local notification scheduling failed, but Firestore schedule recorded.');
    }

    // Audit log
    final durationMinutes = targetSnoozeTime.difference(now).inMinutes;
    final action = NotificationActionRecord(
      id: 'act_snooze_${now.millisecondsSinceEpoch}',
      notificationId: snoozeScheduleId,
      recordId: recordId,
      actionType: NotificationActionType.snooze,
      originalDate: originalDueDate,
      newDate: targetSnoozeTime,
      snoozeDurationMinutes: durationMinutes,
      occurrenceId: occurrenceId,
      performedAt: now,
      performedBy: userId,
      metadata: {
        'preset': preset.name,
        'snoozeCount': effectiveCount,
        'wasOverdue': isAlreadyOverdue,
      },
    );
    await _repository.recordAction(userId, action);

    return SnoozeResult(
      isSuccess: true,
      snoozedUntil: targetSnoozeTime,
      schedule: snoozeSchedule,
    );
  }

  /// Rule 9: Cancel a snoozed reminder (reverts to original schedule).
  Future<void> cancelSnooze(String userId, String recordId) async {
    final schedules = await _repository.getSchedulesForRecord(userId, recordId);
    for (final s in schedules) {
      if (s.isSnoozed && s.isActive) {
        await _localNotificationService.cancelNotification(s.localNotificationId);
        await _repository.updateScheduleStatus(
          userId,
          s.id,
          NotificationScheduleStatus.cancelled,
        );
      }
    }
  }

  /// Rule 10: Cancel all snoozes when record is completed or deleted.
  Future<void> onRecordCompletedOrDeleted(String userId, String recordId) async {
    await cancelSnooze(userId, recordId);
  }

  /// Rule 11: If due date changes, invalidate incompatible snoozed notifications.
  Future<void> onDueDateChanged(String userId, String recordId, DateTime newDueDate) async {
    final schedules = await _repository.getSchedulesForRecord(userId, recordId);
    for (final s in schedules) {
      if (s.isSnoozed && s.isActive) {
        // If snooze date is after the new due date, invalidate it
        if (s.scheduledAt.isAfter(newDueDate)) {
          await _localNotificationService.cancelNotification(s.localNotificationId);
          await _repository.updateScheduleStatus(
            userId,
            s.id,
            NotificationScheduleStatus.cancelled,
          );
        }
      }
    }
  }
}
