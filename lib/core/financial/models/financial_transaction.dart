import 'package:cloud_firestore/cloud_firestore.dart';

/// Enumeration of distinct financial transaction types.
enum TransactionType {
  income,
  expense,
  transfer,
  refund,
  reimbursement,
  adjustment;

  String toDbString() => name;

  static TransactionType fromString(String? value) {
    if (value == null) return TransactionType.expense;
    final lower = value.toLowerCase().trim();
    switch (lower) {
      case 'income':
        return TransactionType.income;
      case 'transfer':
        return TransactionType.transfer;
      case 'refund':
        return TransactionType.refund;
      case 'reimbursement':
        return TransactionType.reimbursement;
      case 'adjustment':
        return TransactionType.adjustment;
      case 'expense':
      default:
        return TransactionType.expense;
    }
  }
}

/// Execution status of a financial transaction.
enum TransactionStatus {
  pending,
  completed,
  cancelled,
  failed;

  String toDbString() => name;

  static TransactionStatus fromString(String? value) {
    if (value == null) return TransactionStatus.completed;
    final lower = value.toLowerCase().trim();
    switch (lower) {
      case 'pending':
        return TransactionStatus.pending;
      case 'cancelled':
        return TransactionStatus.cancelled;
      case 'failed':
        return TransactionStatus.failed;
      case 'completed':
      case 'paid':
      default:
        return TransactionStatus.completed;
    }
  }
}

/// Canonical Financial Transaction Model.
/// Serves as the single source of truth for all actual money movements
/// across all Magic Diary modules (Personal Finance, Household, Education,
/// Vehicle Maintenance, Property, and Bills).
class FinancialTransaction {
  final String id;
  final String userId;

  final TransactionType type;
  final TransactionStatus status;

  /// Amount stored as an integer in the smallest currency unit (e.g., paise for INR, cents for USD)
  /// to eliminate floating-point precision and rounding errors in accounting calculations.
  final int amountMinorUnits;
  final String currencyCode; // ISO 4217 code, e.g. "INR", "USD"

  final String categoryId;
  final String? subcategoryId;

  final String sourceModule; // e.g. "finance", "household", "education", "vehicle", "property", "bills"
  final String? sourceRecordId;

  final String description;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? accountId;
  final String? paymentMethod; // e.g. "UPI", "Credit Card", "Net Banking", "Cash"
  final String? merchantOrPayee;
  final String? notes;

  final String? linkedTransactionId; // e.g., the original transaction that this refund applies to
  final String? transferGroupId; // Links debit and credit legs of an internal account transfer

  final bool isRecurring;
  final String? recurrenceId;

  final bool isDeleted;
  final int schemaVersion;

  const FinancialTransaction({
    required this.id,
    required this.userId,
    required this.type,
    this.status = TransactionStatus.completed,
    required this.amountMinorUnits,
    this.currencyCode = 'INR',
    required this.categoryId,
    this.subcategoryId,
    required this.sourceModule,
    this.sourceRecordId,
    required this.description,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.accountId,
    this.paymentMethod,
    this.merchantOrPayee,
    this.notes,
    this.linkedTransactionId,
    this.transferGroupId,
    this.isRecurring = false,
    this.recurrenceId,
    this.isDeleted = false,
    this.schemaVersion = 1,
  });

  /// Major units helper getter (e.g., rupees or dollars)
  double get amount => amountMinorUnits / 100.0;
  double get amountMajorUnits => amountMinorUnits / 100.0;

  /// Generate a deterministic, idempotent ID for transactions originating from other diary records
  static String generateDeterministicId(String sourceModule, String sourceRecordId) {
    final cleanModule = sourceModule.trim().toLowerCase();
    final cleanRecordId = sourceRecordId.trim();
    return 'txn_${cleanModule}_$cleanRecordId';
  }

