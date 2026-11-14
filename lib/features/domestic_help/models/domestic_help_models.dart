import 'package:cloud_firestore/cloud_firestore.dart';

enum SalaryType { monthlyFixed, dailyWage, hourly, perVisit }

enum AttendancePolicy { deductUnpaidAbsence, fixedNoDeduction, customRule }

enum AttendanceStatus { present, halfDay, absent, approvedLeave, unpaidLeave, notScheduled }

class DomesticWorker {
  final String id;
  final String householdId;
  final String name;
  final String? preferredName;
  final String role; // 'Maid', 'Cook', 'Driver', 'Gardener', 'Babysitter', 'Caretaker', etc.
  final String phone;
  final String? emergencyContact;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<int> workingDays; // 1 = Mon ... 7 = Sun
  final List<int> weeklyOff; // e.g. [7] for Sunday
  final SalaryType salaryType;
  final double baseSalary;
  final int paymentDueDay; // e.g. 5 for 5th of each month
  final AttendancePolicy attendancePolicy;
  final double advanceBalance;
  final String? notes;

  DomesticWorker({
    required this.id,
    required this.householdId,
    required this.name,
    this.preferredName,
    required this.role,
    required this.phone,
    this.emergencyContact,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.workingDays = const [1, 2, 3, 4, 5, 6],
    this.weeklyOff = const [7],
    this.salaryType = SalaryType.monthlyFixed,
    required this.baseSalary,
    this.paymentDueDay = 5,
    this.attendancePolicy = AttendancePolicy.deductUnpaidAbsence,
    this.advanceBalance = 0.0,
    this.notes,
  });

