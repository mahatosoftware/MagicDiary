import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String userId;
  final String name;
  final String category; // 'Electronics', 'Appliances', 'Gadgets', 'Vehicles', 'Furniture', 'Other'
  final String brand;
  final String? model;
  final String? serialNumber;
  final DateTime purchaseDate;
  final double price;
  final String currency;
  final String sellerInfo;
  final bool hasWarranty;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final int warrantyDurationMonths;
  final bool extendedWarranty;
  final String? extendedWarrantyProvider;
  final DateTime? extendedWarrantyExpiry;
  final int? returnWindowDays;
  final DateTime? returnDeadline;
  final String status; // 'active', 'transferred', 'disposed', 'archived'
  final bool isCustomWarranty;
  final String? warrantyType;
  final String? invoiceDocumentId;
  final String? warrantyCardDocumentId;
  final String? manualDocumentId;
  final List<String> imageUrls;
  final String? notes;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.brand,
    this.model,
    this.serialNumber,
    required this.purchaseDate,
    required this.price,
    this.currency = '₹',
    required this.sellerInfo,
    required this.hasWarranty,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.warrantyDurationMonths = 12,
    this.extendedWarranty = false,
    this.extendedWarrantyProvider,
    this.extendedWarrantyExpiry,
    this.returnWindowDays,
    this.returnDeadline,
    this.status = 'active',
    this.isCustomWarranty = false,
    this.warrantyType,
    this.invoiceDocumentId,
    this.warrantyCardDocumentId,
    this.manualDocumentId,
    this.imageUrls = const [],
    this.notes,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'Other',
      brand: map['brand'] ?? '',
      model: map['model'],
      serialNumber: map['serialNumber'],
      purchaseDate: map['purchaseDate'] is Timestamp 
          ? (map['purchaseDate'] as Timestamp).toDate() 
          : DateTime.tryParse(map['purchaseDate'].toString()) ?? DateTime.now(),
      price: (map['price'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? '₹',
      sellerInfo: map['sellerInfo'] ?? '',
      hasWarranty: map['hasWarranty'] ?? false,
      warrantyStartDate: map['warrantyStartDate'] is Timestamp
          ? (map['warrantyStartDate'] as Timestamp).toDate()
          : (map['warrantyStartDate'] != null ? DateTime.tryParse(map['warrantyStartDate'].toString()) : null),
      warrantyEndDate: map['warrantyEndDate'] is Timestamp
          ? (map['warrantyEndDate'] as Timestamp).toDate()
          : (map['warrantyEndDate'] != null ? DateTime.tryParse(map['warrantyEndDate'].toString()) : null),
      warrantyDurationMonths: map['warrantyDurationMonths'] ?? 12,
      extendedWarranty: map['extendedWarranty'] ?? false,
      extendedWarrantyProvider: map['extendedWarrantyProvider'],
      extendedWarrantyExpiry: map['extendedWarrantyExpiry'] is Timestamp
          ? (map['extendedWarrantyExpiry'] as Timestamp).toDate()
          : (map['extendedWarrantyExpiry'] != null ? DateTime.tryParse(map['extendedWarrantyExpiry'].toString()) : null),
      returnWindowDays: map['returnWindowDays'] as int?,
      returnDeadline: map['returnDeadline'] is Timestamp
          ? (map['returnDeadline'] as Timestamp).toDate()
          : (map['returnDeadline'] != null ? DateTime.tryParse(map['returnDeadline'].toString()) : null),
      status: map['status'] as String? ?? 'active',
      isCustomWarranty: map['isCustomWarranty'] ?? false,
      warrantyType: map['warrantyType'],
      invoiceDocumentId: map['invoiceDocumentId'],
      warrantyCardDocumentId: map['warrantyCardDocumentId'],
      manualDocumentId: map['manualDocumentId'],
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      notes: map['notes'],
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'category': category,
      'brand': brand,
      'model': model,
      'serialNumber': serialNumber,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'price': price,
      'currency': currency,
      'sellerInfo': sellerInfo,
      'hasWarranty': hasWarranty,
      'warrantyStartDate': warrantyStartDate != null ? Timestamp.fromDate(warrantyStartDate!) : null,
      'warrantyEndDate': warrantyEndDate != null ? Timestamp.fromDate(warrantyEndDate!) : null,
      'warrantyDurationMonths': warrantyDurationMonths,
      'extendedWarranty': extendedWarranty,
      'extendedWarrantyProvider': extendedWarrantyProvider,
      'extendedWarrantyExpiry': extendedWarrantyExpiry != null ? Timestamp.fromDate(extendedWarrantyExpiry!) : null,
      'returnWindowDays': returnWindowDays,
      'returnDeadline': returnDeadline != null ? Timestamp.fromDate(returnDeadline!) : null,
      'status': status,
      'isCustomWarranty': isCustomWarranty,
      'warrantyType': warrantyType,
      'invoiceDocumentId': invoiceDocumentId,
      'warrantyCardDocumentId': warrantyCardDocumentId,
      'manualDocumentId': manualDocumentId,
      'imageUrls': imageUrls,
      'notes': notes,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Product copyWith({
    String? name,
    String? category,
    String? brand,
    String? model,
    String? serialNumber,
    DateTime? purchaseDate,
    double? price,
    String? currency,
    String? sellerInfo,
    bool? hasWarranty,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    int? warrantyDurationMonths,
    bool? extendedWarranty,
    String? extendedWarrantyProvider,
    DateTime? extendedWarrantyExpiry,
    int? returnWindowDays,
    DateTime? returnDeadline,
    String? status,
    bool? isCustomWarranty,
    String? warrantyType,
    String? invoiceDocumentId,
    String? warrantyCardDocumentId,
    String? manualDocumentId,
    List<String>? imageUrls,
    String? notes,
    List<String>? tags,
  }) {
    return Product(
      id: id,
      userId: userId,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      sellerInfo: sellerInfo ?? this.sellerInfo,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      warrantyDurationMonths: warrantyDurationMonths ?? this.warrantyDurationMonths,
      extendedWarranty: extendedWarranty ?? this.extendedWarranty,
      extendedWarrantyProvider: extendedWarrantyProvider ?? this.extendedWarrantyProvider,
      extendedWarrantyExpiry: extendedWarrantyExpiry ?? this.extendedWarrantyExpiry,
      returnWindowDays: returnWindowDays ?? this.returnWindowDays,
      returnDeadline: returnDeadline ?? this.returnDeadline,
      status: status ?? this.status,
      isCustomWarranty: isCustomWarranty ?? this.isCustomWarranty,
      warrantyType: warrantyType ?? this.warrantyType,
      invoiceDocumentId: invoiceDocumentId ?? this.invoiceDocumentId,
      warrantyCardDocumentId: warrantyCardDocumentId ?? this.warrantyCardDocumentId,
      manualDocumentId: manualDocumentId ?? this.manualDocumentId,
      imageUrls: imageUrls ?? this.imageUrls,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
