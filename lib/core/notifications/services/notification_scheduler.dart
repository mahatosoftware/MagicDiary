import 'package:flutter/foundation.dart';
import '../models/notification_enums.dart';
import '../models/notification_payload.dart';
import '../models/notification_schedule.dart';
import '../models/time_of_day_dto.dart';
import '../repositories/notification_repository.dart';
import 'local_notification_service.dart';
import 'notification_channel_manager.dart';
import 'notification_preference_manager.dart';
import 'notification_template_manager.dart';

class NotificationScheduler {
  final NotificationRepository _repository;
  final NotificationPreferenceManager _preferenceManager;
  final NotificationTemplateManager _templateManager;
  final LocalNotificationService _localNotificationService;

  NotificationScheduler({
    NotificationRepository? repository,
    NotificationPreferenceManager? preferenceManager,
    NotificationTemplateManager? templateManager,
    LocalNotificationService? localNotificationService,
  })  : _repository = repository ?? NotificationRepository(),
        _preferenceManager = preferenceManager ?? NotificationPreferenceManager(),
        _templateManager = templateManager ?? NotificationTemplateManager(),
        _localNotificationService = localNotificationService ?? LocalNotificationService();

  /// Calculates, schedules, and persists all notifications for a diary record.
  Future<List<NotificationSchedule>> scheduleRecordReminders({
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
    final now = DateTime.now();

    // 1. Get resolved effective preferences
    final effectivePref = await _preferenceManager.getEffectivePreference(
      userId: userId,
      moduleId: moduleId,
      categoryId: categoryId,
      recordId: recordId,
      eventType: eventType,
    );

    if (!effectivePref.isEnabled) {
      debugPrint('Notifications disabled for $recordId ($moduleId). Skipping scheduling.');
      return const [];
    }

    // 2. Get template & format messages
    final template = _templateManager.getTemplate(moduleId, eventType);
    final mergedTokens = <String, dynamic>{
      'title': title,
      'eventName': title,
      'dueDate': '${dueDate.day}/${dueDate.month}/${dueDate.year}',
      'date': '${dueDate.day}/${dueDate.month}/${dueDate.year}',
      if (amount != null) 'amount': '$currency ${amount.toStringAsFixed(0)}',
      'currency': currency,
      ...tokenData,
    };

    // 3. Cancel any existing active reminders for this record to prevent duplicates
    await cancelRecordReminders(userId, recordId);

    final generatedSchedules = <NotificationSchedule>[];

    // 4. Schedule advance reminders
    for (final interval in effectivePref.reminderIntervals) {
      final rawTrigger = interval.calculateTriggerTime(
        dueDate,
        effectivePref.preferredNotificationTime,
      );

      // Adjust for Quiet Hours & Weekends
      final adjustedTrigger = _adjustForQuietHoursAndWeekends(
        trigger: rawTrigger,
        quietHoursEnabled: effectivePref.quietHoursEnabled,
        quietStart: effectivePref.quietHoursStart,
        quietEnd: effectivePref.quietHoursEnd,
        allowWeekends: effectivePref.allowWeekendNotifications,
      );

      // Skip past dates
      if (adjustedTrigger.isBefore(now)) continue;

      final offsetKey = interval.toOffsetKey();
      final scheduleId = 'sched_${recordId}_${offsetKey}_$occurrenceId';
      final localId = LocalNotificationService.generateStableId(scheduleId);

      // Dynamic days remaining token
      final daysRemaining = dueDate.difference(adjustedTrigger).inDays;
      final intervalTokens = Map<String, dynamic>.from(mergedTokens);
      intervalTokens['days'] = daysRemaining > 0 ? daysRemaining : 0;

      final formattedTitle = template.formatTitle(intervalTokens);
      final formattedBody = template.formatBody(intervalTokens, effectivePref.privacyMode);

      final payload = NotificationPayload(
        scheduleId: scheduleId,
        recordId: recordId,
        moduleId: moduleId,
        categoryId: categoryId,
        eventType: eventType,
        occurrenceId: occurrenceId,
        title: formattedTitle,
        body: formattedBody,
        amount: amount,
        currency: currency,
        dueDate: dueDate,
        actionRoute: actionRoute,
        actionType: 'OPEN',
        notificationType: 'reminder',
        isOverdue: false,
      );

      final schedule = NotificationSchedule(
        id: scheduleId,
        userId: userId,
        moduleId: moduleId,
        categoryId: categoryId,
        recordId: recordId,
        occurrenceId: occurrenceId,
        eventType: eventType,
        notificationType: 'reminder',
        scheduledAt: adjustedTrigger,
        originalScheduledAt: rawTrigger,
        reminderOffset: offsetKey,
        status: NotificationScheduleStatus.scheduled,
        scheduleSource: (effectivePref.intervalsSource == InheritanceStatus.customized)
            ? ScheduleSource.individualOverride
            : ScheduleSource.defaultTemplate,
        isSnoozed: false,
        isDeferred: false,
        localNotificationId: localId,
        payload: payload.toMap(),
        createdAt: now,
        updatedAt: now,
      );

      // Local notification details
      final details = NotificationChannelManager().buildNotificationDetails(
        channelType: template.channelType,
        soundEnabled: effectivePref.soundEnabled,
        vibrationEnabled: effectivePref.vibrationEnabled,
        privacyMode: effectivePref.privacyMode,
        actions: template.suggestedActions,
      );

      // Schedule local OS alarm
      await _localNotificationService.scheduleNotification(
        id: localId,
        title: formattedTitle,
        body: formattedBody,
        scheduledDate: adjustedTrigger,
        details: details,
        payload: payload.toJsonString(),
      );

      generatedSchedules.add(schedule);
    }

    // If no advance reminders could be scheduled because their trigger times were already in the past
    // (e.g., user adds a bill due tomorrow or today, but 9:00 AM has already passed today),
    // schedule an immediate upcoming reminder so the user actually receives a notification!
    if (generatedSchedules.isEmpty && dueDate.isAfter(now.subtract(const Duration(hours: 12)))) {
      final immediateTrigger = now.add(const Duration(minutes: 1));
      final scheduleId = 'sched_${recordId}_urgent_$occurrenceId';
      final localId = LocalNotificationService.generateStableId(scheduleId);
      final intervalTokens = Map<String, dynamic>.from(mergedTokens);
      intervalTokens['days'] = dueDate.difference(now).inDays;

      final formattedTitle = 'Reminder: $title';
      final formattedBody = 'Payment of ${amount != null ? "$currency ${amount.toStringAsFixed(0)}" : "bill"} is due ${dueDate.day == now.day ? "today" : "tomorrow"}!';

      final payload = NotificationPayload(
        scheduleId: scheduleId,
        recordId: recordId,
        moduleId: moduleId,
        categoryId: categoryId,
        eventType: eventType,
        occurrenceId: occurrenceId,
        title: formattedTitle,
        body: formattedBody,
        amount: amount,
        currency: currency,
        dueDate: dueDate,
        actionRoute: actionRoute,
        actionType: 'OPEN',
        notificationType: 'reminder',
        isOverdue: false,
      );

      final schedule = NotificationSchedule(
        id: scheduleId,
        userId: userId,
        moduleId: moduleId,
        categoryId: categoryId,
        recordId: recordId,
        occurrenceId: occurrenceId,
        eventType: eventType,
        notificationType: 'reminder',
        scheduledAt: immediateTrigger,
        originalScheduledAt: immediateTrigger,
        reminderOffset: 'urgent',
        status: NotificationScheduleStatus.scheduled,
        scheduleSource: ScheduleSource.defaultTemplate,
        isSnoozed: false,
        isDeferred: false,
        localNotificationId: localId,
        payload: payload.toMap(),
        createdAt: now,
        updatedAt: now,
      );

      final details = NotificationChannelManager().buildNotificationDetails(
        channelType: template.channelType,
        soundEnabled: effectivePref.soundEnabled,
        vibrationEnabled: effectivePref.vibrationEnabled,
        privacyMode: effectivePref.privacyMode,
        actions: template.suggestedActions,
      );

      await _localNotificationService.scheduleNotification(
        id: localId,
        title: formattedTitle,
        body: formattedBody,
        scheduledDate: immediateTrigger,
        details: details,
        payload: payload.toJsonString(),
      );

      generatedSchedules.add(schedule);
    }

    // 5. Schedule Overdue Alerts if enabled
    if (effectivePref.overdueAlertsEnabled) {
      for (final overdueDays in effectivePref.overdueIntervalsDays) {
        if (overdueDays == 0) continue; // 0 days is handled as onDueDate

        final rawOverdueTrigger = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day + overdueDays,
          effectivePref.preferredNotificationTime.hour,
          effectivePref.preferredNotificationTime.minute,
        );

        if (rawOverdueTrigger.isBefore(now)) continue;

        final overdueOffsetKey = 'overdue_${overdueDays}d';
        final scheduleId = 'sched_${recordId}_${overdueOffsetKey}_$occurrenceId';
        final localId = LocalNotificationService.generateStableId(scheduleId);

        final overdueTokens = Map<String, dynamic>.from(mergedTokens);
        overdueTokens['days'] = overdueDays;

        final overdueTemplate = _templateManager.getTemplate('general', 'overdue');
        final formattedTitle = overdueTemplate.formatTitle(overdueTokens);
        final formattedBody = overdueTemplate.formatBody(overdueTokens, effectivePref.privacyMode);

        final payload = NotificationPayload(
          scheduleId: scheduleId,
          recordId: recordId,
          moduleId: moduleId,
          categoryId: categoryId,
          eventType: eventType,
          occurrenceId: occurrenceId,
          title: formattedTitle,
          body: formattedBody,
          amount: amount,
          currency: currency,
          dueDate: dueDate,
          actionRoute: actionRoute,
          actionType: 'OPEN',
          notificationType: 'overdue',
          isOverdue: true,
        );

        final overdueSchedule = NotificationSchedule(
          id: scheduleId,
          userId: userId,
          moduleId: moduleId,
          categoryId: categoryId,
          recordId: recordId,
          occurrenceId: occurrenceId,
          eventType: eventType,
          notificationType: 'overdue',
          scheduledAt: rawOverdueTrigger,
          originalScheduledAt: rawOverdueTrigger,
          reminderOffset: overdueOffsetKey,
          status: NotificationScheduleStatus.scheduled,
          scheduleSource: ScheduleSource.overdueAlert,
          isSnoozed: false,
          isDeferred: false,
          localNotificationId: localId,
          payload: payload.toMap(),
          createdAt: now,
          updatedAt: now,
        );

        final details = NotificationChannelManager().buildNotificationDetails(
          channelType: NotificationChannelType.overdueAlerts,
          soundEnabled: effectivePref.soundEnabled,
          vibrationEnabled: effectivePref.vibrationEnabled,
          privacyMode: effectivePref.privacyMode,
          actions: [
            NotificationActionType.markPaid,
            NotificationActionType.snooze,
            NotificationActionType.defer,
            NotificationActionType.open,
          ],
        );

        await _localNotificationService.scheduleNotification(
          id: localId,
          title: formattedTitle,
          body: formattedBody,
          scheduledDate: rawOverdueTrigger,
          details: details,
          payload: payload.toJsonString(),
        );

        generatedSchedules.add(overdueSchedule);
      }
    }

    // 6. Batch persist all schedules
    await _repository.saveSchedulesBatch(userId, generatedSchedules);

    return generatedSchedules;
  }

