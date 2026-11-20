class Vehicle {
  final String id;
  final String name; // e.g. "Family Car - Creta"
  final String type; // "Car", "Bike", "EV", "Scooter"
  final String brand;
  final String model;
  final String registrationNumber;
  final DateTime purchaseDate;
  final int currentOdometer;
  final DateTime insuranceExpiry;
  final DateTime pucExpiry;
  final double? loanEmiAmount;
  final DateTime? nextServiceDate;
  final String? fastagId;
  final int serviceIntervalKm;
  final int serviceIntervalMonths;
  final int lastServiceOdometer;
  final DateTime? drivingLicenseExpiry;
  final int insuranceTenureMonths;
  final int pucTenureMonths;
  final DateTime? insuranceStartDate;
  final DateTime? pucStartDate;

  Vehicle({
    required this.id,
    required this.name,
    required this.type,
    required this.brand,
    required this.model,
    required this.registrationNumber,
    required this.purchaseDate,
    required this.currentOdometer,
    required this.insuranceExpiry,
    required this.pucExpiry,
    this.loanEmiAmount,
    this.nextServiceDate,
    this.fastagId,
    this.serviceIntervalKm = 10000,
    this.serviceIntervalMonths = 6,
    this.lastServiceOdometer = 0,
    this.drivingLicenseExpiry,
    this.insuranceTenureMonths = 12,
    this.pucTenureMonths = 12,
    this.insuranceStartDate,
    this.pucStartDate,
  });

  static const List<int> insuranceTenureOptions = [6, 12, 36, 60];
  static const List<int> pucTenureOptions = [6, 12];
  static const List<int> standardServiceIntervalOptions = [6, 10, 12];

  String get serviceIntervalLabel {
    if (serviceIntervalMonths == 12) return '1 Year';
    return '$serviceIntervalMonths Months';
  }

  String get serviceRepeatSchedule {
    switch (serviceIntervalMonths) {
      case 6:
        return 'semi_annual';
      case 12:
        return 'annual';
      default:
        return 'every_${serviceIntervalMonths}_months';
    }
  }

  String get insuranceTenureLabel {
    switch (insuranceTenureMonths) {
      case 6:
        return '6 Months';
      case 36:
        return '3 Years';
      case 60:
        return '5 Years';
      case 12:
      default:
        return '1 Year';
    }
  }

  String get pucTenureLabel {
    switch (pucTenureMonths) {
      case 6:
        return '6 Months';
      case 12:
      default:
        return '1 Year';
    }
  }

  String get insuranceRepeatSchedule {
    switch (insuranceTenureMonths) {
      case 6:
        return 'semi_annual';
      case 36:
        return 'triennial';
      case 60:
        return 'quinquennial';
      case 12:
      default:
        return 'annual';
    }
  }

  String get pucRepeatSchedule {
    switch (pucTenureMonths) {
      case 6:
        return 'semi_annual';
      case 12:
      default:
        return 'annual';
    }
  }

  static DateTime calculateExpiryDate(DateTime startDate, int tenureMonths) {
    var newYear = startDate.year;
    var newMonth = startDate.month + tenureMonths;
    while (newMonth > 12) {
      newYear++;
      newMonth -= 12;
    }
    while (newMonth < 1) {
      newYear--;
      newMonth += 12;
    }
    // Calculate max days in that target month
    final maxDays = DateTime(newYear, newMonth + 1, 0).day;
    final clampedDay = startDate.day.clamp(1, maxDays);
    return DateTime(
      newYear,
      newMonth,
      clampedDay,
      startDate.hour,
      startDate.minute,
      startDate.second,
    );
  }

  int get nextServiceOdometer => lastServiceOdometer + serviceIntervalKm;
  int get kmUntilNextService => nextServiceOdometer - currentOdometer;
  bool get isOdometerServiceDue => kmUntilNextService <= 500;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'brand': brand,
        'model': model,
        'registrationNumber': registrationNumber,
        'purchaseDate': purchaseDate.toIso8601String(),
        'currentOdometer': currentOdometer,
        'insuranceExpiry': insuranceExpiry.toIso8601String(),
        'pucExpiry': pucExpiry.toIso8601String(),
        'loanEmiAmount': loanEmiAmount,
        'nextServiceDate': nextServiceDate?.toIso8601String(),
        'fastagId': fastagId,
        'serviceIntervalKm': serviceIntervalKm,
        'serviceIntervalMonths': serviceIntervalMonths,
        'lastServiceOdometer': lastServiceOdometer,
        'drivingLicenseExpiry': drivingLicenseExpiry?.toIso8601String(),
        'insuranceTenureMonths': insuranceTenureMonths,
        'pucTenureMonths': pucTenureMonths,
        'insuranceStartDate': insuranceStartDate?.toIso8601String(),
        'pucStartDate': pucStartDate?.toIso8601String(),
      };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        brand: json['brand'] as String,
        model: json['model'] as String,
        registrationNumber: json['registrationNumber'] as String,
        purchaseDate: DateTime.parse(json['purchaseDate'] as String),
        currentOdometer: (json['currentOdometer'] as num).toInt(),
        insuranceExpiry: DateTime.parse(json['insuranceExpiry'] as String),
        pucExpiry: DateTime.parse(json['pucExpiry'] as String),
        loanEmiAmount: (json['loanEmiAmount'] as num?)?.toDouble(),
        nextServiceDate: json['nextServiceDate'] != null
            ? DateTime.parse(json['nextServiceDate'] as String)
            : null,
        fastagId: json['fastagId'] as String?,
        serviceIntervalKm: (json['serviceIntervalKm'] as num?)?.toInt() ?? 10000,
        serviceIntervalMonths: (json['serviceIntervalMonths'] as num?)?.toInt() ?? 6,
        lastServiceOdometer: (json['lastServiceOdometer'] as num?)?.toInt() ?? 0,
        drivingLicenseExpiry: json['drivingLicenseExpiry'] != null
            ? DateTime.parse(json['drivingLicenseExpiry'] as String)
            : null,
        insuranceTenureMonths: (json['insuranceTenureMonths'] as num?)?.toInt() ?? 12,
        pucTenureMonths: (json['pucTenureMonths'] as num?)?.toInt() ?? 12,
        insuranceStartDate: json['insuranceStartDate'] != null
            ? DateTime.parse(json['insuranceStartDate'] as String)
            : null,
        pucStartDate: json['pucStartDate'] != null
            ? DateTime.parse(json['pucStartDate'] as String)
            : null,
      );

  Vehicle copyWith({
    String? id,
    String? name,
    String? type,
    String? brand,
    String? model,
    String? registrationNumber,
    DateTime? purchaseDate,
    int? currentOdometer,
    DateTime? insuranceExpiry,
    DateTime? pucExpiry,
    double? loanEmiAmount,
    DateTime? nextServiceDate,
    String? fastagId,
    int? serviceIntervalKm,
    int? serviceIntervalMonths,
    int? lastServiceOdometer,
    DateTime? drivingLicenseExpiry,
    int? insuranceTenureMonths,
    int? pucTenureMonths,
    DateTime? insuranceStartDate,
    DateTime? pucStartDate,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      pucExpiry: pucExpiry ?? this.pucExpiry,
      loanEmiAmount: loanEmiAmount ?? this.loanEmiAmount,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
      fastagId: fastagId ?? this.fastagId,
      serviceIntervalKm: serviceIntervalKm ?? this.serviceIntervalKm,
      serviceIntervalMonths: serviceIntervalMonths ?? this.serviceIntervalMonths,
      lastServiceOdometer: lastServiceOdometer ?? this.lastServiceOdometer,
      drivingLicenseExpiry: drivingLicenseExpiry ?? this.drivingLicenseExpiry,
      insuranceTenureMonths: insuranceTenureMonths ?? this.insuranceTenureMonths,
      pucTenureMonths: pucTenureMonths ?? this.pucTenureMonths,
      insuranceStartDate: insuranceStartDate ?? this.insuranceStartDate,
      pucStartDate: pucStartDate ?? this.pucStartDate,
    );
  }
}

