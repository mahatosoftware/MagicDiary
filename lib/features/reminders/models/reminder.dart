import 'package:cloud_firestore/cloud_firestore.dart';

/// Structured payment audit and details for financial reminders.
class ReminderPaymentDetails {
  final double amount;
  final String currency;
  final DateTime paidAt;
  final String paymentMethod; // 'UPI', 'Cash', 'Bank Transfer', 'Card', 'Cheque', 'Other'
  final String? transactionReference;
  final String? notes;
  final String? receiptUrl;

  const ReminderPaymentDetails({
    required this.amount,
    this.currency = 'INR',
    required this.paidAt,
    this.paymentMethod = 'UPI',
    this.transactionReference,
    this.notes,
    this.receiptUrl,
  });

  factory ReminderPaymentDetails.fromMap(Map<String, dynamic> map) {
    return ReminderPaymentDetails(
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'INR',
      paidAt: map['paidAt'] is Timestamp
          ? (map['paidAt'] as Timestamp).toDate()
          : (map['paidAt'] != null
              ? DateTime.tryParse(map['paidAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      paymentMethod: map['paymentMethod'] as String? ?? 'UPI',
      transactionReference: map['transactionReference'] as String?,
      notes: map['notes'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'currency': currency,
      'paidAt': Timestamp.fromDate(paidAt),
      'paymentMethod': paymentMethod,
      if (transactionReference != null && transactionReference!.isNotEmpty)
        'transactionReference': transactionReference,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (receiptUrl != null && receiptUrl!.isNotEmpty) 'receiptUrl': receiptUrl,
    };
  }

  ReminderPaymentDetails copyWith({
    double? amount,
    String? currency,
    DateTime? paidAt,
    String? paymentMethod,
    String? transactionReference,
    String? notes,
    String? receiptUrl,
  }) {
    return ReminderPaymentDetails(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paidAt: paidAt ?? this.paidAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionReference: transactionReference ?? this.transactionReference,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }
}

class Reminder {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String module; // 'SchoolFees', 'Bills', 'Vehicle', 'Household', 'Property', 'Warranty', 'Finance', 'Personal', 'General'
  final String status; // 'pending', 'due', 'overdue', 'snoozed', 'completed', 'paid', 'skipped', 'cancelled'
  final DateTime dueDate;
  final String? relatedId;
  final String? linkedRecordId;
  final String? linkedDiaryId;
  final double? amount;
  final String? currencyCode;
  final String? actionRoute;
  final String actionType; // 'mark_paid', 'mark_complete', 'mark_resolved', 'mark_acknowledged', 'custom' or legacy ('Pay', 'Complete', etc.)
  final bool? isFinancial;
  final String priority; // 'high', 'medium', 'low'
  final String? assignedTo; // For household / family delegation
  final DateTime? snoozedUntil;
  final DateTime? completedAt;
  final String? completedBy;
  final String? occurrenceId;
  final ReminderPaymentDetails? paymentDetails;
  final String? completionNotes;
  final String? serviceProvider;
  final double? actualCost;
  final List<int>? remindBeforeDays;
  final String? repeatSchedule;
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
    this.linkedRecordId,
    this.linkedDiaryId,
    this.amount,
    this.currencyCode = 'INR',
    this.actionRoute,
    this.actionType = 'Complete',
    this.isFinancial,
    this.priority = 'medium',
    this.assignedTo,
    this.snoozedUntil,
    this.completedAt,
    this.completedBy,
    this.occurrenceId,
    this.paymentDetails,
    this.completionNotes,
    this.serviceProvider,
    this.actualCost,
    this.remindBeforeDays,
    this.repeatSchedule,
    required this.createdAt,
  });

  bool get isCompleted => status == 'completed' || status == 'paid';
  bool get isPaid => status == 'paid';
  bool get isSnoozed => status == 'snoozed';
  bool get isPending => status == 'pending' || status == 'due' || status == 'overdue';

  String get effectiveLinkedRecordId => linkedRecordId ?? relatedId ?? '';
  String get effectiveLinkedDiaryId => linkedDiaryId ?? module;

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
    final paymentMap = map['payment'] ?? map['paymentDetails'];
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
      linkedRecordId: map['linkedRecordId'] as String? ?? map['relatedId'] as String?,
      linkedDiaryId: map['linkedDiaryId'] as String? ?? map['module'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      currencyCode: map['currencyCode'] as String? ?? 'INR',
      actionRoute: map['actionRoute'] as String?,
      actionType: map['actionType'] as String? ?? 'Complete',
      isFinancial: map['isFinancial'] as bool?,
      priority: map['priority'] as String? ?? 'medium',
      assignedTo: map['assignedTo'] as String?,
      snoozedUntil: map['snoozedUntil'] is Timestamp
          ? (map['snoozedUntil'] as Timestamp).toDate()
          : (map['snoozedUntil'] != null ? DateTime.tryParse(map['snoozedUntil'].toString()) : null),
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : (map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null),
      completedBy: map['completedBy'] as String?,
      occurrenceId: map['occurrenceId'] as String?,
      paymentDetails: paymentMap is Map<String, dynamic> ? ReminderPaymentDetails.fromMap(paymentMap) : null,
      completionNotes: map['completionNotes'] as String?,
      serviceProvider: map['serviceProvider'] as String?,
      actualCost: (map['actualCost'] as num?)?.toDouble(),
      remindBeforeDays: (map['remindBeforeDays'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      repeatSchedule: map['repeatSchedule'] as String?,
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
      if (linkedRecordId != null) 'linkedRecordId': linkedRecordId,
      if (linkedDiaryId != null) 'linkedDiaryId': linkedDiaryId,
      if (amount != null) 'amount': amount,
      if (currencyCode != null) 'currencyCode': currencyCode,
      if (actionRoute != null) 'actionRoute': actionRoute,
      'actionType': actionType,
      if (isFinancial != null) 'isFinancial': isFinancial,
      'priority': priority,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (completedBy != null) 'completedBy': completedBy,
      if (occurrenceId != null) 'occurrenceId': occurrenceId,
      if (paymentDetails != null) 'payment': paymentDetails!.toMap(),
      if (completionNotes != null) 'completionNotes': completionNotes,
      if (serviceProvider != null) 'serviceProvider': serviceProvider,
      if (actualCost != null) 'actualCost': actualCost,
      if (remindBeforeDays != null) 'remindBeforeDays': remindBeforeDays,
      if (repeatSchedule != null) 'repeatSchedule': repeatSchedule,
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
    String? linkedRecordId,
    String? linkedDiaryId,
    double? amount,
    String? currencyCode,
    String? actionRoute,
    String? actionType,
    bool? isFinancial,
    String? priority,
    String? assignedTo,
    DateTime? snoozedUntil,
    DateTime? completedAt,
    String? completedBy,
    String? occurrenceId,
    ReminderPaymentDetails? paymentDetails,
    String? completionNotes,
    String? serviceProvider,
    double? actualCost,
    List<int>? remindBeforeDays,
    String? repeatSchedule,
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
      linkedRecordId: linkedRecordId ?? this.linkedRecordId,
      linkedDiaryId: linkedDiaryId ?? this.linkedDiaryId,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      actionRoute: actionRoute ?? this.actionRoute,
      actionType: actionType ?? this.actionType,
      isFinancial: isFinancial ?? this.isFinancial,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      completionNotes: completionNotes ?? this.completionNotes,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      actualCost: actualCost ?? this.actualCost,
      remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
      repeatSchedule: repeatSchedule ?? this.repeatSchedule,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