  DomesticWorker copyWith({
    String? id,
    String? householdId,
    String? name,
    String? preferredName,
    String? role,
    String? phone,
    String? emergencyContact,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    List<int>? workingDays,
    List<int>? weeklyOff,
    SalaryType? salaryType,
    double? baseSalary,
    int? paymentDueDay,
    AttendancePolicy? attendancePolicy,
    double? advanceBalance,
    String? notes,
  }) {
    return DomesticWorker(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      preferredName: preferredName ?? this.preferredName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      workingDays: workingDays ?? this.workingDays,
      weeklyOff: weeklyOff ?? this.weeklyOff,
      salaryType: salaryType ?? this.salaryType,
      baseSalary: baseSalary ?? this.baseSalary,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      attendancePolicy: attendancePolicy ?? this.attendancePolicy,
      advanceBalance: advanceBalance ?? this.advanceBalance,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'name': name,
        'preferredName': preferredName,
        'role': role,
        'phone': phone,
        'emergencyContact': emergencyContact,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'isActive': isActive,
        'workingDays': workingDays,
        'weeklyOff': weeklyOff,
        'salaryType': salaryType.name,
        'baseSalary': baseSalary,
        'paymentDueDay': paymentDueDay,
        'attendancePolicy': attendancePolicy.name,
        'advanceBalance': advanceBalance,
        'notes': notes,
      };

  factory DomesticWorker.fromJson(Map<String, dynamic> json) => DomesticWorker(
        id: json['id'] as String,
        householdId: json['householdId'] as String? ?? '',
        name: json['name'] as String,
        preferredName: json['preferredName'] as String?,
        role: json['role'] as String? ?? 'Maid',
        phone: json['phone'] as String? ?? '',
        emergencyContact: json['emergencyContact'] as String?,
        startDate: json['startDate'] is Timestamp
            ? (json['startDate'] as Timestamp).toDate()
            : DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
        endDate: json['endDate'] is Timestamp
            ? (json['endDate'] as Timestamp).toDate()
            : (json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null),
        isActive: json['isActive'] as bool? ?? true,
        workingDays: (json['workingDays'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [1, 2, 3, 4, 5, 6],
        weeklyOff: (json['weeklyOff'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [7],
        salaryType: SalaryType.values.firstWhere(
          (e) => e.name == json['salaryType'],
          orElse: () => SalaryType.monthlyFixed,
        ),
        baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0.0,
        paymentDueDay: (json['paymentDueDay'] as num?)?.toInt() ?? 5,
        attendancePolicy: AttendancePolicy.values.firstWhere(
          (e) => e.name == json['attendancePolicy'],
          orElse: () => AttendancePolicy.deductUnpaidAbsence,
        ),
        advanceBalance: (json['advanceBalance'] as num?)?.toDouble() ?? 0.0,
        notes: json['notes'] as String?,
      );
}

class WorkerAttendance {
  final String id; // Deterministic: "${workerId}_${dateStr}"
  final String workerId;
  final String householdId;
  final String date; // yyyy-MM-dd
  final AttendanceStatus status;
  final String? arrivalTime; // e.g. "08:30 AM"
  final String? recordedByUid;
  final String? recordedByName;
  final String? notes;
  final DateTime timestamp;

  WorkerAttendance({
    required this.id,
    required this.workerId,
    required this.householdId,
    required this.date,
    required this.status,
    this.arrivalTime,
    this.recordedByUid,
    this.recordedByName,
    this.notes,
    required this.timestamp,
  });

  static String generateId(String workerId, DateTime date) {
    final dStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${workerId}_$dStr';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workerId': workerId,
        'householdId': householdId,
        'date': date,
        'status': status.name,
        'arrivalTime': arrivalTime,
        'recordedByUid': recordedByUid,
        'recordedByName': recordedByName,
        'notes': notes,
        'timestamp': Timestamp.fromDate(timestamp),
      };

  factory WorkerAttendance.fromJson(Map<String, dynamic> json) => WorkerAttendance(
        id: json['id'] as String,
        workerId: json['workerId'] as String,
        householdId: json['householdId'] as String? ?? '',
        date: json['date'] as String,
        status: AttendanceStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => AttendanceStatus.present,
        ),
        arrivalTime: json['arrivalTime'] as String?,
        recordedByUid: json['recordedByUid'] as String?,
        recordedByName: json['recordedByName'] as String?,
        notes: json['notes'] as String?,
        timestamp: json['timestamp'] is Timestamp
            ? (json['timestamp'] as Timestamp).toDate()
            : DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );
}

class SalaryAdvance {
  final String id;
  final String workerId;
  final String householdId;
  final double amount;
  final DateTime date;
  final double monthlyRecoveryAmount;
  final double recoveredAmount;
  final bool isFullyRecovered;
  final String? notes;

  SalaryAdvance({
    required this.id,
    required this.workerId,
    required this.householdId,
    required this.amount,
    required this.date,
    required this.monthlyRecoveryAmount,
    this.recoveredAmount = 0.0,
    this.isFullyRecovered = false,
    this.notes,
  });

  double get remainingBalance => (amount - recoveredAmount).clamp(0.0, double.infinity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'workerId': workerId,
        'householdId': householdId,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'monthlyRecoveryAmount': monthlyRecoveryAmount,
        'recoveredAmount': recoveredAmount,
        'isFullyRecovered': isFullyRecovered,
        'notes': notes,
      };

  factory SalaryAdvance.fromJson(Map<String, dynamic> json) => SalaryAdvance(
        id: json['id'] as String,
        workerId: json['workerId'] as String,
        householdId: json['householdId'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        date: json['date'] is Timestamp
            ? (json['date'] as Timestamp).toDate()
            : DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        monthlyRecoveryAmount: (json['monthlyRecoveryAmount'] as num?)?.toDouble() ?? 0.0,
        recoveredAmount: (json['recoveredAmount'] as num?)?.toDouble() ?? 0.0,
        isFullyRecovered: json['isFullyRecovered'] as bool? ?? false,
        notes: json['notes'] as String?,
      );
}

class SalaryAdjustment {
  final String id;
  final String workerId;
  final String householdId;
  final String type; // 'bonus', 'deduction', 'extra_work'
  final double amount;
  final DateTime date;
  final String reason;

  SalaryAdjustment({
    required this.id,
    required this.workerId,
    required this.householdId,
    required this.type,
    required this.amount,
    required this.date,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'workerId': workerId,
        'householdId': householdId,
        'type': type,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'reason': reason,
      };

  factory SalaryAdjustment.fromJson(Map<String, dynamic> json) => SalaryAdjustment(
        id: json['id'] as String,
        workerId: json['workerId'] as String,
        householdId: json['householdId'] as String? ?? '',
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: json['date'] is Timestamp
            ? (json['date'] as Timestamp).toDate()
            : DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        reason: json['reason'] as String? ?? '',
      );
}

class SalaryStatement {
  final String id;
  final String workerId;
  final String workerName;
  final String householdId;
  final int month; // 1 - 12
  final int year;
  final double baseSalary;
  final double bonuses;
  final double extraWorkPay;
  final double deductions;
  final double advanceRecovery;
  final double netPayable;
  final double paidAmount;
  final String status; // 'draft', 'approved', 'partially_paid', 'paid'
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? paymentReference;
  final String? financialTransactionId;

  SalaryStatement({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.householdId,
    required this.month,
    required this.year,
    required this.baseSalary,
    this.bonuses = 0.0,
    this.extraWorkPay = 0.0,
    this.deductions = 0.0,
    this.advanceRecovery = 0.0,
    required this.netPayable,
    this.paidAmount = 0.0,
    this.status = 'draft',
    this.paymentDate,
    this.paymentMethod,
    this.paymentReference,
    this.financialTransactionId,
  });

  double get outstandingBalance => (netPayable - paidAmount).clamp(0.0, double.infinity);
  bool get isSettled => outstandingBalance <= 0.0;

  SalaryStatement copyWith({
    String? id,
    String? workerId,
    String? workerName,
    String? householdId,
    int? month,
    int? year,
    double? baseSalary,
    double? bonuses,
    double? extraWorkPay,
    double? deductions,
    double? advanceRecovery,
    double? netPayable,
    double? paidAmount,
    String? status,
    DateTime? paymentDate,
    String? paymentMethod,
    String? paymentReference,
    String? financialTransactionId,
  }) {
    return SalaryStatement(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      householdId: householdId ?? this.householdId,
      month: month ?? this.month,
      year: year ?? this.year,
      baseSalary: baseSalary ?? this.baseSalary,
      bonuses: bonuses ?? this.bonuses,
      extraWorkPay: extraWorkPay ?? this.extraWorkPay,
      deductions: deductions ?? this.deductions,
      advanceRecovery: advanceRecovery ?? this.advanceRecovery,
      netPayable: netPayable ?? this.netPayable,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      financialTransactionId: financialTransactionId ?? this.financialTransactionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workerId': workerId,
        'workerName': workerName,
        'householdId': householdId,
        'month': month,
        'year': year,
        'baseSalary': baseSalary,
        'bonuses': bonuses,
        'extraWorkPay': extraWorkPay,
        'deductions': deductions,
        'advanceRecovery': advanceRecovery,
        'netPayable': netPayable,
        'paidAmount': paidAmount,
        'status': status,
        'paymentDate': paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'financialTransactionId': financialTransactionId,
      };

  factory SalaryStatement.fromJson(Map<String, dynamic> json) => SalaryStatement(
        id: json['id'] as String,
        workerId: json['workerId'] as String,
        workerName: json['workerName'] as String? ?? 'Worker',
        householdId: json['householdId'] as String? ?? '',
        month: (json['month'] as num).toInt(),
        year: (json['year'] as num).toInt(),
        baseSalary: (json['baseSalary'] as num).toDouble(),
        bonuses: (json['bonuses'] as num?)?.toDouble() ?? 0.0,
        extraWorkPay: (json['extraWorkPay'] as num?)?.toDouble() ?? 0.0,
        deductions: (json['deductions'] as num?)?.toDouble() ?? 0.0,
        advanceRecovery: (json['advanceRecovery'] as num?)?.toDouble() ?? 0.0,
        netPayable: (json['netPayable'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'draft',
        paymentDate: json['paymentDate'] is Timestamp
            ? (json['paymentDate'] as Timestamp).toDate()
            : (json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate'].toString()) : null),
        paymentMethod: json['paymentMethod'] as String?,
        paymentReference: json['paymentReference'] as String?,
        financialTransactionId: json['financialTransactionId'] as String?,
      );
}

class RecurringService {
  final String id;
  final String householdId;
  final String name; // e.g. "Amul Buffalo Milk", "Times of India", "Water Cans"
  final String serviceType; // 'Milk', 'Newspaper', 'Laundry', 'WaterCan', 'Cleaning', 'Internet', 'Other'
  final String providerName;
  final String? providerContact;
  final String billingModel; // 'perUnit', 'perDelivery', 'monthlyFixed'
  final double unitRate; // e.g. ₹68 per litre
  final String unitName; // 'Litres', 'Cans', 'Papers', 'Items'
  final List<int> deliveryDays; // 1 = Mon ... 7 = Sun
  final double defaultDailyQuantity;
  final double unpaidBalance;
  final bool isActive;
  final String? notes;

  RecurringService({
    required this.id,
    required this.householdId,
    required this.name,
    required this.serviceType,
    required this.providerName,
    this.providerContact,
    this.billingModel = 'perUnit',
    required this.unitRate,
    this.unitName = 'Litres',
    this.deliveryDays = const [1, 2, 3, 4, 5, 6, 7],
    this.defaultDailyQuantity = 1.0,
    this.unpaidBalance = 0.0,
    this.isActive = true,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'name': name,
        'serviceType': serviceType,
        'providerName': providerName,
        'providerContact': providerContact,
        'billingModel': billingModel,
        'unitRate': unitRate,
        'unitName': unitName,
        'deliveryDays': deliveryDays,
        'defaultDailyQuantity': defaultDailyQuantity,
        'unpaidBalance': unpaidBalance,
        'isActive': isActive,
        'notes': notes,
      };

  factory RecurringService.fromJson(Map<String, dynamic> json) => RecurringService(
        id: json['id'] as String,
        householdId: json['householdId'] as String? ?? '',
        name: json['name'] as String,
        serviceType: json['serviceType'] as String? ?? 'Milk',
        providerName: json['providerName'] as String? ?? '',
        providerContact: json['providerContact'] as String?,
        billingModel: json['billingModel'] as String? ?? 'perUnit',
        unitRate: (json['unitRate'] as num?)?.toDouble() ?? 0.0,
        unitName: json['unitName'] as String? ?? 'Litres',
        deliveryDays: (json['deliveryDays'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [1, 2, 3, 4, 5, 6, 7],
        defaultDailyQuantity: (json['defaultDailyQuantity'] as num?)?.toDouble() ?? 1.0,
        unpaidBalance: (json['unpaidBalance'] as num?)?.toDouble() ?? 0.0,
        isActive: json['isActive'] as bool? ?? true,
        notes: json['notes'] as String?,
      );
}

class ServiceEntry {
  final String id; // Deterministic: "${serviceId}_${dateStr}"
  final String serviceId;
  final String householdId;
  final String date; // yyyy-MM-dd
  final double quantity;
  final double rate;
  final bool isDelivered;
  final String? notes;

  ServiceEntry({
    required this.id,
    required this.serviceId,
    required this.householdId,
    required this.date,
    required this.quantity,
    required this.rate,
    this.isDelivered = true,
    this.notes,
  });

  double get cost => isDelivered ? quantity * rate : 0.0;

  static String generateId(String serviceId, DateTime date) {
    final dStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${serviceId}_$dStr';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceId': serviceId,
        'householdId': householdId,
        'date': date,
        'quantity': quantity,
        'rate': rate,
        'isDelivered': isDelivered,
        'notes': notes,
      };

  factory ServiceEntry.fromJson(Map<String, dynamic> json) => ServiceEntry(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String,
        householdId: json['householdId'] as String? ?? '',
        date: json['date'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        isDelivered: json['isDelivered'] as bool? ?? true,
        notes: json['notes'] as String?,
      );
}

class ServiceBill {
  final String id;
  final String serviceId;
  final String serviceName;
  final String householdId;
  final int month;
  final int year;
  final double totalQuantity;
  final double totalAmount;
  final double paidAmount;
  final String status; // 'pending', 'partially_paid', 'paid'
  final DateTime? paidDate;
  final String? financialTransactionId;

  ServiceBill({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.householdId,
    required this.month,
    required this.year,
    required this.totalQuantity,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.status = 'pending',
    this.paidDate,
    this.financialTransactionId,
  });

  double get outstandingBalance => (totalAmount - paidAmount).clamp(0.0, double.infinity);
  bool get isSettled => outstandingBalance <= 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'householdId': householdId,
        'month': month,
        'year': year,
        'totalQuantity': totalQuantity,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'status': status,
        'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
        'financialTransactionId': financialTransactionId,
      };

  factory ServiceBill.fromJson(Map<String, dynamic> json) => ServiceBill(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String,
        serviceName: json['serviceName'] as String? ?? 'Service',
        householdId: json['householdId'] as String? ?? '',
        month: (json['month'] as num).toInt(),
        year: (json['year'] as num).toInt(),
        totalQuantity: (json['totalQuantity'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'pending',
        paidDate: json['paidDate'] is Timestamp
            ? (json['paidDate'] as Timestamp).toDate()
            : (json['paidDate'] != null ? DateTime.tryParse(json['paidDate'].toString()) : null),
        financialTransactionId: json['financialTransactionId'] as String?,
      );
}