  /// Cancels all active scheduled reminders for a record (e.g. when paid, completed or deleted).
  Future<void> cancelRecordReminders(String userId, String recordId) async {
    final schedules = await _repository.getSchedulesForRecord(userId, recordId);
    for (final s in schedules) {
      if (s.isActive) {
        await _localNotificationService.cancelNotification(s.localNotificationId);
      }
    }
    // Also cancel by stable record ID in case a direct or instant notification was posted
    await _localNotificationService.cancelNotification(
      LocalNotificationService.generateStableId(recordId),
    );
    await _repository.cancelSchedulesForRecord(userId, recordId);
  }

  /// Called when a payment is marked as paid or a task is completed:
  /// Cancels all future reminders and overdue alerts for this record occurrence.
  Future<void> onRecordPaidOrCompleted(String userId, String recordId) async {
    await cancelRecordReminders(userId, recordId);
  }

  /// Adjusts trigger time forward if falling in Quiet Hours or weekend restriction.
  DateTime _adjustForQuietHoursAndWeekends({
    required DateTime trigger,
    required bool quietHoursEnabled,
    required TimeOfDayDto quietStart,
    required TimeOfDayDto quietEnd,
    required bool allowWeekends,
  }) {
    var adjusted = trigger;

    // 1. Weekend adjustment
    if (!allowWeekends) {
      if (adjusted.weekday == DateTime.saturday) {
        // Shift to Friday same time
        adjusted = adjusted.subtract(const Duration(days: 1));
      } else if (adjusted.weekday == DateTime.sunday) {
        // Shift to Monday same time
        adjusted = adjusted.add(const Duration(days: 1));
      }
    }

    // 2. Quiet hours adjustment
    if (quietHoursEnabled) {
      final triggerMinutes = adjusted.hour * 60 + adjusted.minute;
      final startMinutes = quietStart.hour * 60 + quietStart.minute;
      final endMinutes = quietEnd.hour * 60 + quietEnd.minute;

      bool inQuietHours = false;
      if (startMinutes > endMinutes) {
        // Overnight window: e.g. 22:00 (1320) to 07:00 (420)
        inQuietHours = triggerMinutes >= startMinutes || triggerMinutes < endMinutes;
      } else {
        // Daytime window
        inQuietHours = triggerMinutes >= startMinutes && triggerMinutes < endMinutes;
      }

      if (inQuietHours) {
        // Shift forward to the end of quiet hours on the appropriate day
        if (triggerMinutes >= startMinutes) {
          // Trigger is late at night, push to next morning at quietEnd
          final nextDay = adjusted.add(const Duration(days: 1));
          adjusted = DateTime(nextDay.year, nextDay.month, nextDay.day, quietEnd.hour, quietEnd.minute);
        } else {
          // Trigger is early morning, push to quietEnd today
          adjusted = DateTime(adjusted.year, adjusted.month, adjusted.day, quietEnd.hour, quietEnd.minute);
        }
      }
    }

    return adjusted;
  }
}
