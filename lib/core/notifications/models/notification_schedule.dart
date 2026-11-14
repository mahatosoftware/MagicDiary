import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_enums.dart';

class NotificationSchedule {
  final String id;
  final String userId;
  final String moduleId;
  final String categoryId;
  final String recordId;
  final String occurrenceId;
  final String eventType;
  final String notificationType; // 'reminder', 'snooze', 'defer', 'overdue'

  final DateTime scheduledAt;
  final String timezone;
  final DateTime originalScheduledAt;
  final String reminderOffset; // e.g. "-3d", "-1d", "0d", "snooze_1h", "overdue_1d"

  final NotificationScheduleStatus status;
  final String deliveryKey;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime? sentAt;
  final DateTime? claimLeaseExpiresAt;
  final String? claimedByWorker;
  final String? errorMessage;

  final ScheduleSource scheduleSource;
  final bool isSnoozed;
  final bool isDeferred;
  final int snoozeCount;

  final int localNotificationId;
  final Map<String, dynamic> payload;

  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationSchedule({
    required this.id,
    required this.userId,
    required this.moduleId,
    required this.categoryId,
    required this.recordId,
    this.occurrenceId = 'occ_default',
    required this.eventType,
    this.notificationType = 'reminder',
    required this.scheduledAt,
    this.timezone = 'UTC',
    required this.originalScheduledAt,
    required this.reminderOffset,
    this.status = NotificationScheduleStatus.scheduled,
    String? deliveryKey,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.sentAt,
    this.claimLeaseExpiresAt,
    this.claimedByWorker,
    this.errorMessage,
    this.scheduleSource = ScheduleSource.defaultTemplate,
    this.isSnoozed = false,
    this.isDeferred = false,
    this.snoozeCount = 0,
    required this.localNotificationId,
    this.payload = const {},
    required this.createdAt,
    required this.updatedAt,
  }) : deliveryKey = deliveryKey ?? '${userId}_${recordId}_${occurrenceId}_${notificationType}_$reminderOffset';

  static String generateDeliveryKey({
    required String userId,
    required String recordId,
    String occurrenceId = 'occ_default',
    String notificationType = 'reminder',
    required String reminderOffset,
  }) =>
      '${userId}_${recordId}_${occurrenceId}_${notificationType}_$reminderOffset';

  bool get isActive =>
      status == NotificationScheduleStatus.scheduled ||
      status == NotificationScheduleStatus.snoozed ||
      status == NotificationScheduleStatus.deferred;

  bool get isOverdueAlert => notificationType == 'overdue' || reminderOffset.startsWith('overdue');

