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
  final DateTime createdAt;

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
    required this.createdAt,
  });

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
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Bill {
  final String id;
  final String billAccountId;
  final String userId;
  final String billPeriod; // e.g. 'Oct 2026'
  final DateTime billDate;
  final DateTime dueDate;
  final double amount;
  final double minimumDue;
  final String status; // 'unpaid', 'paid', 'overdue', 'partially_paid'
  final String? invoiceDocumentId;
  final String? notes;

  Bill({
    required this.id,
    required this.billAccountId,
    required this.userId,
    required this.billPeriod,
    required this.billDate,
    required this.dueDate,
    required this.amount,
    this.minimumDue = 0.0,
    this.status = 'unpaid',
    this.invoiceDocumentId,
    this.notes,
  });

  factory Bill.fromMap(Map<String, dynamic> map, String id) {
    return Bill(
      id: id,
      billAccountId: map['billAccountId'] ?? '',
      userId: map['userId'] ?? '',
      billPeriod: map['billPeriod'] ?? '',
      billDate: map['billDate'] is Timestamp
          ? (map['billDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['billDate'].toString()) ?? DateTime.now(),
      dueDate: map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['dueDate'].toString()) ?? DateTime.now(),
      amount: (map['amount'] ?? 0.0).toDouble(),
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
      'billPeriod': billPeriod,
      'billDate': Timestamp.fromDate(billDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'amount': amount,
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
