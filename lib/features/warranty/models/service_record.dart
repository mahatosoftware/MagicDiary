import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRecord {
  final String id;
  final String productId;
  final DateTime serviceDate;
  final String serviceType; // 'Routine Maintenance', 'Repair', 'Inspection', 'Part Replacement'
  final String workPerformed;
  final double totalCost;
  final String currency;
  final String serviceCenter;
  final String? invoiceDocumentId;
  final DateTime? nextServiceDate;
  final String? notes;
  final DateTime createdAt;

  ServiceRecord({
    required this.id,
    required this.productId,
    required this.serviceDate,
    required this.serviceType,
    required this.workPerformed,
    required this.totalCost,
    this.currency = '₹',
    required this.serviceCenter,
    this.invoiceDocumentId,
    this.nextServiceDate,
    this.notes,
    required this.createdAt,
  });

  factory ServiceRecord.fromMap(Map<String, dynamic> map, String id) {
    return ServiceRecord(
      id: id,
      productId: map['productId'] ?? '',
      serviceDate: map['serviceDate'] is Timestamp 
          ? (map['serviceDate'] as Timestamp).toDate() 
          : DateTime.tryParse(map['serviceDate'].toString()) ?? DateTime.now(),
      serviceType: map['serviceType'] ?? 'Routine Maintenance',
      workPerformed: map['workPerformed'] ?? '',
      totalCost: (map['totalCost'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? '₹',
      serviceCenter: map['serviceCenter'] ?? '',
      invoiceDocumentId: map['invoiceDocumentId'],
      nextServiceDate: map['nextServiceDate'] is Timestamp
          ? (map['nextServiceDate'] as Timestamp).toDate()
          : (map['nextServiceDate'] != null ? DateTime.tryParse(map['nextServiceDate'].toString()) : null),
      notes: map['notes'],
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'serviceDate': Timestamp.fromDate(serviceDate),
      'serviceType': serviceType,
      'workPerformed': workPerformed,
      'totalCost': totalCost,
      'currency': currency,
      'serviceCenter': serviceCenter,
      'invoiceDocumentId': invoiceDocumentId,
      'nextServiceDate': nextServiceDate != null ? Timestamp.fromDate(nextServiceDate!) : null,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