  /// Create a transaction by providing standard major currency units (e.g., rupees)
  factory FinancialTransaction.fromMajorUnits({
    required String id,
    required String userId,
    required TransactionType type,
    TransactionStatus status = TransactionStatus.completed,
    required double amountMajor,
    String currencyCode = 'INR',
    required String categoryId,
    String? subcategoryId,
    required String sourceModule,
    String? sourceRecordId,
    required String description,
    required DateTime transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? accountId,
    String? paymentMethod,
    String? merchantOrPayee,
    String? notes,
    String? linkedTransactionId,
    String? transferGroupId,
    bool isRecurring = false,
    String? recurrenceId,
    bool isDeleted = false,
    int schemaVersion = 1,
  }) {
    final now = DateTime.now();
    return FinancialTransaction(
      id: id,
      userId: userId,
      type: type,
      status: status,
      amountMinorUnits: (amountMajor * 100).round(),
      currencyCode: currencyCode,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      sourceModule: sourceModule,
      sourceRecordId: sourceRecordId,
      description: description,
      transactionDate: transactionDate,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      accountId: accountId,
      paymentMethod: paymentMethod,
      merchantOrPayee: merchantOrPayee,
      notes: notes,
      linkedTransactionId: linkedTransactionId,
      transferGroupId: transferGroupId,
      isRecurring: isRecurring,
      recurrenceId: recurrenceId,
      isDeleted: isDeleted,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'type': type.toDbString(),
        'status': status.toDbString(),
        'amountMinorUnits': amountMinorUnits,
        'amount': amount, // Kept for backward compatibility with existing queries/views
        'currencyCode': currencyCode,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'sourceModule': sourceModule,
        'sourceRecordId': sourceRecordId,
        'description': description,
        'transactionDate': Timestamp.fromDate(transactionDate),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'accountId': accountId,
        'paymentMethod': paymentMethod,
        'merchantOrPayee': merchantOrPayee,
        'notes': notes,
        'linkedTransactionId': linkedTransactionId,
        'transferGroupId': transferGroupId,
        'isRecurring': isRecurring,
        'recurrenceId': recurrenceId,
        'isDeleted': isDeleted,
        'schemaVersion': schemaVersion,
      };

  Map<String, dynamic> toJson() => toMap();

  factory FinancialTransaction.fromMap(Map<String, dynamic> map, [String? docId]) {
    final id = docId ?? map['id'] as String? ?? '';

    // Handle amount minor vs legacy major units
    int minorUnits;
    if (map['amountMinorUnits'] != null) {
      minorUnits = (map['amountMinorUnits'] as num).toInt();
    } else if (map['amount'] != null) {
      minorUnits = ((map['amount'] as num).toDouble() * 100).round();
    } else {
      minorUnits = 0;
    }

    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback ?? DateTime.now();
    }

    final txDate = parseDate(map['transactionDate'] ?? map['date']);
    final created = parseDate(map['createdAt'], txDate);
    final updated = parseDate(map['updatedAt'], created);

    return FinancialTransaction(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: TransactionType.fromString(map['type'] as String?),
      status: TransactionStatus.fromString(map['status'] as String?),
      amountMinorUnits: minorUnits,
      currencyCode: map['currencyCode'] as String? ?? 'INR',
      categoryId: map['categoryId'] as String? ?? map['category'] as String? ?? 'Other',
      subcategoryId: map['subcategoryId'] as String?,
      sourceModule: map['sourceModule'] as String? ?? 'finance',
      sourceRecordId: map['sourceRecordId'] as String?,
      description: map['description'] as String? ?? '',
      transactionDate: txDate,
      createdAt: created,
      updatedAt: updated,
      accountId: map['accountId'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      merchantOrPayee: map['merchantOrPayee'] as String?,
      notes: map['notes'] as String?,
      linkedTransactionId: map['linkedTransactionId'] as String?,
      transferGroupId: map['transferGroupId'] as String?,
      isRecurring: map['isRecurring'] as bool? ?? false,
      recurrenceId: map['recurrenceId'] as String?,
      isDeleted: map['isDeleted'] as bool? ?? false,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) =>
      FinancialTransaction.fromMap(json);

  FinancialTransaction copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    TransactionStatus? status,
    int? amountMinorUnits,
    String? currencyCode,
    String? categoryId,
    String? subcategoryId,
    String? sourceModule,
    String? sourceRecordId,
    String? description,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? accountId,
    String? paymentMethod,
    String? merchantOrPayee,
    String? notes,
    String? linkedTransactionId,
    String? transferGroupId,
    bool? isRecurring,
    String? recurrenceId,
    bool? isDeleted,
    int? schemaVersion,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      currencyCode: currencyCode ?? this.currencyCode,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      sourceModule: sourceModule ?? this.sourceModule,
      sourceRecordId: sourceRecordId ?? this.sourceRecordId,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accountId: accountId ?? this.accountId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      merchantOrPayee: merchantOrPayee ?? this.merchantOrPayee,
      notes: notes ?? this.notes,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      transferGroupId: transferGroupId ?? this.transferGroupId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      isDeleted: isDeleted ?? this.isDeleted,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}