  NotificationSchedule copyWith({
    String? id,
    String? userId,
    String? moduleId,
    String? categoryId,
    String? recordId,
    String? occurrenceId,
    String? eventType,
    String? notificationType,
    DateTime? scheduledAt,
    String? timezone,
    DateTime? originalScheduledAt,
    String? reminderOffset,
    NotificationScheduleStatus? status,
    String? deliveryKey,
    int? attemptCount,
    DateTime? lastAttemptAt,
    DateTime? sentAt,
    DateTime? claimLeaseExpiresAt,
    String? claimedByWorker,
    String? errorMessage,
    ScheduleSource? scheduleSource,
    bool? isSnoozed,
    bool? isDeferred,
    int? snoozeCount,
    int? localNotificationId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationSchedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moduleId: moduleId ?? this.moduleId,
      categoryId: categoryId ?? this.categoryId,
      recordId: recordId ?? this.recordId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      eventType: eventType ?? this.eventType,
      notificationType: notificationType ?? this.notificationType,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      timezone: timezone ?? this.timezone,
      originalScheduledAt: originalScheduledAt ?? this.originalScheduledAt,
      reminderOffset: reminderOffset ?? this.reminderOffset,
      status: status ?? this.status,
      deliveryKey: deliveryKey ?? this.deliveryKey,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      sentAt: sentAt ?? this.sentAt,
      claimLeaseExpiresAt: claimLeaseExpiresAt ?? this.claimLeaseExpiresAt,
      claimedByWorker: claimedByWorker ?? this.claimedByWorker,
      errorMessage: errorMessage ?? this.errorMessage,
      scheduleSource: scheduleSource ?? this.scheduleSource,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      isDeferred: isDeferred ?? this.isDeferred,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      localNotificationId: localNotificationId ?? this.localNotificationId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'moduleId': moduleId,
        'categoryId': categoryId,
        'recordId': recordId,
        'occurrenceId': occurrenceId,
        'eventType': eventType,
        'notificationType': notificationType,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'timezone': timezone,
        'originalScheduledAt': Timestamp.fromDate(originalScheduledAt),
        'reminderOffset': reminderOffset,
        'status': status.name,
        'deliveryKey': deliveryKey,
        'attemptCount': attemptCount,
        if (lastAttemptAt != null) 'lastAttemptAt': Timestamp.fromDate(lastAttemptAt!),
        if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
        if (claimLeaseExpiresAt != null)
          'claimLeaseExpiresAt': Timestamp.fromDate(claimLeaseExpiresAt!),
        if (claimedByWorker != null) 'claimedByWorker': claimedByWorker,
        if (errorMessage != null) 'errorMessage': errorMessage,
        'scheduleSource': scheduleSource.name,
        'isSnoozed': isSnoozed,
        'isDeferred': isDeferred,
        'snoozeCount': snoozeCount,
        'localNotificationId': localNotificationId,
        'payload': payload,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory NotificationSchedule.fromMap(Map<String, dynamic> map, [String? docId]) {
    final now = DateTime.now();
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? now;
      return now;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final userId = map['userId'] as String? ?? '';
    final recordId = map['recordId'] as String? ?? '';
    final occurrenceId = map['occurrenceId'] as String? ?? 'occ_default';
    final notificationType = map['notificationType'] as String? ?? 'reminder';
    final reminderOffset = map['reminderOffset'] as String? ?? '0d';

    return NotificationSchedule(
      id: docId ?? map['id'] as String? ?? 'sched_${now.millisecondsSinceEpoch}',
      userId: userId,
      moduleId: map['moduleId'] as String? ?? 'general',
      categoryId: map['categoryId'] as String? ?? 'general',
      recordId: recordId,
      occurrenceId: occurrenceId,
      eventType: map['eventType'] as String? ?? 'general',
      notificationType: notificationType,
      scheduledAt: parseDate(map['scheduledAt']),
      timezone: map['timezone'] as String? ?? 'UTC',
      originalScheduledAt: parseDate(map['originalScheduledAt']),
      reminderOffset: reminderOffset,
      status: NotificationScheduleStatus.fromString(map['status'] as String?),
      deliveryKey: map['deliveryKey'] as String? ??
          NotificationSchedule.generateDeliveryKey(
            userId: userId,
            recordId: recordId,
            occurrenceId: occurrenceId,
            notificationType: notificationType,
            reminderOffset: reminderOffset,
          ),
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
      lastAttemptAt: parseNullableDate(map['lastAttemptAt']),
      sentAt: parseNullableDate(map['sentAt']),
      claimLeaseExpiresAt: parseNullableDate(map['claimLeaseExpiresAt']),
      claimedByWorker: map['claimedByWorker'] as String?,
      errorMessage: map['errorMessage'] as String?,
      scheduleSource: ScheduleSource.fromString(map['scheduleSource'] as String?),
      isSnoozed: map['isSnoozed'] as bool? ?? false,
      isDeferred: map['isDeferred'] as bool? ?? false,
      snoozeCount: (map['snoozeCount'] as num?)?.toInt() ?? 0,
      localNotificationId: (map['localNotificationId'] as num?)?.toInt() ?? 0,
      payload: map['payload'] is Map
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : const {},
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
