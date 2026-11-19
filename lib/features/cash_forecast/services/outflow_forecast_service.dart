import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../bills/models/bills_models.dart';
import '../../school_fees/models/school_fees_models.dart';
import '../../vehicle/models/vehicle_models.dart';
import '../../property/models/property_models.dart';
import '../../domestic_help/models/domestic_help_models.dart';
import '../../household/models/household_models.dart';
import '../../reminders/models/reminder.dart';
import '../../warranty/models/product.dart';
import '../models/outflow_forecast_models.dart';

class OutflowForecastService {
  static const String catBills = 'Bills & Utilities';
  static const String catLoans = 'Loans & EMIs';
  static const String catSchool = 'School & Education';
  static const String catVehicle = 'Vehicle & Transport';
  static const String catProperty = 'Property & Housing';
  static const String catDomestic = 'Domestic Help & Staff';
  static const String catHousehold = 'Household & Living';
  static const String catWarranties = 'Warranties & AMC';
  static const String catOther = 'Other Commitments';

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case catBills:
        return Icons.receipt_long_rounded;
      case catLoans:
        return Icons.account_balance_rounded;
      case catSchool:
        return Icons.school_rounded;
      case catVehicle:
        return Icons.directions_car_rounded;
      case catProperty:
        return Icons.apartment_rounded;
      case catDomestic:
        return Icons.people_alt_rounded;
      case catHousehold:
        return Icons.shopping_bag_outlined;
      case catWarranties:
        return Icons.verified_user_rounded;
      default:
        return Icons.alarm_rounded;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case catBills:
        return Colors.teal;
      case catLoans:
        return Colors.indigo;
      case catSchool:
        return Colors.deepOrange;
      case catVehicle:
        return Colors.blue;
      case catProperty:
        return Colors.brown;
      case catDomestic:
        return Colors.purple;
      case catHousehold:
        return Colors.orange;
      case catWarranties:
        return Colors.cyan;
      default:
        return Colors.blueGrey;
    }
  }

  static DateTime _getNextMonthlyOccurrence(DateTime fromDate, int dueDay) {
    final clampedDay = dueDay.clamp(1, 28);
    var target = DateTime(fromDate.year, fromDate.month, clampedDay);
    if (target.isBefore(fromDate)) {
      target = DateTime(fromDate.year, fromDate.month + 1, clampedDay);
    }
    return target;
  }

  /// Builds a complete Outflow Horizon Report for the requested horizon (Month, Quarter, Year)
  static OutflowHorizonReport generateReport({
    required OutflowHorizon horizon,
    required DateTime now,
    List<Bill> bills = const [],
    List<BillAccount> billAccounts = const [],
    List<FeeInstallment> feeInstallments = const [],
    List<Vehicle> vehicles = const [],
    List<Property> properties = const [],
    List<DomesticWorker> domesticWorkers = const [],
    List<RecurringService> recurringServices = const [],
    List<HouseholdExpense> householdExpenses = const [],
    List<Reminder> reminders = const [],
    List<Product> products = const [],
  }) {
    final int monthsToProject = horizon.monthCount;
    final DateTime startDate = DateTime(now.year, now.month, now.day);
    // Horizon duration in days
    final DateTime endDate = startDate.add(Duration(days: horizon.days + 2));

    final items = <OutflowItem>[];

    // 1. VEHICLE EMIs (Monthly recurring per vehicle with loan)
    for (final v in vehicles) {
      if (v.loanEmiAmount != null && v.loanEmiAmount! > 0) {
        final firstDate = _getNextMonthlyOccurrence(startDate, 10);
        for (int m = 0; m < monthsToProject; m++) {
          final dueDate = DateTime(firstDate.year, firstDate.month + m, firstDate.day);
          items.add(OutflowItem(
            id: 'outflow_veh_emi_${v.id}_${dueDate.year}_${dueDate.month}',
            title: '${v.name} Loan EMI',
            category: catLoans,
            amount: v.loanEmiAmount!,
            dueDate: dueDate,
            isRecurring: true,
            isFixed: true,
            isEstimate: false,
            sourceRecordId: v.id,
            route: '/vehicle',
          ));
        }
      }

      // Vehicle Insurance (annual)
      if (!v.insuranceExpiry.isBefore(startDate) && !v.insuranceExpiry.isAfter(endDate)) {
        items.add(OutflowItem(
          id: 'outflow_veh_ins_${v.id}',
          title: '${v.name} Insurance Renewal',
          category: catVehicle,
          amount: 12000.0, // Standard benchmark estimate
          dueDate: v.insuranceExpiry,
          isRecurring: true,
          isFixed: true,
          isEstimate: true,
          sourceRecordId: v.id,
          route: '/vehicle',
        ));
      }

      // Vehicle PUC Renewal
      if (!v.pucExpiry.isBefore(startDate) && !v.pucExpiry.isAfter(endDate)) {
        items.add(OutflowItem(
          id: 'outflow_veh_puc_${v.id}',
          title: '${v.name} PUC Certification',
          category: catVehicle,
          amount: 150.0,
          dueDate: v.pucExpiry,
          isRecurring: true,
          isFixed: true,
          isEstimate: false,
          sourceRecordId: v.id,
          route: '/vehicle',
        ));
      }

      // Scheduled Maintenance
      if (v.nextServiceDate != null &&
          !v.nextServiceDate!.isBefore(startDate) &&
          !v.nextServiceDate!.isAfter(endDate)) {
        items.add(OutflowItem(
          id: 'outflow_veh_srv_${v.id}',
          title: '${v.name} Scheduled Service',
          category: catVehicle,
          amount: 6500.0,
          dueDate: v.nextServiceDate!,
          isRecurring: true,
          isFixed: false,
          isEstimate: true,
          sourceRecordId: v.id,
          route: '/vehicle',
        ));
      }
    }

    // 2. DOMESTIC HELP SALARIES (Monthly recurring)
    for (final worker in domesticWorkers) {
      if (worker.isActive && worker.baseSalary > 0) {
        final firstDate = _getNextMonthlyOccurrence(startDate, worker.paymentDueDay);
        for (int m = 0; m < monthsToProject; m++) {
          final dueDate = DateTime(firstDate.year, firstDate.month + m, firstDate.day);
          items.add(OutflowItem(
            id: 'outflow_dom_salary_${worker.id}_${dueDate.year}_${dueDate.month}',
            title: '${worker.role} Salary (${worker.name})',
            category: catDomestic,
            amount: worker.baseSalary,
            dueDate: dueDate,
            isRecurring: true,
            isFixed: true,
            isEstimate: false,
            sourceRecordId: worker.id,
            route: '/domestic-help',
          ));
        }
      }
    }

    // 3. RECURRING HOUSEHOLD SERVICES (Milk, Newspaper, Water)
    for (final serv in recurringServices) {
      if (serv.isActive && serv.unitRate > 0) {
        final estMonthly = serv.defaultDailyQuantity * serv.unitRate * 30;
        final firstDate = _getNextMonthlyOccurrence(startDate, 28);
        for (int m = 0; m < monthsToProject; m++) {
          final dueDate = DateTime(firstDate.year, firstDate.month + m, firstDate.day);
          items.add(OutflowItem(
            id: 'outflow_rec_serv_${serv.id}_${dueDate.year}_${dueDate.month}',
            title: '${serv.name} Delivery',
            category: catDomestic,
            amount: estMonthly,
            dueDate: dueDate,
            isRecurring: true,
            isFixed: false,
            isEstimate: true,
            sourceRecordId: serv.id,
            route: '/domestic-help',
          ));
        }
      }
    }

    // 4. BILLS & SUBSCRIPTIONS
    // Include all active pending bills in the window
    final Set<String> processedBillPeriods = {};
    for (final b in bills) {
      if (b.status.toLowerCase() != 'paid') {
        final isOverdue = b.dueDate.isBefore(startDate);
        if (isOverdue || (!b.dueDate.isBefore(startDate) && !b.dueDate.isAfter(endDate))) {
          final key = '${b.billAccountId}_${b.dueDate.year}_${b.dueDate.month}';
          processedBillPeriods.add(key);

          final isFixedType = b.displayTitle().toLowerCase().contains('loan') ||
              b.displayTitle().toLowerCase().contains('emi') ||
              b.displayTitle().toLowerCase().contains('rent') ||
              b.displayTitle().toLowerCase().contains('subscription');

          items.add(OutflowItem(
            id: 'outflow_bill_${b.id}',
            title: b.displayTitle(),
            category: isFixedType ? catLoans : catBills,
            amount: b.amount,
            dueDate: isOverdue ? startDate : b.dueDate,
            isRecurring: true,
            isFixed: isFixedType,
            isEstimate: false,
            isOverdue: isOverdue,
            sourceRecordId: b.id,
            route: '/bills',
          ));
        }
      }
    }

    // Project future monthly/quarterly/annual bills for BillAccounts if not yet generated as individual bills
    for (final acc in billAccounts) {
      if (acc.isActive && acc.defaultAmount > 0) {
        if (acc.billingCycle.toLowerCase() == 'monthly') {
          final firstDate = _getNextMonthlyOccurrence(startDate, acc.dueDayOfMonth);
          for (int m = 0; m < monthsToProject; m++) {
            final dueDate = DateTime(firstDate.year, firstDate.month + m, firstDate.day);
            final key = '${acc.id}_${dueDate.year}_${dueDate.month}';

            // Avoid double counting if already present in pending bills
            if (!processedBillPeriods.contains(key)) {
              items.add(OutflowItem(
                id: 'outflow_proj_bill_${acc.id}_${dueDate.year}_${dueDate.month}',
                title: '${acc.name} (${DateFormat("MMM yyyy").format(dueDate)})',
                category: acc.category.toLowerCase().contains('credit') ? catLoans : catBills,
                amount: acc.defaultAmount,
                dueDate: dueDate,
                isRecurring: true,
                isFixed: acc.isSubscription,
                isEstimate: !acc.isSubscription,
                sourceRecordId: acc.id,
                route: '/bills',
              ));
            }
          }
        } else if (acc.billingCycle.toLowerCase() == 'quarterly') {
          for (int m = 0; m < monthsToProject; m += 3) {
            final firstDate = _getNextMonthlyOccurrence(startDate, acc.dueDayOfMonth);
            final dueDate = DateTime(firstDate.year, firstDate.month + m, firstDate.day);
            if (!dueDate.isBefore(startDate) && !dueDate.isAfter(endDate)) {
              items.add(OutflowItem(
                id: 'outflow_proj_qbill_${acc.id}_${dueDate.year}_${dueDate.month}',
                title: '${acc.name} (Quarterly)',
                category: catBills,
                amount: acc.defaultAmount,
                dueDate: dueDate,
                isRecurring: true,
                isFixed: true,
                isEstimate: false,
                sourceRecordId: acc.id,
                route: '/bills',
              ));
            }
          }
        } else if (acc.billingCycle.toLowerCase() == 'yearly' && acc.renewalDate != null) {
          if (!acc.renewalDate!.isBefore(startDate) && !acc.renewalDate!.isAfter(endDate)) {
            items.add(OutflowItem(
              id: 'outflow_proj_ybill_${acc.id}',
              title: '${acc.name} (Annual Renewal)',
              category: catBills,
              amount: acc.defaultAmount,
              dueDate: acc.renewalDate!,
              isRecurring: true,
              isFixed: true,
              isEstimate: false,
              sourceRecordId: acc.id,
              route: '/bills',
            ));
          }
        }
      }
    }

    // 5. SCHOOL / EDUCATION FEES
    for (final fee in feeInstallments) {
      if (!fee.isSettled) {
        final isOverdue = fee.dueDate.isBefore(startDate);
        if (isOverdue || (!fee.dueDate.isBefore(startDate) && !fee.dueDate.isAfter(endDate))) {
          items.add(OutflowItem(
            id: 'outflow_fee_${fee.id}',
            title: fee.title,
            category: catSchool,
            amount: fee.netPayable,
            dueDate: isOverdue ? startDate : fee.dueDate,
            isRecurring: true,
            isFixed: true,
            isEstimate: false,
            isOverdue: isOverdue,
            sourceRecordId: fee.id,
            route: '/school-fees',
          ));
        }
      }
    }

    // 6. PROPERTY TAXES & CHARGES
    for (final prop in properties) {
      if (prop.propertyTaxAmount > 0) {
        final isOverdue = prop.taxDueDate.isBefore(startDate);
        if (isOverdue || (!prop.taxDueDate.isBefore(startDate) && !prop.taxDueDate.isAfter(endDate))) {
          items.add(OutflowItem(
            id: 'outflow_proptax_${prop.id}',
            title: 'Property Tax: ${prop.title}',
            category: catProperty,
            amount: prop.propertyTaxAmount,
            dueDate: isOverdue ? startDate : prop.taxDueDate,
            isRecurring: true,
            isFixed: true,
            isEstimate: false,
            isOverdue: isOverdue,
            sourceRecordId: prop.id,
            route: '/property',
          ));
        }
      }
    }

    // 7. HOUSEHOLD EXPENSES & REGULAR UTILITIES
    for (final exp in householdExpenses) {
      if (exp.status.toLowerCase() != 'paid') {
        final isOverdue = exp.dueDate.isBefore(startDate);
        if (isOverdue || (!exp.dueDate.isBefore(startDate) && !exp.dueDate.isAfter(endDate))) {
          items.add(OutflowItem(
            id: 'outflow_hh_${exp.id}',
            title: '${exp.category} (${exp.providerName})',
            category: catHousehold,
            amount: exp.amount,
            dueDate: isOverdue ? startDate : exp.dueDate,
            isRecurring: false,
            isFixed: false,
            isEstimate: false,
            isOverdue: isOverdue,
            sourceRecordId: exp.id,
            route: '/household',
          ));
        }
      }
    }

    // 8. FINANCIAL REMINDERS
    for (final rem in reminders) {
      if (rem.isFinancial == true && (rem.amount != null && rem.amount! > 0) && !rem.isCompleted) {
        final isOverdue = rem.dueDate.isBefore(startDate);
        if (isOverdue || (!rem.dueDate.isBefore(startDate) && !rem.dueDate.isAfter(endDate))) {
          // Avoid duplicating already captured bills/fees
          final alreadyCaptured = items.any((i) => i.sourceRecordId == rem.linkedRecordId);
          if (!alreadyCaptured) {
            items.add(OutflowItem(
              id: 'outflow_rem_${rem.id}',
              title: rem.title,
              category: catOther,
              amount: rem.amount!,
              dueDate: isOverdue ? startDate : rem.dueDate,
              isRecurring: rem.repeatSchedule != null,
              isFixed: true,
              isEstimate: false,
              isOverdue: isOverdue,
              sourceRecordId: rem.id,
              route: '/reminders',
            ));
          }
        }
      }
    }

    // 9. WARRANTY & AMC EXPIRIES (Optional renewal estimates)
    for (final p in products) {
      final expiry = p.extendedWarrantyExpiry ?? p.warrantyEndDate;
      if (expiry != null && !expiry.isBefore(startDate) && !expiry.isAfter(endDate)) {
        // Estimated AMC / renewal is ~10% of purchase price if above ₹500
        final estRenewal = (p.price * 0.1).clamp(500.0, 5000.0);
        items.add(OutflowItem(
          id: 'outflow_prod_amc_${p.id}',
          title: '${p.name} Warranty / AMC Renewal',
          category: catWarranties,
          amount: estRenewal,
          dueDate: expiry,
          isRecurring: true,
          isFixed: false,
          isEstimate: true,
          sourceRecordId: p.id,
          route: '/warranty',
        ));
      }
    }

    // Sort all items chronologically
    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // Calculate Totals
    final double totalOutflow = items.fold(0.0, (sum, i) => sum + i.amount);
    final double fixedOutflow = items.where((i) => i.isFixed).fold(0.0, (sum, i) => sum + i.amount);
    final double variableOutflow = items.where((i) => !i.isFixed).fold(0.0, (sum, i) => sum + i.amount);
    final double averageMonthlyOutflow = monthsToProject > 0 ? (totalOutflow / monthsToProject) : 0.0;

    // Calculate Category Breakdown
    final Map<String, List<OutflowItem>> categoryMap = {};
    for (final item in items) {
      categoryMap.putIfAbsent(item.category, () => []).add(item);
    }

    final categoryBreakdown = categoryMap.entries.map((entry) {
      final catAmount = entry.value.fold(0.0, (sum, i) => sum + i.amount);
      final percentage = totalOutflow > 0 ? (catAmount / totalOutflow) : 0.0;
      return OutflowCategorySummary(
        category: entry.key,
        totalAmount: catAmount,
        percentage: percentage,
        itemCount: entry.value.length,
        icon: getCategoryIcon(entry.key),
        color: getCategoryColor(entry.key),
      );
    }).toList();

    // Sort categories by highest outflow amount
    categoryBreakdown.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // Calculate Monthly Trend
    final monthlyTrend = <MonthlyOutflowPoint>[];
    double maxMonthAmount = 0.0;

    final Set<int> monthKeys = {};
    for (final item in items) {
      monthKeys.add(item.dueDate.year * 100 + item.dueDate.month);
    }

    if (monthKeys.isEmpty) {
      for (int m = 0; m < monthsToProject; m++) {
        final d = DateTime(startDate.year, startDate.month + m, 1);
        monthKeys.add(d.year * 100 + d.month);
      }
    }

    final sortedMonthKeys = monthKeys.toList()..sort();

    for (final key in sortedMonthKeys) {
      final targetYear = key ~/ 100;
      final targetMonth = key % 100;
      final monthDate = DateTime(targetYear, targetMonth, 1);
      final label = DateFormat('MMM yyyy').format(monthDate);

      final monthItems = items.where((i) =>
          i.dueDate.year == targetYear && i.dueDate.month == targetMonth).toList();

      final monthTotal = monthItems.fold(0.0, (sum, i) => sum + i.amount);
      final monthFixed = monthItems.where((i) => i.isFixed).fold(0.0, (sum, i) => sum + i.amount);
      final monthVar = monthItems.where((i) => !i.isFixed).fold(0.0, (sum, i) => sum + i.amount);

      if (monthTotal > maxMonthAmount) {
        maxMonthAmount = monthTotal;
      }

      monthlyTrend.add(MonthlyOutflowPoint(
        monthDate: monthDate,
        monthLabel: label,
        totalAmount: monthTotal,
        fixedAmount: monthFixed,
        variableAmount: monthVar,
        obligationCount: monthItems.length,
      ));
    }

    // Flag peak month(s)
    final adjustedTrend = monthlyTrend.map((pt) {
      final isPeak = maxMonthAmount > 0 && pt.totalAmount >= maxMonthAmount && monthsToProject > 1;
      return MonthlyOutflowPoint(
        monthDate: pt.monthDate,
        monthLabel: pt.monthLabel,
        totalAmount: pt.totalAmount,
        fixedAmount: pt.fixedAmount,
        variableAmount: pt.variableAmount,
        obligationCount: pt.obligationCount,
        isPeakMonth: isPeak,
      );
    }).toList();

    return OutflowHorizonReport(
      horizon: horizon,
      startDate: startDate,
      endDate: endDate,
      totalOutflow: totalOutflow,
      fixedOutflow: fixedOutflow,
      variableOutflow: variableOutflow,
      averageMonthlyOutflow: averageMonthlyOutflow,
      categoryBreakdown: categoryBreakdown,
      monthlyTrend: adjustedTrend,
      allItems: items,
    );
  }
}
