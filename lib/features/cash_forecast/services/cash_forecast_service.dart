import '../../bills/models/bills_models.dart';
import '../../school_fees/models/school_fees_models.dart';
import '../../vehicle/models/vehicle_models.dart';
import '../../property/models/property_models.dart';
import '../../household/models/household_models.dart';
import '../../domestic_help/models/domestic_help_models.dart';
import '../models/cash_forecast_models.dart';

class CashForecastService {
  /// Consolidates all upcoming obligations across modules and calculates chronological cash flow projection
  static ForecastSummary generateForecast({
    required DateTime now,
    required double startingCashBalance,
    double safetyBuffer = 0.0,
    int forecastDays = 30, // 7 for week, 30 for month, 90 for quarter
    List<Bill> bills = const [],
    List<FeeInstallment> feeInstallments = const [],
    List<Vehicle> vehicles = const [],
    List<Property> properties = const [],
    List<HouseholdExpense> householdExpenses = const [],
    List<DomesticWorker> domesticWorkers = const [],
    List<RecurringService> recurringServices = const [],
    List<ForecastIncome> configuredIncomes = const [],
    ForecastScenario? scenario,
  }) {
    final rangeEnd = now.add(Duration(days: forecastDays));
    final obligations = <ForecastObligation>[];

    // 1. BILLS
    for (final b in bills) {
      if (b.status.toLowerCase() != 'paid') {
        final isOverdue = b.dueDate.isBefore(DateTime(now.year, now.month, now.day));
        if (isOverdue || b.dueDate.isBefore(rangeEnd)) {
          obligations.add(ForecastObligation(
            id: 'fc_bill_${b.id}',
            sourceModule: 'Bills',
            title: b.displayTitle(),
            dueDate: isOverdue ? now : b.dueDate,
            amount: b.amount,
            paidAmount: 0.0,
            type: ForecastItemType.bill,
            isOverdue: isOverdue,
            sourceRecordId: b.id,
            status: b.status,
          ));
        }
      }
    }

    // 2. SCHOOL FEES
    for (final fee in feeInstallments) {
      if (!fee.isSettled) {
        final isOverdue = fee.dueDate.isBefore(DateTime(now.year, now.month, now.day));
        if (isOverdue || fee.dueDate.isBefore(rangeEnd)) {
          obligations.add(ForecastObligation(
            id: 'fc_fee_${fee.id}',
            sourceModule: 'SchoolFees',
            title: fee.title,
            dueDate: isOverdue ? now : fee.dueDate,
            amount: fee.netPayable,
            paidAmount: fee.paidAmount,
            type: ForecastItemType.schoolFee,
            isOverdue: isOverdue,
            sourceRecordId: fee.id,
            status: fee.status,
          ));
        }
      }
    }

    // 3. VEHICLE OBLIGATIONS (EMIs, Insurance, PUC)
    for (final v in vehicles) {
      if (v.loanEmiAmount != null && v.loanEmiAmount! > 0) {
        // Vehicle EMI due monthly (typically 10th of month)
        final emiDate = DateTime(now.year, now.month, 10);
        if (emiDate.isAfter(now) && emiDate.isBefore(rangeEnd)) {
          obligations.add(ForecastObligation(
            id: 'fc_veh_emi_${v.id}_${now.month}',
            sourceModule: 'Vehicle',
            title: '${v.name} Loan EMI',
            dueDate: emiDate,
            amount: v.loanEmiAmount!,
            type: ForecastItemType.loanEmi,
            sourceRecordId: v.id,
          ));
        }
      }

      if (v.insuranceExpiry.isAfter(now) && v.insuranceExpiry.isBefore(rangeEnd)) {
        obligations.add(ForecastObligation(
          id: 'fc_veh_ins_${v.id}',
          sourceModule: 'Vehicle',
          title: '${v.name} Insurance Renewal',
          dueDate: v.insuranceExpiry,
          amount: 12000.0, // Estimated standard premium
          type: ForecastItemType.vehicleInsurance,
          isEstimate: true,
          sourceRecordId: v.id,
        ));
      }
    }

    // 4. PROPERTY DUES & TAXES
    for (final prop in properties) {
      if (prop.propertyTaxAmount > 0) {
        if (prop.taxDueDate.isAfter(now) && prop.taxDueDate.isBefore(rangeEnd)) {
          obligations.add(ForecastObligation(
            id: 'fc_prop_tax_${prop.id}',
            sourceModule: 'Property',
            title: 'Property Tax: ${prop.title}',
            dueDate: prop.taxDueDate,
            amount: prop.propertyTaxAmount,
            type: ForecastItemType.propertyTax,
            sourceRecordId: prop.id,
          ));
        }
      }
    }

    // 5. HOUSEHOLD EXPENSES
    for (final exp in householdExpenses) {
      if (exp.status.toLowerCase() != 'paid') {
        final isOverdue = exp.dueDate.isBefore(DateTime(now.year, now.month, now.day));
        if (isOverdue || exp.dueDate.isBefore(rangeEnd)) {
          obligations.add(ForecastObligation(
            id: 'fc_hh_${exp.id}',
            sourceModule: 'Household',
            title: '${exp.category} (${exp.providerName})',
            dueDate: isOverdue ? now : exp.dueDate,
            amount: exp.amount,
            type: ForecastItemType.bill,
            isOverdue: isOverdue,
            sourceRecordId: exp.id,
            status: exp.status,
          ));
        }
      }
    }

    // 6. DOMESTIC HELP WORKER SALARIES
    for (final worker in domesticWorkers) {
      if (worker.isActive && worker.baseSalary > 0) {
        // Normal payment date in current/next month
        var salaryDate = DateTime(now.year, now.month, worker.paymentDueDay);
        if (salaryDate.isBefore(now)) {
          salaryDate = DateTime(now.year, now.month + 1, worker.paymentDueDay);
        }
        if (salaryDate.isBefore(rangeEnd)) {
          obligations.add(ForecastObligation(
            id: 'fc_salary_${worker.id}_${salaryDate.month}',
            sourceModule: 'DomesticHelp',
            title: '${worker.role} Salary (${worker.name})',
            dueDate: salaryDate,
            amount: worker.baseSalary,
            type: ForecastItemType.domesticSalary,
            sourceRecordId: worker.id,
          ));
        }
      }
    }

    // 7. RECURRING HOUSEHOLD SERVICES (Milk, Newspaper, Water)
    for (final serv in recurringServices) {
      if (serv.isActive && serv.unitRate > 0) {
        final estMonthly = serv.defaultDailyQuantity * serv.unitRate * 30;
        final billingDate = DateTime(now.year, now.month, 28);
        if (billingDate.isAfter(now) && billingDate.isBefore(rangeEnd)) {
          obligations.add(ForecastObligation(
            id: 'fc_service_${serv.id}_${now.month}',
            sourceModule: 'DomesticHelp',
            title: '${serv.name} Delivery',
            dueDate: billingDate,
            amount: estMonthly,
            type: ForecastItemType.recurringService,
            isEstimate: true,
            sourceRecordId: serv.id,
          ));
        }
      }
    }

    // 8. APPLY SCENARIO ADJUSTMENTS (if simulated)
    if (scenario != null && scenario.additionalExpenseAmount > 0) {
      obligations.add(ForecastObligation(
        id: 'fc_scenario_exp',
        sourceModule: 'Finance',
        title: scenario.additionalExpenseTitle ?? 'Simulated Expense',
        dueDate: scenario.additionalExpenseDate ?? now.add(const Duration(days: 5)),
        amount: scenario.additionalExpenseAmount,
        type: ForecastItemType.customObligation,
        isEstimate: true,
      ));
    }

    // Sort obligations chronologically
    obligations.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // 9. INFLOWS & SCENARIO INCOME DELAY
    final adjustedIncomes = <ForecastIncome>[];
    for (final inc in configuredIncomes) {
      var incDate = inc.expectedDate;
      if (scenario != null && scenario.delayIncomeDays > 0) {
        incDate = incDate.add(Duration(days: scenario.delayIncomeDays));
      }
      if (incDate.isBefore(rangeEnd)) {
        adjustedIncomes.add(ForecastIncome(
          id: inc.id,
          title: inc.title,
          expectedDate: incDate,
          amount: inc.amount,
          isConfirmed: inc.isConfirmed,
          notes: inc.notes,
        ));
      }
    }

    // 10. CHRONOLOGICAL CASH FLOW SIMULATION
    double runningBalance = startingCashBalance;
    final timeline = <ForecastDayPoint>[];
    final shortfalls = <CashShortfall>[];

    // Group events day-by-day
    for (int day = 0; day <= forecastDays; day++) {
      final currentDay = DateTime(now.year, now.month, now.day).add(Duration(days: day));

      final dayInflows = adjustedIncomes.where((i) =>
          i.expectedDate.year == currentDay.year &&
          i.expectedDate.month == currentDay.month &&
          i.expectedDate.day == currentDay.day).toList();

      final dayOutflows = obligations.where((o) =>
          o.dueDate.year == currentDay.year &&
          o.dueDate.month == currentDay.month &&
          o.dueDate.day == currentDay.day).toList();

      final dayInTotal = dayInflows.fold<double>(0.0, (sum, i) => sum + i.amount);
      final dayOutTotal = dayOutflows.fold<double>(0.0, (sum, o) => sum + o.remainingCommitment);

      final startingDayBalance = runningBalance;
      runningBalance = runningBalance + dayInTotal - dayOutTotal;

      final events = <String>[];
      for (final i in dayInflows) {
        events.add('+₹${i.amount.toStringAsFixed(0)}: ${i.title}');
      }
      for (final o in dayOutflows) {
        events.add('-₹${o.remainingCommitment.toStringAsFixed(0)}: ${o.title}');
      }

      timeline.add(ForecastDayPoint(
        date: currentDay,
        startingBalance: startingDayBalance,
        inflows: dayInTotal,
        outflows: dayOutTotal,
        endingBalance: runningBalance,
        eventSummaries: events,
      ));

      // Check for Shortfall
      if (runningBalance < safetyBuffer) {
        final deficit = (safetyBuffer - runningBalance);
        shortfalls.add(CashShortfall(
          date: currentDay,
          projectedBalance: runningBalance,
          bufferThreshold: safetyBuffer,
          deficitAmount: deficit,
          triggers: dayOutflows,
          explanation: 'On ${currentDay.day}/${currentDay.month}, projected cash drops to ₹${runningBalance.toStringAsFixed(0)} (below buffer threshold of ₹${safetyBuffer.toStringAsFixed(0)}) due to: ${dayOutflows.map((e) => e.title).join(", ")}.',
        ));
      }
    }

    final totalIncome = adjustedIncomes.fold<double>(0.0, (sum, i) => sum + i.amount);
    final totalOutflow = obligations.fold<double>(0.0, (sum, o) => sum + o.remainingCommitment);

    return ForecastSummary(
      availableCashNow: startingCashBalance,
      totalExpectedIncome: totalIncome,
      totalExpectedCommitments: totalOutflow,
      projectedNetFlow: totalIncome - totalOutflow,
      projectedClosingBalance: startingCashBalance + totalIncome - totalOutflow,
      shortfalls: shortfalls,
      timeline: timeline,
      obligations: obligations,
      incomes: adjustedIncomes,
      lastCalculatedAt: DateTime.now(),
    );
  }
}
