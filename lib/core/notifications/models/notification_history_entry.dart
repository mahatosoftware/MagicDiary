import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_enums.dart';

class NotificationHistoryEntry {
  final String id;
  final String notificationId;
  final String recordId;
  final String moduleId;
  final String eventType;
  final String title;
  final String body;
  final NotificationScheduleStatus status;
  final DateTime scheduledAt;
  final DateTime? deliveredAt;
  final DateTime? displayedAt;
  final DateTime? openedAt;
  final String? actionTaken;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const NotificationHistoryEntry({
    required this.id,
    required this.notificationId,
    required this.recordId,
    required this.moduleId,
    required this.eventType,
    required this.title,
    required this.body,
    required this.status,
    required this.scheduledAt,
    this.deliveredAt,
    this.displayedAt,
    this.openedAt,
    this.actionTaken,
    this.metadata = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'notificationId': notificationId,
        'recordId': recordId,
        'moduleId': moduleId,
        'eventType': eventType,
        'title': title,
        'body': body,
        'status': status.name,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
        if (displayedAt != null) 'displayedAt': Timestamp.fromDate(displayedAt!),
        if (openedAt != null) 'openedAt': Timestamp.fromDate(openedAt!),
        if (actionTaken != null) 'actionTaken': actionTaken,
        'metadata': metadata,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory NotificationHistoryEntry.fromMap(Map<String, dynamic> map, [String? docId]) {
    final now = DateTime.now();
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return NotificationHistoryEntry(
      id: docId ?? map['id'] as String? ?? 'hist_${now.millisecondsSinceEpoch}',
      notificationId: map['notificationId'] as String? ?? '',
      recordId: map['recordId'] as String? ?? '',
      moduleId: map['moduleId'] as String? ?? 'general',
      eventType: map['eventType'] as String? ?? 'general',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      status: NotificationScheduleStatus.fromString(map['status'] as String?),
      scheduledAt: parseDate(map['scheduledAt']) ?? now,
      deliveredAt: parseDate(map['deliveredAt']),
      displayedAt: parseDate(map['displayedAt']),
      openedAt: parseDate(map['openedAt']),
      actionTaken: map['actionTaken'] as String?,
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const {},
      createdAt: parseDate(map['createdAt']) ?? now,
    );
  }
}
