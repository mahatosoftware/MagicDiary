enum ForecastTimeHorizon { thisWeek, thisMonth, next90Days, custom }

enum ForecastItemType {
  bill,
  schoolFee,
  loanEmi,
  vehicleInsurance,
  vehiclePuc,
  vehicleService,
  propertyTax,
  houseRent,
  domesticSalary,
  recurringService,
  subscription,
  customObligation,
}

class ForecastObligation {
  final String id;
  final String sourceModule; // 'Bills', 'SchoolFees', 'Vehicle', 'Property', 'DomesticHelp', 'Household', 'Finance'
  final String title;
  final DateTime dueDate;
  final double amount;
  final double paidAmount;
  final ForecastItemType type;
  final bool isEstimate;
  final bool isOverdue;
  final String? assignedTo;
  final String? sourceRecordId;
  final String status; // 'unpaid', 'partially_paid', 'paid'

  ForecastObligation({
    required this.id,
    required this.sourceModule,
    required this.title,
    required this.dueDate,
    required this.amount,
    this.paidAmount = 0.0,
    required this.type,
    this.isEstimate = false,
    this.isOverdue = false,
    this.assignedTo,
    this.sourceRecordId,
    this.status = 'unpaid',
  });

  double get remainingCommitment => (amount - paidAmount).clamp(0.0, double.infinity);
  bool get isSettled => remainingCommitment <= 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceModule': sourceModule,
        'title': title,
        'dueDate': dueDate.toIso8601String(),
        'amount': amount,
        'paidAmount': paidAmount,
        'type': type.name,
        'isEstimate': isEstimate,
        'isOverdue': isOverdue,
        'assignedTo': assignedTo,
        'sourceRecordId': sourceRecordId,
        'status': status,
      };

  factory ForecastObligation.fromJson(Map<String, dynamic> json) => ForecastObligation(
        id: json['id'] as String,
        sourceModule: json['sourceModule'] as String,
        title: json['title'] as String,
        dueDate: DateTime.parse(json['dueDate'] as String),
        amount: (json['amount'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
        type: ForecastItemType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ForecastItemType.customObligation,
        ),
        isEstimate: json['isEstimate'] as bool? ?? false,
        isOverdue: json['isOverdue'] as bool? ?? false,
        assignedTo: json['assignedTo'] as String?,
        sourceRecordId: json['sourceRecordId'] as String?,
        status: json['status'] as String? ?? 'unpaid',
      );
}

class ForecastIncome {
  final String id;
  final String title; // e.g. "Primary Salary", "Rental Inflow"
  final DateTime expectedDate;
  final double amount;
  final bool isConfirmed;
  final String? notes;

  ForecastIncome({
    required this.id,
    required this.title,
    required this.expectedDate,
    required this.amount,
    this.isConfirmed = true,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'expectedDate': expectedDate.toIso8601String(),
        'amount': amount,
        'isConfirmed': isConfirmed,
        'notes': notes,
      };

  factory ForecastIncome.fromJson(Map<String, dynamic> json) => ForecastIncome(
        id: json['id'] as String,
        title: json['title'] as String,
        expectedDate: DateTime.parse(json['expectedDate'] as String),
        amount: (json['amount'] as num).toDouble(),
        isConfirmed: json['isConfirmed'] as bool? ?? true,
        notes: json['notes'] as String?,
      );
}

class CashShortfall {
  final DateTime date;
  final double projectedBalance;
  final double bufferThreshold;
  final double deficitAmount;
  final List<ForecastObligation> triggers;
  final String explanation;

  CashShortfall({
    required this.date,
    required this.projectedBalance,
    required this.bufferThreshold,
    required this.deficitAmount,
    required this.triggers,
    required this.explanation,
  });
}

class ForecastDayPoint {
  final DateTime date;
  final double startingBalance;
  final double inflows;
  final double outflows;
  final double endingBalance;
  final List<String> eventSummaries;

  ForecastDayPoint({
    required this.date,
    required this.startingBalance,
    required this.inflows,
    required this.outflows,
    required this.endingBalance,
    required this.eventSummaries,
  });
}

class ForecastSummary {
  final double availableCashNow;
  final double totalExpectedIncome;
  final double totalExpectedCommitments;
  final double projectedNetFlow;
  final double projectedClosingBalance;
  final List<CashShortfall> shortfalls;
  final List<ForecastDayPoint> timeline;
  final List<ForecastObligation> obligations;
  final List<ForecastIncome> incomes;
  final DateTime lastCalculatedAt;

  ForecastSummary({
    required this.availableCashNow,
    required this.totalExpectedIncome,
    required this.totalExpectedCommitments,
    required this.projectedNetFlow,
    required this.projectedClosingBalance,
    required this.shortfalls,
    required this.timeline,
    required this.obligations,
    required this.incomes,
    required this.lastCalculatedAt,
  });

  bool get hasShortfall => shortfalls.isNotEmpty;
}

class ForecastScenario {
  final String id;
  final String name;
  final int delayIncomeDays;
  final double additionalExpenseAmount;
  final String? additionalExpenseTitle;
  final DateTime? additionalExpenseDate;

  ForecastScenario({
    required this.id,
    required this.name,
    this.delayIncomeDays = 0,
    this.additionalExpenseAmount = 0.0,
    this.additionalExpenseTitle,
    this.additionalExpenseDate,
  });
}