class ServiceRecord {
  final String id;
  final String vehicleId;
  final DateTime serviceDate;
  final int odometerReading;
  final String serviceType; // e.g., "Periodic Service", "Tyre Replacement", "Battery Change", "Challan"
  final String workPerformed;
  final double totalCost;
  final String serviceCenter;

  ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.serviceDate,
    required this.odometerReading,
    required this.serviceType,
    required this.workPerformed,
    required this.totalCost,
    required this.serviceCenter,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'serviceDate': serviceDate.toIso8601String(),
        'odometerReading': odometerReading,
        'serviceType': serviceType,
        'workPerformed': workPerformed,
        'totalCost': totalCost,
        'serviceCenter': serviceCenter,
      };

  factory ServiceRecord.fromJson(Map<String, dynamic> json) => ServiceRecord(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String,
        serviceDate: DateTime.parse(json['serviceDate'] as String),
        odometerReading: (json['odometerReading'] as num).toInt(),
        serviceType: json['serviceType'] as String,
        workPerformed: json['workPerformed'] as String,
        totalCost: (json['totalCost'] as num).toDouble(),
        serviceCenter: json['serviceCenter'] as String,
      );

  ServiceRecord copyWith({
    String? id,
    String? vehicleId,
    DateTime? serviceDate,
    int? odometerReading,
    String? serviceType,
    String? workPerformed,
    double? totalCost,
    String? serviceCenter,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceDate: serviceDate ?? this.serviceDate,
      odometerReading: odometerReading ?? this.odometerReading,
      serviceType: serviceType ?? this.serviceType,
      workPerformed: workPerformed ?? this.workPerformed,
      totalCost: totalCost ?? this.totalCost,
      serviceCenter: serviceCenter ?? this.serviceCenter,
    );
  }
}

class FuelEntry {
  final String id;
  final String vehicleId;
  final DateTime date;
  final int odometer;
  final double fuelLiters;
  final double totalCost;
  final bool isFullTank;
  final double? kmPerLiter;

  FuelEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.fuelLiters,
    required this.totalCost,
    this.isFullTank = true,
    this.kmPerLiter,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'date': date.toIso8601String(),
        'odometer': odometer,
        'fuelLiters': fuelLiters,
        'totalCost': totalCost,
        'isFullTank': isFullTank,
        'kmPerLiter': kmPerLiter,
      };

  factory FuelEntry.fromJson(Map<String, dynamic> json) => FuelEntry(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String,
        date: DateTime.parse(json['date'] as String),
        odometer: (json['odometer'] as num).toInt(),
        fuelLiters: (json['fuelLiters'] as num).toDouble(),
        totalCost: (json['totalCost'] as num).toDouble(),
        isFullTank: json['isFullTank'] as bool? ?? true,
        kmPerLiter: (json['kmPerLiter'] as num?)?.toDouble(),
      );
}
