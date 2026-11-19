import 'package:cloud_firestore/cloud_firestore.dart';

class BillAccount {
  final String id;
  final String userId;
  final String name; // e.g. "Airtel Postpaid", "HDFC Credit Card", "Times of India"
  final String category; // 'Telecom', 'Credit Card', 'Newspaper', 'Utility', 'Subscription', 'Rent', 'Other'
  final String providerName;
  final String accountNumber;
  final String billingCycle; // 'Monthly', 'Quarterly', 'Yearly'
  final int dueDayOfMonth; // 1-31
  final double defaultAmount;
  final bool autoReminder;
  final bool isAutopay;
  final String? paymentMethod;
  final bool isSubscription;
  final bool isUnusedFlagged;
  final DateTime createdAt;

  // Subscription & Free Trial Tracker fields
  final String subscriptionType; // 'paid', 'free_trial'
  final DateTime? trialEndsAt;
  final DateTime? renewalDate;
  final int reminderDaysBefore; // default 3 days
  final String? cancelUrl;
  final String? planTier; // e.g. 'Standard', 'Premium 4K', 'Family'
  final bool isActive;

  BillAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.providerName,
    required this.accountNumber,
    required this.billingCycle,
    required this.dueDayOfMonth,
    this.defaultAmount = 0.0,
    this.autoReminder = true,
    this.isAutopay = false,
    this.paymentMethod,
    this.isSubscription = false,
    this.isUnusedFlagged = false,
    required this.createdAt,
    this.subscriptionType = 'paid',
    this.trialEndsAt,
    this.renewalDate,
    this.reminderDaysBefore = 3,
    this.cancelUrl,
    this.planTier,
    this.isActive = true,
  });

  BillAccount copyWith({
    String? id,
    String? userId,
    String? name,
    String? category,
    String? providerName,
    String? accountNumber,
    String? billingCycle,
    int? dueDayOfMonth,
    double? defaultAmount,
    bool? autoReminder,
    bool? isAutopay,
    String? paymentMethod,
    bool? isSubscription,
    bool? isUnusedFlagged,
    DateTime? createdAt,
    String? subscriptionType,
    DateTime? trialEndsAt,
    DateTime? renewalDate,
    int? reminderDaysBefore,
    String? cancelUrl,
    String? planTier,
    bool? isActive,
  }) {
    return BillAccount(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      providerName: providerName ?? this.providerName,
      accountNumber: accountNumber ?? this.accountNumber,
      billingCycle: billingCycle ?? this.billingCycle,
      dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      autoReminder: autoReminder ?? this.autoReminder,
      isAutopay: isAutopay ?? this.isAutopay,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSubscription: isSubscription ?? this.isSubscription,
      isUnusedFlagged: isUnusedFlagged ?? this.isUnusedFlagged,
      createdAt: createdAt ?? this.createdAt,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      renewalDate: renewalDate ?? this.renewalDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      cancelUrl: cancelUrl ?? this.cancelUrl,
      planTier: planTier ?? this.planTier,
      isActive: isActive ?? this.isActive,
    );
  }

  factory BillAccount.fromMap(Map<String, dynamic> map, String id) {
    return BillAccount(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'Utility',
      providerName: map['providerName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      billingCycle: map['billingCycle'] ?? 'Monthly',
      dueDayOfMonth: map['dueDayOfMonth'] ?? 10,
      defaultAmount: (map['defaultAmount'] ?? 0.0).toDouble(),
      autoReminder: map['autoReminder'] ?? true,
      isAutopay: map['isAutopay'] ?? false,
      paymentMethod: map['paymentMethod'],
      isSubscription: map['isSubscription'] ?? false,
      isUnusedFlagged: map['isUnusedFlagged'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
      subscriptionType: map['subscriptionType'] ?? 'paid',
      trialEndsAt: map['trialEndsAt'] is Timestamp
          ? (map['trialEndsAt'] as Timestamp).toDate()
          : (map['trialEndsAt'] != null ? DateTime.tryParse(map['trialEndsAt'].toString()) : null),
      renewalDate: map['renewalDate'] is Timestamp
          ? (map['renewalDate'] as Timestamp).toDate()
          : (map['renewalDate'] != null ? DateTime.tryParse(map['renewalDate'].toString()) : null),
      reminderDaysBefore: (map['reminderDaysBefore'] as num?)?.toInt() ?? 3,
      cancelUrl: map['cancelUrl'],
      planTier: map['planTier'],
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'category': category,
      'providerName': providerName,
      'accountNumber': accountNumber,
      'billingCycle': billingCycle,
      'dueDayOfMonth': dueDayOfMonth,
      'defaultAmount': defaultAmount,
      'autoReminder': autoReminder,
      'isAutopay': isAutopay,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      'isSubscription': isSubscription,
      'isUnusedFlagged': isUnusedFlagged,
      'createdAt': Timestamp.fromDate(createdAt),
      'subscriptionType': subscriptionType,
      if (trialEndsAt != null) 'trialEndsAt': Timestamp.fromDate(trialEndsAt!),
      if (renewalDate != null) 'renewalDate': Timestamp.fromDate(renewalDate!),
      'reminderDaysBefore': reminderDaysBefore,
      if (cancelUrl != null) 'cancelUrl': cancelUrl,
      if (planTier != null) 'planTier': planTier,
      'isActive': isActive,
    };
  }
}

class Bill {
  final String id;
  final String billAccountId;
  final String userId;
  final String? title; // e.g. "BESCOM Electricity", "Airtel Broadband", etc.
  final String billPeriod; // e.g. 'Oct 2026'
  final DateTime billDate;
  final DateTime dueDate;
  final double amount;
  final double? expectedAmount;
  final double? previousAmount;
  final double lateFee;
  final double minimumDue;
  final String status; // 'unpaid', 'paid', 'overdue', 'partially_paid'
  final String? invoiceDocumentId;
  final String? notes;

  Bill({
    required this.id,
    required this.billAccountId,
    required this.userId,
    this.title,
    required this.billPeriod,
    required this.billDate,
    required this.dueDate,
    required this.amount,
    this.expectedAmount,
    this.previousAmount,
    this.lateFee = 0.0,
    this.minimumDue = 0.0,
    this.status = 'unpaid',
    this.invoiceDocumentId,
    this.notes,
  });

  /// Returns a clean, context-aware display title for the bill.
  /// Priority:
  /// 1. Explicit [title]
  /// 2. Provided [accountName]
  /// 3. Name extracted from [notes] (e.g. "Auto-generated bill for BESCOM Electricity")
  /// 4. Fallback to 'Bill'
  String displayTitle({String? accountName}) {
    final effectiveName = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : ((accountName != null && accountName.trim().isNotEmpty)
            ? accountName.trim()
            : _extractNameFromNotes());

    if (effectiveName.isNotEmpty) {
      return billPeriod.isNotEmpty ? '$effectiveName ($billPeriod)' : effectiveName;
    }
    return billPeriod.isNotEmpty ? 'Bill ($billPeriod)' : 'Bill';
  }

  String _extractNameFromNotes() {
    if (notes == null || notes!.isEmpty) return '';
    final autoGenMatch = RegExp(r'Auto-(?:generated bill|rolled over) for ([^(]+)').firstMatch(notes!);
    if (autoGenMatch != null && autoGenMatch.group(1) != null) {
      return autoGenMatch.group(1)!.trim();
    }
    return '';
  }

  Bill copyWith({
    String? id,
    String? billAccountId,
    String? userId,
    String? title,
    String? billPeriod,
    DateTime? billDate,
    DateTime? dueDate,
    double? amount,
    double? expectedAmount,
    double? previousAmount,
    double? lateFee,
    double? minimumDue,
    String? status,
    String? invoiceDocumentId,
    String? notes,
  }) {
    return Bill(
      id: id ?? this.id,
      billAccountId: billAccountId ?? this.billAccountId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      billPeriod: billPeriod ?? this.billPeriod,
      billDate: billDate ?? this.billDate,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      previousAmount: previousAmount ?? this.previousAmount,
      lateFee: lateFee ?? this.lateFee,
      minimumDue: minimumDue ?? this.minimumDue,
      status: status ?? this.status,
      invoiceDocumentId: invoiceDocumentId ?? this.invoiceDocumentId,
      notes: notes ?? this.notes,
    );
  }

  factory Bill.fromMap(Map<String, dynamic> map, String id) {
    return Bill(
      id: id,
      billAccountId: map['billAccountId'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'],
      billPeriod: map['billPeriod'] ?? '',
      billDate: map['billDate'] is Timestamp
          ? (map['billDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['billDate'].toString()) ?? DateTime.now(),
      dueDate: map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['dueDate'].toString()) ?? DateTime.now(),
      amount: (map['amount'] ?? 0.0).toDouble(),
      expectedAmount: (map['expectedAmount'] as num?)?.toDouble(),
      previousAmount: (map['previousAmount'] as num?)?.toDouble(),
      lateFee: (map['lateFee'] as num?)?.toDouble() ?? 0.0,
      minimumDue: (map['minimumDue'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'unpaid',
      invoiceDocumentId: map['invoiceDocumentId'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billAccountId': billAccountId,
      'userId': userId,
      if (title != null) 'title': title,
      'billPeriod': billPeriod,
      'billDate': Timestamp.fromDate(billDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'amount': amount,
      if (expectedAmount != null) 'expectedAmount': expectedAmount,
      if (previousAmount != null) 'previousAmount': previousAmount,
      'lateFee': lateFee,
      'minimumDue': minimumDue,
      'status': status,
      'invoiceDocumentId': invoiceDocumentId,
      'notes': notes,
    };
  }
}

class BillPayment {
  final String id;
  final String billId;
  final String billAccountId;
  final double amountPaid;
  final DateTime paymentDate;
  final String paymentMethod;
  final String transactionRef;
  final String? receiptDocumentId;
  final String? notes;

  BillPayment({
    required this.id,
    required this.billId,
    required this.billAccountId,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentMethod,
    required this.transactionRef,
    this.receiptDocumentId,
    this.notes,
  });

  factory BillPayment.fromMap(Map<String, dynamic> map, String id) {
    return BillPayment(
      id: id,
      billId: map['billId'] ?? '',
      billAccountId: map['billAccountId'] ?? '',
      amountPaid: (map['amountPaid'] ?? 0.0).toDouble(),
      paymentDate: map['paymentDate'] is Timestamp
          ? (map['paymentDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['paymentDate'].toString()) ?? DateTime.now(),
      paymentMethod: map['paymentMethod'] ?? 'UPI',
      transactionRef: map['transactionRef'] ?? '',
      receiptDocumentId: map['receiptDocumentId'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'billAccountId': billAccountId,
      'amountPaid': amountPaid,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'paymentMethod': paymentMethod,
      'transactionRef': transactionRef,
      'receiptDocumentId': receiptDocumentId,
      'notes': notes,
    };
  }
}
