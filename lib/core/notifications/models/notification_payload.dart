import 'dart:convert';

class NotificationPayload {
  final String scheduleId;
  final String recordId;
  final String moduleId;
  final String categoryId;
  final String eventType;
  final String occurrenceId;
  final String title;
  final String body;
  final double? amount;
  final String currency;
  final DateTime dueDate;
  final String? actionRoute;
  final String actionType;
  final String notificationType;
  final bool isOverdue;

  const NotificationPayload({
    required this.scheduleId,
    required this.recordId,
    required this.moduleId,
    required this.categoryId,
    required this.eventType,
    this.occurrenceId = 'occ_default',
    required this.title,
    required this.body,
    this.amount,
    this.currency = 'INR',
    required this.dueDate,
    this.actionRoute,
    this.actionType = 'OPEN',
    this.notificationType = 'reminder',
    this.isOverdue = false,
  });

  Map<String, dynamic> toMap() => {
        'scheduleId': scheduleId,
        'recordId': recordId,
        'moduleId': moduleId,
        'categoryId': categoryId,
        'eventType': eventType,
        'occurrenceId': occurrenceId,
        'title': title,
        'body': body,
        if (amount != null) 'amount': amount,
        'currency': currency,
        'dueDate': dueDate.toIso8601String(),
        if (actionRoute != null) 'actionRoute': actionRoute,
        'actionType': actionType,
        'notificationType': notificationType,
        'isOverdue': isOverdue,
      };

  String toJsonString() => jsonEncode(toMap());

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return NotificationPayload(
      scheduleId: map['scheduleId'] as String? ?? '',
      recordId: map['recordId'] as String? ?? '',
      moduleId: map['moduleId'] as String? ?? 'general',
      categoryId: map['categoryId'] as String? ?? 'general',
      eventType: map['eventType'] as String? ?? 'general',
      occurrenceId: map['occurrenceId'] as String? ?? 'occ_default',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? 'INR',
      dueDate: parseDate(map['dueDate']),
      actionRoute: map['actionRoute'] as String?,
      actionType: map['actionType'] as String? ?? 'OPEN',
      notificationType: map['notificationType'] as String? ?? 'reminder',
      isOverdue: map['isOverdue'] as bool? ?? false,
    );
  }

  factory NotificationPayload.fromJsonString(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) {
        return NotificationPayload.fromMap(map);
      }
    } catch (_) {}
    return NotificationPayload(
      scheduleId: '',
      recordId: '',
      moduleId: 'general',
      categoryId: 'general',
      eventType: 'general',
      title: 'Reminder',
      body: 'You have a pending commitment.',
      dueDate: DateTime.now(),
    );
  }
}
