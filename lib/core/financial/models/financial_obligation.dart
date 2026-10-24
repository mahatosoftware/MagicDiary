import 'package:cloud_firestore/cloud_firestore.dart';

enum ObligationStatus {
  pending,
  partiallyPaid,
  paid,
  overdue,
  cancelled;

  String toDbString() {
    switch (this) {
      case ObligationStatus.partiallyPaid:
        return 'partially_paid';
      default:
        return name;
    }
  }

  static ObligationStatus fromString(String? val, [DateTime? dueDate]) {
    if (val == null) return ObligationStatus.pending;
    final lower = val.toLowerCase().trim();
    switch (lower) {
      case 'paid':
      case 'completed':
        return ObligationStatus.paid;
      case 'partially_paid':
      case 'partial':
        return ObligationStatus.partiallyPaid;
      case 'cancelled':
        return ObligationStatus.cancelled;
      case 'overdue':
        return ObligationStatus.overdue;
      case 'pending':
      case 'unpaid':
      default:
        if (dueDate != null && dueDate.isBefore(DateTime.now())) {
          return ObligationStatus.overdue;
        }
        return ObligationStatus.pending;
    }
  }
}

/// Represents an amount expected to become payable or receivable in the future
/// (such as school fees, property tax, utility bills, insurance renewals, or service estimates).
///
/// Obligation records are NOT completed financial transactions and must never be
/// tallied into actual expense cash flows until completed payments are recorded.
class FinancialObligation {
  final String id;
  final String userId;
  final String title;
  final String categoryId;
  final String? subcategoryId;

  final String sourceModule; // e.g. "household", "school_fees", "bills", "property", "vehicle"
  final String? sourceRecordId;

  final int expectedAmountMinorUnits;
  final int paidAmountMinorUnits;
  final String currencyCode;

  final DateTime dueDate;
  final ObligationStatus status;
  final String? recurrenceId;
  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialObligation({
    required this.id,
    required this.userId,
    required this.title,
    required this.categoryId,
    this.subcategoryId,
    required this.sourceModule,
    this.sourceRecordId,
    required this.expectedAmountMinorUnits,
    this.paidAmountMinorUnits = 0,
    this.currencyCode = 'INR',
    required this.dueDate,
    this.status = ObligationStatus.pending,
    this.recurrenceId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get expectedAmount => expectedAmountMinorUnits / 100.0;
  double get paidAmount => paidAmountMinorUnits / 100.0;
  double get remainingAmount => (expectedAmountMinorUnits - paidAmountMinorUnits) / 100.0;
  int get daysRemaining => dueDate.difference(DateTime.now()).inDays;
  bool get isOverdue => (status != ObligationStatus.paid && status != ObligationStatus.cancelled) && dueDate.isBefore(DateTime.now());

  static String generateDeterministicId(String sourceModule, String sourceRecordId) {
    final cleanModule = sourceModule.trim().toLowerCase();
    final cleanRecordId = sourceRecordId.trim();
    return 'ob_${cleanModule}_$cleanRecordId';
  }

  factory FinancialObligation.fromMajorUnits({
    required String id,
    required String userId,
    required String title,
    required String categoryId,
    String? subcategoryId,
    required String sourceModule,
    String? sourceRecordId,
    required double expectedAmountMajor,
    double paidAmountMajor = 0.0,
    String currencyCode = 'INR',
    required DateTime dueDate,
    ObligationStatus status = ObligationStatus.pending,
    String? recurrenceId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return FinancialObligation(
      id: id,
      userId: userId,
      title: title,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      sourceModule: sourceModule,
      sourceRecordId: sourceRecordId,
      expectedAmountMinorUnits: (expectedAmountMajor * 100).round(),
      paidAmountMinorUnits: (paidAmountMajor * 100).round(),
      currencyCode: currencyCode,
      dueDate: dueDate,
      status: status,
      recurrenceId: recurrenceId,
      notes: notes,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'sourceModule': sourceModule,
        'sourceRecordId': sourceRecordId,
        'expectedAmountMinorUnits': expectedAmountMinorUnits,
        'paidAmountMinorUnits': paidAmountMinorUnits,
        'expectedAmount': expectedAmount,
        'currencyCode': currencyCode,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': status.toDbString(),
        'recurrenceId': recurrenceId,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Map<String, dynamic> toJson() => toMap();

  factory FinancialObligation.fromMap(Map<String, dynamic> map, [String? docId]) {
    final id = docId ?? map['id'] as String? ?? '';

    int expectedMinor = 0;
    if (map['expectedAmountMinorUnits'] != null) {
      expectedMinor = (map['expectedAmountMinorUnits'] as num).toInt();
    } else if (map['expectedAmount'] != null) {
      expectedMinor = ((map['expectedAmount'] as num).toDouble() * 100).round();
    } else if (map['amount'] != null) {
      expectedMinor = ((map['amount'] as num).toDouble() * 100).round();
    }

    int paidMinor = 0;
    if (map['paidAmountMinorUnits'] != null) {
      paidMinor = (map['paidAmountMinorUnits'] as num).toInt();
    } else if (map['paidAmount'] != null) {
      paidMinor = ((map['paidAmount'] as num).toDouble() * 100).round();
    }

    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback ?? DateTime.now();
    }

    final due = parseDate(map['dueDate']);
    final created = parseDate(map['createdAt'], due);
    final updated = parseDate(map['updatedAt'], created);

    return FinancialObligation(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? map['category'] as String? ?? 'Other',
      subcategoryId: map['subcategoryId'] as String?,
      sourceModule: map['sourceModule'] as String? ?? 'general',
      sourceRecordId: map['sourceRecordId'] as String?,
      expectedAmountMinorUnits: expectedMinor,
      paidAmountMinorUnits: paidMinor,
      currencyCode: map['currencyCode'] as String? ?? 'INR',
      dueDate: due,
      status: ObligationStatus.fromString(map['status'] as String?, due),
      recurrenceId: map['recurrenceId'] as String?,
      notes: map['notes'] as String?,
      createdAt: created,
      updatedAt: updated,
    );
  }

  factory FinancialObligation.fromJson(Map<String, dynamic> json) =>
      FinancialObligation.fromMap(json);

  FinancialObligation copyWith({
    String? id,
    String? userId,
    String? title,
    String? categoryId,
    String? subcategoryId,
    String? sourceModule,
    String? sourceRecordId,
    int? expectedAmountMinorUnits,
    int? paidAmountMinorUnits,
    String? currencyCode,
    DateTime? dueDate,
    ObligationStatus? status,
    String? recurrenceId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialObligation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      sourceModule: sourceModule ?? this.sourceModule,
      sourceRecordId: sourceRecordId ?? this.sourceRecordId,
      expectedAmountMinorUnits: expectedAmountMinorUnits ?? this.expectedAmountMinorUnits,
      paidAmountMinorUnits: paidAmountMinorUnits ?? this.paidAmountMinorUnits,
      currencyCode: currencyCode ?? this.currencyCode,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
