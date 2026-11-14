import '../models/notification_action_record.dart';
import '../models/notification_enums.dart';
import '../models/notification_schedule.dart';
import '../models/time_of_day_dto.dart';
import '../repositories/notification_repository.dart';
import 'local_notification_service.dart';
import 'notification_channel_manager.dart';

class DeferImpactReport {
  final DateTime originalDate;
  final DateTime newDate;
  final int daysDeferred;
  final int affectedRemindersCount;
  final bool willChangeRecurringDates;
  final bool willUpdateFinancialRecord;
  final bool isPotentiallyOverdueWarning;
  final String? warningMessage;

  const DeferImpactReport({
    required this.originalDate,
    required this.newDate,
    required this.daysDeferred,
    required this.affectedRemindersCount,
    required this.willChangeRecurringDates,
    required this.willUpdateFinancialRecord,
    required this.isPotentiallyOverdueWarning,
    this.warningMessage,
  });
}

class DeferResult {
  final bool isSuccess;
  final String? errorMessage;
  final DeferMode mode;
  final DateTime newDate;
  final DeferImpactReport impactReport;

  const DeferResult({
    required this.isSuccess,
    this.errorMessage,
    required this.mode,
    required this.newDate,
    required this.impactReport,
  });
}

typedef ModuleEventUpdater = Future<bool> Function({
  required String recordId,
  required DateTime newDueDate,
  required bool updateRecurringSeries,
  String? reason,
});

class NotificationDeferManager {
  final NotificationRepository _repository;
  final LocalNotificationService _localNotificationService;

  // Registered module updaters for Mode B (validated module updates)
  final Map<String, ModuleEventUpdater> _moduleUpdaters = {};

  NotificationDeferManager({
    NotificationRepository? repository,
    LocalNotificationService? localNotificationService,
  })  : _repository = repository ?? NotificationRepository(),
        _localNotificationService = localNotificationService ?? LocalNotificationService();

  void registerModuleUpdater(String moduleId, ModuleEventUpdater updater) {
    _moduleUpdaters[moduleId.toLowerCase().trim()] = updater;
  }

  /// Calculates deferred date based on chosen preset or custom date.
  DateTime calculateDeferredDate({
    required DateTime baseDate,
    required DeferPreset preset,
    DateTime? customDateTime,
    TimeOfDayDto preferredTime = TimeOfDayDto.defaultPreferred,
  }) {
    final now = DateTime.now();
    switch (preset) {
      case DeferPreset.laterToday:
        final later = now.add(const Duration(hours: 4));
        return later.isAfter(now) ? later : now.add(const Duration(hours: 2));
      case DeferPreset.tomorrow:
        final d = baseDate.add(const Duration(days: 1));
        return DateTime(d.year, d.month, d.day, preferredTime.hour, preferredTime.minute);
      case DeferPreset.nextWorkingDay:
        var next = baseDate.add(const Duration(days: 1));
        while (next.weekday == DateTime.saturday || next.weekday == DateTime.sunday) {
          next = next.add(const Duration(days: 1));
        }
        return DateTime(next.year, next.month, next.day, preferredTime.hour, preferredTime.minute);
      case DeferPreset.in2Days:
        final d = baseDate.add(const Duration(days: 2));
        return DateTime(d.year, d.month, d.day, preferredTime.hour, preferredTime.minute);
      case DeferPreset.in3Days:
        final d = baseDate.add(const Duration(days: 3));
        return DateTime(d.year, d.month, d.day, preferredTime.hour, preferredTime.minute);
      case DeferPreset.nextWeek:
        final d = baseDate.add(const Duration(days: 7));
        return DateTime(d.year, d.month, d.day, preferredTime.hour, preferredTime.minute);
      case DeferPreset.nextMonth:
        final d = DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
        return DateTime(d.year, d.month, d.day, preferredTime.hour, preferredTime.minute);
      case DeferPreset.custom:
        return customDateTime ?? baseDate.add(const Duration(days: 1));
    }
  }

  /// Generates pre-confirmation impact report for the user.
  Future<DeferImpactReport> generateImpactReport({
    required String userId,
    required String recordId,
    required DateTime originalDate,
    required DateTime newDate,
    required DeferMode mode,
    bool updateRecurringSeries = false,
  }) async {
    final daysDeferred = newDate.difference(originalDate).inDays;
    final now = DateTime.now();

    final activeSchedules = await _repository.getSchedulesForRecord(userId, recordId);
    final affectedCount = activeSchedules.where((s) => s.isActive).length;

    // Check potential overdue warning
    final isPotentiallyOverdue = newDate.isBefore(now);
    String? warning;
    if (isPotentiallyOverdue) {
      warning = 'Selected deferred date is already in the past. This commitment will be marked Overdue.';
    } else if (daysDeferred > 30) {
      warning = 'Postponing by $daysDeferred days may incur late fees or penalty interest if statutory.';
    }

    return DeferImpactReport(
      originalDate: originalDate,
      newDate: newDate,
      daysDeferred: daysDeferred,
      affectedRemindersCount: affectedCount,
      willChangeRecurringDates: mode == DeferMode.underlyingEvent && updateRecurringSeries,
      willUpdateFinancialRecord: mode == DeferMode.underlyingEvent,
      isPotentiallyOverdueWarning: isPotentiallyOverdue,
      warningMessage: warning,
    );
  }

  /// MODE A: Defer Notification Only
  /// Postpones upcoming notification without changing the underlying commitment due date.
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
    final now = DateTime.now();
    final impact = await generateImpactReport(
      userId: userId,
      recordId: recordId,
      originalDate: originalDueDate,
      newDate: newNotificationDate,
      mode: DeferMode.notificationOnly,
    );

