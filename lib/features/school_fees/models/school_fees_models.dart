import 'package:cloud_firestore/cloud_firestore.dart';

class Child {
  final String id;
  final String userId;
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final String? schoolName;
  final String? grade;
  final String? profilePhotoUrl;
  final String? notes;
  final DateTime createdAt;

  Child({
    required this.id,
    required this.userId,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    this.schoolName,
    this.grade,
    this.profilePhotoUrl,
    this.notes,
    required this.createdAt,
  });

  factory Child.fromMap(Map<String, dynamic> map, String id) {
    return Child(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      dateOfBirth: map['dateOfBirth'] is Timestamp
          ? (map['dateOfBirth'] as Timestamp).toDate()
          : DateTime.tryParse(map['dateOfBirth'].toString()) ?? DateTime.now(),
      gender: map['gender'] ?? 'Other',
      schoolName: map['schoolName'] as String?,
      grade: map['grade'] as String?,
      profilePhotoUrl: map['profilePhotoUrl'],
      notes: map['notes'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'gender': gender,
      'schoolName': schoolName,
      'grade': grade,
      'profilePhotoUrl': profilePhotoUrl,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Child copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? schoolName,
    String? grade,
    String? profilePhotoUrl,
    String? notes,
    DateTime? createdAt,
  }) {
    return Child(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      schoolName: schoolName ?? this.schoolName,
      grade: grade ?? this.grade,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class School {
  final String id;
  final String userId;
  final String name;
  final String address;
  final String contactPhone;
  final String contactEmail;
  final String website;
  final DateTime createdAt;

  School({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.contactPhone,
    required this.contactEmail,
    required this.website,
    required this.createdAt,
  });

  factory School.fromMap(Map<String, dynamic> map, String id) {
    return School(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      website: map['website'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'address': address,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'website': website,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class AcademicYear {
  final String id;
  final String childId;
  final String schoolId;
  final String yearLabel; // e.g., '2025-2026'
  final String grade; // e.g., 'Grade 5'
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  AcademicYear({
    required this.id,
    required this.childId,
    required this.schoolId,
    required this.yearLabel,
    required this.grade,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory AcademicYear.fromMap(Map<String, dynamic> map, String id) {
    return AcademicYear(
      id: id,
      childId: map['childId'] ?? '',
      schoolId: map['schoolId'] ?? '',
      yearLabel: map['yearLabel'] ?? '',
      grade: map['grade'] ?? '',
      startDate: map['startDate'] is Timestamp
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['startDate'].toString()) ?? DateTime.now(),
      endDate: map['endDate'] is Timestamp
          ? (map['endDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['endDate'].toString()) ?? DateTime.now(),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'schoolId': schoolId,
      'yearLabel': yearLabel,
      'grade': grade,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class FeeStructure {
  final String id;
  final String academicYearId;
  final String name; // e.g., 'Tuition & Transport'
  final double totalAmount;
  final String frequency; // 'Monthly', 'Quarterly', 'Semi-Annually', 'Annually'
  final int numberOfInstallments;
  final DateTime firstDueDate;
  final DateTime createdAt;

  FeeStructure({
    required this.id,
    required this.academicYearId,
    required this.name,
    required this.totalAmount,
    required this.frequency,
    required this.numberOfInstallments,
    required this.firstDueDate,
    required this.createdAt,
  });

  factory FeeStructure.fromMap(Map<String, dynamic> map, String id) {
    return FeeStructure(
      id: id,
      academicYearId: map['academicYearId'] ?? '',
      name: map['name'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      frequency: map['frequency'] ?? 'Quarterly',
      numberOfInstallments: map['numberOfInstallments'] ?? 4,
      firstDueDate: map['firstDueDate'] is Timestamp
          ? (map['firstDueDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['firstDueDate'].toString()) ?? DateTime.now(),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'academicYearId': academicYearId,
      'name': name,
      'totalAmount': totalAmount,
      'frequency': frequency,
      'numberOfInstallments': numberOfInstallments,
      'firstDueDate': Timestamp.fromDate(firstDueDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class FeeInstallment {
  final String id;
  final String feeStructureId;
  final String childId;
  final int installmentNumber;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String status; // 'pending', 'paid', 'overdue', 'partially_paid'
  final double paidAmount;
  final DateTime? paidDate;

  FeeInstallment({
    required this.id,
    required this.feeStructureId,
    required this.childId,
    required this.installmentNumber,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.status = 'pending',
    this.paidAmount = 0.0,
    this.paidDate,
  });

  factory FeeInstallment.fromMap(Map<String, dynamic> map, String id) {
    return FeeInstallment(
      id: id,
      feeStructureId: map['feeStructureId'] ?? '',
      childId: map['childId'] ?? '',
      installmentNumber: map['installmentNumber'] ?? 1,
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      dueDate: map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['dueDate'].toString()) ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      paidAmount: (map['paidAmount'] ?? 0.0).toDouble(),
      paidDate: map['paidDate'] is Timestamp
          ? (map['paidDate'] as Timestamp).toDate()
          : (map['paidDate'] != null ? DateTime.tryParse(map['paidDate'].toString()) : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'feeStructureId': feeStructureId,
      'childId': childId,
      'installmentNumber': installmentNumber,
      'title': title,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'paidAmount': paidAmount,
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
    };
  }
}

class FeePayment {
  final String id;
  final String installmentId;
  final double amountPaid;
  final DateTime paymentDate;
  final String paymentMethod; // 'UPI', 'Credit Card', 'Bank Transfer', 'Cash', 'Cheque'
  final String transactionRef;
  final String? receiptDocumentId;
  final String? notes;

  FeePayment({
    required this.id,
    required this.installmentId,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentMethod,
    required this.transactionRef,
    this.receiptDocumentId,
    this.notes,
  });

  factory FeePayment.fromMap(Map<String, dynamic> map, String id) {
    return FeePayment(
      id: id,
      installmentId: map['installmentId'] ?? '',
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
      'installmentId': installmentId,
      'amountPaid': amountPaid,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'paymentMethod': paymentMethod,
      'transactionRef': transactionRef,
      'receiptDocumentId': receiptDocumentId,
      'notes': notes,
    };
  }
}
