import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_enums.dart';

class NotificationActionRecord {
  final String id;
  final String notificationId;
  final String recordId;
  final NotificationActionType actionType;
  final DateTime? originalDate;
  final DateTime? newDate;
  final int? snoozeDurationMinutes;
  final String? deferReason;
  final String? occurrenceId;
  final DateTime performedAt;
  final String performedBy;
  final Map<String, dynamic> metadata;

  const NotificationActionRecord({
    required this.id,
    required this.notificationId,
    required this.recordId,
    required this.actionType,
    this.originalDate,
    this.newDate,
    this.snoozeDurationMinutes,
    this.deferReason,
    this.occurrenceId,
    required this.performedAt,
    required this.performedBy,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'notificationId': notificationId,
        'recordId': recordId,
        'actionType': actionType.actionId,
        if (originalDate != null) 'originalDate': Timestamp.fromDate(originalDate!),
        if (newDate != null) 'newDate': Timestamp.fromDate(newDate!),
        if (snoozeDurationMinutes != null) 'snoozeDuration': snoozeDurationMinutes,
        if (deferReason != null) 'deferReason': deferReason,
        if (occurrenceId != null) 'occurrenceId': occurrenceId,
        'performedAt': Timestamp.fromDate(performedAt),
        'performedBy': performedBy,
        'metadata': metadata,
      };

  factory NotificationActionRecord.fromMap(Map<String, dynamic> map, [String? docId]) {
    final now = DateTime.now();
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return NotificationActionRecord(
      id: docId ?? map['id'] as String? ?? 'act_${now.millisecondsSinceEpoch}',
      notificationId: map['notificationId'] as String? ?? '',
      recordId: map['recordId'] as String? ?? '',
      actionType: NotificationActionType.fromString(map['actionType'] as String?),
      originalDate: parseDate(map['originalDate']),
      newDate: parseDate(map['newDate']),
      snoozeDurationMinutes: (map['snoozeDuration'] as num?)?.toInt(),
      deferReason: map['deferReason'] as String?,
      occurrenceId: map['occurrenceId'] as String?,
      performedAt: parseDate(map['performedAt']) ?? now,
      performedBy: map['performedBy'] as String? ?? 'user',
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const {},
    );
  }
}