    // Cancel prior local notification alarms for this record that are before newNotificationDate
    final existingSchedules = await _repository.getSchedulesForRecord(userId, recordId);
    for (final s in existingSchedules) {
      if (s.scheduledAt.isBefore(newNotificationDate) && s.isActive) {
        await _localNotificationService.cancelNotification(s.localNotificationId);
        await _repository.updateScheduleStatus(
          userId,
          s.id,
          NotificationScheduleStatus.deferred,
          isDeferred: true,
        );
      }
    }

    // Schedule new deferred notification
    final scheduleId = 'defer_notif_${recordId}_${now.millisecondsSinceEpoch}';
    final localId = LocalNotificationService.generateStableId(scheduleId);

    final deferSchedule = NotificationSchedule(
      id: scheduleId,
      userId: userId,
      moduleId: moduleId,
      categoryId: categoryId,
      recordId: recordId,
      occurrenceId: occurrenceId ?? 'occ_default',
      eventType: eventType,
      notificationType: 'defer',
      scheduledAt: newNotificationDate,
      originalScheduledAt: originalDueDate,
      reminderOffset: 'defer_notification',
      status: NotificationScheduleStatus.deferred,
      scheduleSource: ScheduleSource.deferModeA,
      isSnoozed: false,
      isDeferred: true,
      localNotificationId: localId,
      payload: {
        'recordId': recordId,
        'moduleId': moduleId,
        'title': title,
        'originalDueDate': originalDueDate.toIso8601String(),
        'deferReason': reason,
        ...?extraPayload,
      },
      createdAt: now,
      updatedAt: now,
    );

    await _repository.saveSchedule(userId, deferSchedule);

    final details = NotificationChannelManager().buildNotificationDetails(
      channelType: NotificationChannelType.snoozeDefer,
      soundEnabled: true,
      vibrationEnabled: true,
      privacyMode: PrivacyMode.detailed,
      actions: [
        NotificationActionType.markPaid,
        NotificationActionType.snooze,
        NotificationActionType.open,
      ],
    );

    await _localNotificationService.scheduleNotification(
      id: localId,
      title: 'Deferred Reminder: $title',
      body: 'Reminder rescheduled to today. Due date remains: ${originalDueDate.day}/${originalDueDate.month}.',
      scheduledDate: newNotificationDate,
      details: details,
      payload: scheduleId,
    );

    // Record action audit
    final action = NotificationActionRecord(
      id: 'act_defer_mode_a_${now.millisecondsSinceEpoch}',
      notificationId: scheduleId,
      recordId: recordId,
      actionType: NotificationActionType.defer,
      originalDate: originalDueDate,
      newDate: newNotificationDate,
      deferReason: reason,
      occurrenceId: occurrenceId,
      performedAt: now,
      performedBy: userId,
      metadata: {'mode': 'notification_only'},
    );
    await _repository.recordAction(userId, action);

    return DeferResult(
      isSuccess: true,
      mode: DeferMode.notificationOnly,
      newDate: newNotificationDate,
      impactReport: impact,
    );
  }

  /// MODE B: Defer Underlying Event
  /// Reschedules actual commitment date through owning module with validation.
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
    final now = DateTime.now();
    final impact = await generateImpactReport(
      userId: userId,
      recordId: recordId,
      originalDate: originalDueDate,
      newDate: newEventDueDate,
      mode: DeferMode.underlyingEvent,
      updateRecurringSeries: updateRecurringSeries,
    );

    // 1. Execute owning module's validated update operation
    final cleanModule = moduleId.toLowerCase().trim();
    if (_moduleUpdaters.containsKey(cleanModule)) {
      final updater = _moduleUpdaters[cleanModule]!;
      final success = await updater(
        recordId: recordId,
        newDueDate: newEventDueDate,
        updateRecurringSeries: updateRecurringSeries,
        reason: reason,
      );
      if (!success) {
        return DeferResult(
          isSuccess: false,
          errorMessage: 'Owning module rejected rescheduling operation.',
          mode: DeferMode.underlyingEvent,
          newDate: newEventDueDate,
          impactReport: impact,
        );
      }
    }

    // 2. Cancel all old scheduled alarms for this record
    final activeSchedules = await _repository.getSchedulesForRecord(userId, recordId);
    for (final s in activeSchedules) {
      if (s.isActive) {
        await _localNotificationService.cancelNotification(s.localNotificationId);
        await _repository.updateScheduleStatus(
          userId,
          s.id,
          NotificationScheduleStatus.cancelled,
        );
      }
    }

    // 3. Trigger recalculation of the full schedule from the new event date
    await rescheduleCallback(newEventDueDate);

    // 4. Record action audit with full before/after state
    final action = NotificationActionRecord(
      id: 'act_defer_mode_b_${now.millisecondsSinceEpoch}',
      notificationId: 'defer_mode_b_$recordId',
      recordId: recordId,
      actionType: NotificationActionType.defer,
      originalDate: originalDueDate,
      newDate: newEventDueDate,
      deferReason: reason,
      occurrenceId: occurrenceId,
      performedAt: now,
      performedBy: userId,
      metadata: {
        'mode': 'underlying_event',
        'updateRecurringSeries': updateRecurringSeries,
        'daysDeferred': impact.daysDeferred,
      },
    );
    await _repository.recordAction(userId, action);

    return DeferResult(
      isSuccess: true,
      mode: DeferMode.underlyingEvent,
      newDate: newEventDueDate,
      impactReport: impact,
    );
  }
}
