import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String module; // 'SchoolFees', 'Bills', 'Vehicle', 'Household', 'Property', 'Warranty', 'Finance', 'Personal', 'General'
  final String status; // 'pending', 'snoozed', 'completed'
  final DateTime dueDate;
  final String? relatedId;
  final double? amount;
  final String? currencyCode;
  final String? actionRoute;
  final DateTime? snoozedUntil;
  final DateTime? completedAt;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.module,
    this.status = 'pending',
    required this.dueDate,
    this.relatedId,
    this.amount,
    this.currencyCode = 'INR',
    this.actionRoute,
    this.snoozedUntil,
    this.completedAt,
    required this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isSnoozed => status == 'snoozed';
  bool get isPending => status == 'pending';

  bool isOverdue(DateTime now) {
    if (isCompleted) return false;
    final todayStart = DateTime(now.year, now.month, now.day);
    return dueDate.isBefore(todayStart);
  }

  bool isToday(DateTime now) {
    if (isCompleted) return false;
    return dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;
  }

  bool isUpcoming(DateTime now) {
    if (isCompleted) return false;
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return dueDate.isAfter(todayEnd);
  }

  int daysUntil(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return target.difference(today).inDays;
  }

  factory Reminder.fromMap(Map<String, dynamic> map, String id) {
    return Reminder(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      module: map['module'] ?? 'General',
      status: map['status'] ?? 'pending',
      dueDate: map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['dueDate'].toString()) ?? DateTime.now(),
      relatedId: map['relatedId'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      currencyCode: map['currencyCode'] as String? ?? 'INR',
      actionRoute: map['actionRoute'] as String?,
      snoozedUntil: map['snoozedUntil'] is Timestamp
          ? (map['snoozedUntil'] as Timestamp).toDate()
          : (map['snoozedUntil'] != null ? DateTime.tryParse(map['snoozedUntil'].toString()) : null),
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : (map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'module': module,
      'status': status,
      'dueDate': Timestamp.fromDate(dueDate),
      if (relatedId != null) 'relatedId': relatedId,
      if (amount != null) 'amount': amount,
      if (currencyCode != null) 'currencyCode': currencyCode,
      if (actionRoute != null) 'actionRoute': actionRoute,
      'snoozedUntil': snoozedUntil != null ? Timestamp.fromDate(snoozedUntil!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Reminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? module,
    String? status,
    DateTime? dueDate,
    String? relatedId,
    double? amount,
    String? currencyCode,
    String? actionRoute,
    DateTime? snoozedUntil,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      module: module ?? this.module,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      relatedId: relatedId ?? this.relatedId,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      actionRoute: actionRoute ?? this.actionRoute,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
