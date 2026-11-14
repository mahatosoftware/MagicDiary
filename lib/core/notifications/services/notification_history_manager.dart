import '../models/notification_enums.dart';
import '../models/notification_history_entry.dart';
import '../models/notification_schedule.dart';
import '../repositories/notification_repository.dart';

class NotificationHistoryManager {
  final NotificationRepository _repository;

  NotificationHistoryManager({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepository();

  Future<void> logEvent({
    required String userId,
    required String notificationId,
    required String recordId,
    required String moduleId,
    required String eventType,
    required String title,
    required String body,
    required NotificationScheduleStatus status,
    required DateTime scheduledAt,
    DateTime? deliveredAt,
    DateTime? displayedAt,
    DateTime? openedAt,
    String? actionTaken,
    Map<String, dynamic> metadata = const {},
  }) async {
    final entry = NotificationHistoryEntry(
      id: 'hist_${notificationId}_${DateTime.now().millisecondsSinceEpoch}',
      notificationId: notificationId,
      recordId: recordId,
      moduleId: moduleId,
      eventType: eventType,
      title: title,
      body: body,
      status: status,
      scheduledAt: scheduledAt,
      deliveredAt: deliveredAt,
      displayedAt: displayedAt,
      openedAt: openedAt,
      actionTaken: actionTaken,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    await _repository.addHistoryEntry(userId, entry);
  }

  /// Categorizes active schedules for the Notification Centre UI.
  Map<String, List<NotificationSchedule>> categorizeSchedules(
    List<NotificationSchedule> schedules, {
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final today = <NotificationSchedule>[];
    final upcoming = <NotificationSchedule>[];
    final overdue = <NotificationSchedule>[];
    final snoozed = <NotificationSchedule>[];
    final deferred = <NotificationSchedule>[];
    final completed = <NotificationSchedule>[];

    for (final s in schedules) {
      if (s.status == NotificationScheduleStatus.completed) {
        completed.add(s);
      } else if (s.isSnoozed && s.isActive) {
        snoozed.add(s);
      } else if (s.isDeferred && s.isActive) {
        deferred.add(s);
      } else if (s.isOverdueAlert || (s.originalScheduledAt.isBefore(todayStart) && s.isActive)) {
        overdue.add(s);
      } else if (s.scheduledAt.isAfter(todayStart) && s.scheduledAt.isBefore(todayEnd)) {
        today.add(s);
      } else if (s.scheduledAt.isAfter(todayEnd) && s.isActive) {
        upcoming.add(s);
      }
    }

    // Sort chronologically
    today.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    overdue.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt)); // Most recent overdue first
    snoozed.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    deferred.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    completed.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return {
      'today': today,
      'upcoming': upcoming,
      'overdue': overdue,
      'snoozed': snoozed,
      'deferred': deferred,
      'completed': completed,
    };
  }

  Future<List<NotificationHistoryEntry>> getAuditHistory(String userId, {int limit = 50}) async {
    return await _repository.getHistoryEntries(userId, limit: limit);
  }
}
