import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../finance/models/finance_models.dart';
import '../../household/models/household_models.dart';
import '../../school_fees/models/school_fees_models.dart';
import '../../vehicle/models/vehicle_models.dart';
import '../../property/models/property_models.dart';
import '../../bills/models/bills_models.dart';
import '../../reminders/models/reminder.dart';
import '../models/report_models.dart';

class FinancialAnalyticsService {
  // Category Color & Icon Configuration
  static const Map<String, Color> categoryColors = {
    'Household': Color(0xFF2E7D32),  // Forest Green
    'Education': Color(0xFF6A1B9A),  // Deep Purple
    'Vehicle': Color(0xFFC62828),    // Crimson Red
    'Property': Color(0xFFE65100),   // Dark Orange
    'Financial': Color(0xFF1565C0),  // Deep Blue
    'Healthcare': Color(0xFF00838F), // Teal
    'Lifestyle': Color(0xFFAD1457),  // Pink / Magenta
    'Other': Color(0xFF455A64),      // Slate Grey
  };

  static const Map<String, IconData> categoryIcons = {
    'Household': Icons.home_rounded,
    'Education': Icons.school_rounded,
    'Vehicle': Icons.directions_car_rounded,
    'Property': Icons.apartment_rounded,
    'Financial': Icons.account_balance_rounded,
    'Healthcare': Icons.local_hospital_rounded,
    'Lifestyle': Icons.local_mall_rounded,
    'Other': Icons.category_rounded,
  };

  /// Compute date range for standard periods
  static ReportDateRange getDateRange({
    required ReportPeriodType periodType,
    required DateTime referenceDate,
    YearType yearType = YearType.financialYear,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final year = referenceDate.year;
    final month = referenceDate.month;

    switch (periodType) {
      case ReportPeriodType.monthly:
        final start = DateTime(year, month, 1);
        final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
        final end = nextMonth.subtract(const Duration(milliseconds: 1));
        return ReportDateRange(
          start: start,
          end: end,
          label: DateFormat('MMMM yyyy').format(start),
          periodType: periodType,
          yearType: yearType,
        );

      case ReportPeriodType.quarterly:
        if (yearType == YearType.financialYear) {
          // Indian FY starts April: Q1 (Apr-Jun), Q2 (Jul-Sep), Q3 (Oct-Dec), Q4 (Jan-Mar)
          int qIndex;
          int fyStartYear;
          if (month >= 4) {
            fyStartYear = year;
            qIndex = (month - 4) ~/ 3 + 1; // 1, 2, or 3
          } else {
            fyStartYear = year - 1;
            qIndex = 4; // Jan - Mar
          }

          late DateTime start;
          late DateTime end;
          if (qIndex == 1) {
            start = DateTime(fyStartYear, 4, 1);
            end = DateTime(fyStartYear, 6, 30, 23, 59, 59, 999);
          } else if (qIndex == 2) {
            start = DateTime(fyStartYear, 7, 1);
            end = DateTime(fyStartYear, 9, 30, 23, 59, 59, 999);
          } else if (qIndex == 3) {
            start = DateTime(fyStartYear, 10, 1);
            end = DateTime(fyStartYear, 12, 31, 23, 59, 59, 999);
          } else {
            start = DateTime(fyStartYear + 1, 1, 1);
            end = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59, 999);
          }
          final fyLabel = 'FY ${fyStartYear.toString().substring(2)}-${(fyStartYear + 1).toString().substring(2)}';
          return ReportDateRange(
            start: start,
            end: end,
            label: 'Q$qIndex ($fyLabel)',
            periodType: periodType,
            yearType: yearType,
          );
        } else {
          // Calendar Year: Q1 (Jan-Mar), Q2 (Apr-Jun), Q3 (Jul-Sep), Q4 (Oct-Dec)
          final qIndex = (month - 1) ~/ 3 + 1;
          final startMonth = (qIndex - 1) * 3 + 1;
          final start = DateTime(year, startMonth, 1);
          final endMonth = startMonth + 2;
          final nextMonth = endMonth == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, endMonth + 1, 1);
          final end = nextMonth.subtract(const Duration(milliseconds: 1));
          return ReportDateRange(
            start: start,
            end: end,
            label: 'Q$qIndex $year',
            periodType: periodType,
            yearType: yearType,
          );
        }

      case ReportPeriodType.halfYearly:
        if (yearType == YearType.financialYear) {
          int fyStartYear = month >= 4 ? year : year - 1;
          final isH1 = month >= 4 && month <= 9;
          final start = isH1 ? DateTime(fyStartYear, 4, 1) : DateTime(fyStartYear, 10, 1);
          final end = isH1
              ? DateTime(fyStartYear, 9, 30, 23, 59, 59, 999)
              : DateTime(fyStartYear + 1, 3, 31, 23, 59, 59, 999);
          final fyLabel = 'FY ${fyStartYear.toString().substring(2)}-${(fyStartYear + 1).toString().substring(2)}';
          return ReportDateRange(
            start: start,
            end: end,
            label: '${isH1 ? "H1" : "H2"} ($fyLabel)',
            periodType: periodType,
            yearType: yearType,
          );
        } else {
          final isH1 = month <= 6;
          final start = isH1 ? DateTime(year, 1, 1) : DateTime(year, 7, 1);
          final end = isH1
              ? DateTime(year, 6, 30, 23, 59, 59, 999)
              : DateTime(year, 12, 31, 23, 59, 59, 999);
          return ReportDateRange(
            start: start,
            end: end,
            label: '${isH1 ? "H1" : "H2"} $year',
            periodType: periodType,
            yearType: yearType,
          );
        }

      case ReportPeriodType.annual:
        if (yearType == YearType.financialYear) {
          int fyStartYear = month >= 4 ? year : year - 1;
          final start = DateTime(fyStartYear, 4, 1);
          final end = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59, 999);
          return ReportDateRange(
            start: start,
            end: end,
            label: 'Financial Year $fyStartYear-${fyStartYear + 1}',
            periodType: periodType,
            yearType: yearType,
          );
        } else {
          final start = DateTime(year, 1, 1);
          final end = DateTime(year, 12, 31, 23, 59, 59, 999);
          return ReportDateRange(
            start: start,
            end: end,
            label: 'Calendar Year $year',
            periodType: periodType,
            yearType: yearType,
          );
        }

      case ReportPeriodType.allTime:
        return ReportDateRange(
          start: DateTime(2020, 1, 1),
          end: DateTime.now().add(const Duration(days: 365 * 10)),
          label: 'All Time Overview',
          periodType: periodType,
          yearType: yearType,
        );

      case ReportPeriodType.custom:
        final start = customStart ?? DateTime(year, month, 1);
        final end = customEnd != null
            ? DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999)
            : DateTime(year, month, 28, 23, 59, 59, 999);
        return ReportDateRange(
          start: start,
          end: end,
          label: '${DateFormat('dd MMM yyyy').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}',
          periodType: periodType,
          yearType: yearType,
        );
    }
  }

  /// Get the immediately previous period for period-over-period comparison
  static ReportDateRange getPreviousPeriod(ReportDateRange current) {
    switch (current.periodType) {
      case ReportPeriodType.monthly:
        final prevMonthDate = DateTime(current.start.year, current.start.month - 1, 1);
        return getDateRange(
          periodType: ReportPeriodType.monthly,
          referenceDate: prevMonthDate,
          yearType: current.yearType,
        );

      case ReportPeriodType.quarterly:
        final prevQuarterDate = current.start.subtract(const Duration(days: 15));
        return getDateRange(
          periodType: ReportPeriodType.quarterly,
          referenceDate: prevQuarterDate,
          yearType: current.yearType,
        );

      case ReportPeriodType.halfYearly:
        final prevHalfDate = current.start.subtract(const Duration(days: 30));
        return getDateRange(
          periodType: ReportPeriodType.halfYearly,
          referenceDate: prevHalfDate,
          yearType: current.yearType,
        );

      case ReportPeriodType.annual:
        final prevYearDate = DateTime(current.start.year - 1, current.start.month, current.start.day);
        return getDateRange(
          periodType: ReportPeriodType.annual,
          referenceDate: prevYearDate,
          yearType: current.yearType,
        );

      case ReportPeriodType.allTime:
        return current;

      case ReportPeriodType.custom:
        final duration = current.end.difference(current.start);
        final prevEnd = current.start.subtract(const Duration(milliseconds: 1));
        final prevStart = prevEnd.subtract(duration);
        return ReportDateRange(
          start: prevStart,
          end: prevEnd,
          label: 'Previous Period',
          periodType: ReportPeriodType.custom,
          yearType: current.yearType,
        );
    }
  }

  /// Map expense descriptions/subcategories to standard top-level categories
  static String mapToTopCategory(String sourceCategory, String description) {
    final lower = '$sourceCategory $description'.toLowerCase();

    if (lower.contains('electric') ||
        lower.contains('water') ||
        lower.contains('gas') ||
        lower.contains('internet') ||
        lower.contains('broadband') ||
        lower.contains('wifi') ||
        lower.contains('maid') ||
        lower.contains('cook') ||
        lower.contains('rent') ||
        lower.contains('grocery') ||
        lower.contains('groceries') ||
        lower.contains('newspaper') ||
        lower.contains('waste') ||
        lower.contains('milk') ||
        lower.contains('household')) {
      return 'Household';
    }

    if (lower.contains('school') ||
        lower.contains('tuition') ||
        lower.contains('books') ||
        lower.contains('uniform') ||
        lower.contains('education') ||
        lower.contains('college') ||
        lower.contains('exam')) {
      return 'Education';
    }

    if (lower.contains('car') ||
        lower.contains('bike') ||
        lower.contains('vehicle') ||
        lower.contains('fuel') ||
        lower.contains('petrol') ||
        lower.contains('diesel') ||
        lower.contains('service') ||
        lower.contains('puc') ||
        lower.contains('motor')) {
      return 'Vehicle';
    }

    if (lower.contains('property') ||
        lower.contains('tax') ||
        lower.contains('apartment') ||
        lower.contains('flat') ||
        lower.contains('land') ||
        lower.contains('villa') ||
        lower.contains('renovation') ||
        lower.contains('plumbing') ||
        lower.contains('painting')) {
      return 'Property';
    }

    if (lower.contains('emi') ||
        lower.contains('loan') ||
        lower.contains('bank') ||
        lower.contains('credit card') ||
        lower.contains('sip') ||
        lower.contains('mutual fund') ||
        lower.contains('fd') ||
        lower.contains('insurance') ||
        lower.contains('interest')) {
      return 'Financial';
    }

    if (lower.contains('doctor') ||
        lower.contains('hospital') ||
        lower.contains('medicine') ||
        lower.contains('medical') ||
        lower.contains('health') ||
        lower.contains('pharmacy') ||
        lower.contains('clinic')) {
      return 'Healthcare';
    }

    if (lower.contains('dine') ||
        lower.contains('food') ||
        lower.contains('restaurant') ||
        lower.contains('shopping') ||
        lower.contains('movie') ||
        lower.contains('travel') ||
        lower.contains('flight') ||
        lower.contains('hotel') ||
        lower.contains('subscription') ||
        lower.contains('ott') ||
        lower.contains('netflix')) {
      return 'Lifestyle';
    }

    return 'Other';
  }

  /// Unified aggregation across all diary modules
  static FinancialPeriodSummary generateReport({
    required ReportDateRange dateRange,
    required List<FinancialTransaction> financialTransactions,
    required List<HouseholdExpense> householdExpenses,
    required List<Child> children,
    required List<FeeInstallment> feeInstallments,
    required List<Vehicle> vehicles,
    required List<ServiceRecord> vehicleServices,
    required List<Property> properties,
    required List<PropertyMaintenance> propertyMaintenances,
    required List<BillAccount> billAccounts,
    required List<Bill> bills,
    required List<Reminder> reminders,
    String sourceModuleFilter = 'All', // 'All', 'Finance', 'Household', 'SchoolFees', 'Vehicle', 'Property', 'Bills'
    List<UnifiedTransaction>? previousPeriodTransactions,
  }) {
    final List<UnifiedTransaction> allPeriodTransactions = [];
    final List<UpcomingObligation> allUpcomingObligations = [];

    final now = DateTime.now();

    // 1. Process FinancialTransactions
    if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Finance') {
      for (final t in financialTransactions) {
        if (dateRange.contains(t.date)) {
          final lowerType = t.type.toLowerCase();
          TransactionFlow flow;
          String category;

          if (lowerType == 'income') {
            flow = TransactionFlow.income;
            category = 'Income';
          } else if (lowerType == 'transfer') {
            flow = TransactionFlow.transfer;
            category = 'Transfer';
          } else if (lowerType == 'refund') {
            flow = TransactionFlow.refund;
            category = 'Refund';
          } else {
            flow = TransactionFlow.expense;
            category = mapToTopCategory(t.category, t.description);
          }

          allPeriodTransactions.add(UnifiedTransaction(
            id: t.id,
            title: t.description.isNotEmpty ? t.description : t.category,
            flow: flow,
            category: category,
            subcategory: t.category,
            amount: t.amount,
            date: t.date,
            paymentMethod: t.paymentMethod,
            sourceModule: 'Finance',
            status: 'completed',
          ));
        }
      }
    }

    // 2. Process HouseholdExpenses
    if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Household') {
      for (final h in householdExpenses) {
        final isPaid = h.status.toLowerCase() == 'paid';
        if (isPaid && dateRange.contains(h.dueDate)) {
          allPeriodTransactions.add(UnifiedTransaction(
            id: h.id,
            title: '${h.category} - ${h.providerName}',
            flow: TransactionFlow.expense,
            category: 'Household',
            subcategory: h.category,
            amount: h.amount,
            date: h.dueDate,
            sourceModule: 'Household',
            notes: h.period,
            status: 'paid',
          ));
        } else if (!isPaid) {
          allUpcomingObligations.add(UpcomingObligation(
            id: h.id,
            title: '${h.category} (${h.providerName})',
            category: 'Household',
            amount: h.amount,
            dueDate: h.dueDate,
            status: h.dueDate.isBefore(now) ? 'overdue' : 'pending',
            sourceModule: 'Household',
            linkedItem: h.period,
          ));
        }
      }
    }

    // 3. Process School Fees Installments
    final childMap = {for (var c in children) c.id: c};
    if (sourceModuleFilter == 'All' || sourceModuleFilter == 'SchoolFees') {
      for (final inst in feeInstallments) {
        final isPaid = inst.status.toLowerCase() == 'paid' || inst.paidAmount > 0;
        final paymentDate = inst.paidDate ?? inst.dueDate;
        final child = childMap[inst.childId];
        final childLabel = child != null ? child.name : 'Student';

        if (isPaid && dateRange.contains(paymentDate)) {
          final paidAmt = inst.paidAmount > 0 ? inst.paidAmount : inst.amount;
          allPeriodTransactions.add(UnifiedTransaction(
            id: inst.id,
            title: '${inst.title} ($childLabel)',
            flow: TransactionFlow.expense,
            category: 'Education',
            subcategory: 'School Fees',
            amount: paidAmt,
            date: paymentDate,
            sourceModule: 'SchoolFees',
            status: 'paid',
            linkedRecordId: inst.childId,
          ));
        }

        final pendingAmt = inst.amount - inst.paidAmount;
        if (pendingAmt > 0) {
          allUpcomingObligations.add(UpcomingObligation(
            id: inst.id,
            title: '${inst.title} - $childLabel',
            category: 'Education',
            amount: pendingAmt,
            dueDate: inst.dueDate,
            status: inst.dueDate.isBefore(now) ? 'overdue' : inst.status,
            sourceModule: 'SchoolFees',
            linkedItem: child != null && child.schoolName != null ? child.schoolName : null,
          ));
        }
      }
    }

    // 4. Process Vehicle Services & Insurance/PUC Obligations
    if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Vehicle') {
      for (final s in vehicleServices) {
        if (dateRange.contains(s.serviceDate)) {
          allPeriodTransactions.add(UnifiedTransaction(
            id: s.id,
            title: '${s.serviceType} (${s.serviceCenter})',
            flow: TransactionFlow.expense,
            category: 'Vehicle',
            subcategory: s.serviceType,
            amount: s.totalCost,
            date: s.serviceDate,
            sourceModule: 'Vehicle',
            linkedRecordId: s.vehicleId,
          ));
        }
      }

      for (final v in vehicles) {
        if (v.insuranceExpiry.isAfter(now.subtract(const Duration(days: 30)))) {
          allUpcomingObligations.add(UpcomingObligation(
            id: 'veh_ins_${v.id}',
            title: '${v.brand} ${v.model} Insurance Renewal',
            category: 'Vehicle',
            amount: 0.0, // Dependent on quote
            dueDate: v.insuranceExpiry,
            status: v.insuranceExpiry.isBefore(now) ? 'overdue' : 'pending',
            sourceModule: 'Vehicle',
            linkedItem: v.registrationNumber,
          ));
        }
        if (v.pucExpiry.isAfter(now.subtract(const Duration(days: 15)))) {
          allUpcomingObligations.add(UpcomingObligation(
            id: 'veh_puc_${v.id}',
            title: '${v.brand} ${v.model} PUC Pollution Check',
            category: 'Vehicle',
            amount: 150.0,
            dueDate: v.pucExpiry,
            status: v.pucExpiry.isBefore(now) ? 'overdue' : 'pending',
            sourceModule: 'Vehicle',
            linkedItem: v.registrationNumber,
          ));
        }
      }
    }

    // 5. Process Property Maintenance & Tax Obligations
    if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Property') {
      for (final pm in propertyMaintenances) {
        if (dateRange.contains(pm.date)) {
          allPeriodTransactions.add(UnifiedTransaction(
            id: pm.id,
            title: '${pm.title} (${pm.contractorName})',
            flow: TransactionFlow.expense,
            category: 'Property',
            subcategory: pm.category,
            amount: pm.cost,
            date: pm.date,
            sourceModule: 'Property',
            linkedRecordId: pm.propertyId,
          ));
        }
      }

      for (final p in properties) {
        if (p.taxDueDate.isAfter(now.subtract(const Duration(days: 30)))) {
          allUpcomingObligations.add(UpcomingObligation(
            id: 'prop_tax_${p.id}',
            title: 'Property Tax (${p.title})',
            category: 'Property',
            amount: p.propertyTaxAmount,
            dueDate: p.taxDueDate,
            status: p.taxDueDate.isBefore(now) ? 'overdue' : 'pending',
            sourceModule: 'Property',
            linkedItem: p.propertyTaxFrequency,
          ));
        }
      }
    }

    // 6. Process Bills & Recurring Subscriptions
    final billAccountMap = {for (var a in billAccounts) a.id: a};
    if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Bills') {
      for (final b in bills) {
        final acc = billAccountMap[b.billAccountId];
        final title = acc != null ? '${acc.name} (${b.billPeriod})' : 'Bill (${b.billPeriod})';
        final category = acc != null ? mapToTopCategory(acc.category, acc.name) : 'Household';
        final isPaid = b.status.toLowerCase() == 'paid';

        if (isPaid && dateRange.contains(b.dueDate)) {
          allPeriodTransactions.add(UnifiedTransaction(
            id: b.id,
            title: title,
            flow: TransactionFlow.expense,
            category: category,
            subcategory: acc?.category ?? 'Bill',
            amount: b.amount,
            date: b.dueDate,
            sourceModule: 'Bills',
            status: 'paid',
          ));
        } else if (!isPaid) {
          allUpcomingObligations.add(UpcomingObligation(
            id: b.id,
            title: title,
            category: category,
            amount: b.amount,
            dueDate: b.dueDate,
            status: b.dueDate.isBefore(now) ? 'overdue' : b.status,
            sourceModule: 'Bills',
            linkedItem: acc?.providerName,
          ));
        }
      }
    }

    // Sort transactions chronologically descending
    allPeriodTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Sort upcoming obligations by due date ascending
    allUpcomingObligations.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // 7. Calculate Totals & Module Totals
    double totalIncome = 0;
    double totalExpenses = 0;
    final Map<String, double> moduleTotals = {
      'Finance': 0.0,
      'Household': 0.0,
      'SchoolFees': 0.0,
      'Vehicle': 0.0,
      'Property': 0.0,
      'Bills': 0.0,
    };

    for (final t in allPeriodTransactions) {
      if (t.flow == TransactionFlow.income) {
        totalIncome += t.amount;
      } else if (t.flow == TransactionFlow.expense) {
        totalExpenses += t.amount;
        moduleTotals[t.sourceModule] = (moduleTotals[t.sourceModule] ?? 0.0) + t.amount;
      } else if (t.flow == TransactionFlow.refund) {
        totalExpenses -= t.amount; // Transparently adjusts net expense
        moduleTotals[t.sourceModule] = (moduleTotals[t.sourceModule] ?? 0.0) - t.amount;
      }
      // Transfers are strictly ignored from income/expense sums!
    }

    final netSavings = totalIncome - totalExpenses;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0.0;

    // 8. Opening & Closing Balance Calculation
    double openingBalance = 0.0;
    if (dateRange.periodType != ReportPeriodType.allTime) {
      final periodStart = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);

      // Prior Finance transactions
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Finance') {
        for (final t in financialTransactions) {
          final tDay = DateTime(t.date.year, t.date.month, t.date.day);
          if (tDay.isBefore(periodStart)) {
            final lower = t.type.toLowerCase();
            if (lower == 'income') {
              openingBalance += t.amount;
            } else if (lower == 'expense') {
              openingBalance -= t.amount;
            } else if (lower == 'refund') {
              openingBalance += t.amount;
            }
          }
        }
      }
      // Prior Household expenses
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Household') {
        for (final h in householdExpenses) {
          final hDay = DateTime(h.dueDate.year, h.dueDate.month, h.dueDate.day);
          if (h.status.toLowerCase() == 'paid' && hDay.isBefore(periodStart)) {
            openingBalance -= h.amount;
          }
        }
      }
      // Prior School fees
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'SchoolFees') {
        for (final inst in feeInstallments) {
          final pDate = inst.paidDate ?? inst.dueDate;
          final pDay = DateTime(pDate.year, pDate.month, pDate.day);
          if ((inst.status.toLowerCase() == 'paid' || inst.paidAmount > 0) && pDay.isBefore(periodStart)) {
            openingBalance -= (inst.paidAmount > 0 ? inst.paidAmount : inst.amount);
          }
        }
      }
      // Prior Vehicle services
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Vehicle') {
        for (final s in vehicleServices) {
          final sDay = DateTime(s.serviceDate.year, s.serviceDate.month, s.serviceDate.day);
          if (sDay.isBefore(periodStart)) openingBalance -= s.totalCost;
        }
      }
      // Prior Property maintenance
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Property') {
        for (final pm in propertyMaintenances) {
          final pmDay = DateTime(pm.date.year, pm.date.month, pm.date.day);
          if (pmDay.isBefore(periodStart)) openingBalance -= pm.cost;
        }
      }
      // Prior Bills
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Bills') {
        for (final b in bills) {
          final bDay = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day);
          if (b.status.toLowerCase() == 'paid' && bDay.isBefore(periodStart)) {
            openingBalance -= b.amount;
          }
        }
      }
    }
    final closingBalance = openingBalance + netSavings;

    // 9. Calculate Category Breakdown
    final Map<String, double> categorySums = {};
    final Map<String, int> categoryCounts = {};

    for (final t in allPeriodTransactions) {
      if (t.flow == TransactionFlow.expense) {
        categorySums[t.category] = (categorySums[t.category] ?? 0) + t.amount;
        categoryCounts[t.category] = (categoryCounts[t.category] ?? 0) + 1;
      }
    }

    final List<CategoryBreakdown> categoryBreakdowns = [];
    final effectiveTotalExpense = totalExpenses > 0 ? totalExpenses : 1.0;

    categorySums.forEach((cat, amount) {
      final pct = (amount / effectiveTotalExpense) * 100;
      categoryBreakdowns.add(CategoryBreakdown(
        category: cat,
        amount: amount,
        percentage: pct,
        count: categoryCounts[cat] ?? 0,
        color: categoryColors[cat] ?? Colors.grey,
        icon: categoryIcons[cat] ?? Icons.category_rounded,
      ));
    });

    categoryBreakdowns.sort((a, b) => b.amount.compareTo(a.amount));

    // 10. Calculate Monthly Trend Points within the period
    final List<MonthlyTrendPoint> monthlyTrends = [];
    DateTime monthCursor = DateTime(dateRange.start.year, dateRange.start.month, 1);
    final endMonth = DateTime(dateRange.end.year, dateRange.end.month, 1);

    while (!monthCursor.isAfter(endMonth)) {
      final mStart = DateTime(monthCursor.year, monthCursor.month, 1);
      final nextMonth = monthCursor.month == 12
          ? DateTime(monthCursor.year + 1, 1, 1)
          : DateTime(monthCursor.year, monthCursor.month + 1, 1);

      double mIncome = 0;
      double mExpense = 0;

      for (final t in allPeriodTransactions) {
        if (t.date.year == monthCursor.year && t.date.month == monthCursor.month) {
          if (t.flow == TransactionFlow.income) mIncome += t.amount;
          if (t.flow == TransactionFlow.expense) mExpense += t.amount;
          if (t.flow == TransactionFlow.refund) mExpense -= t.amount;
        }
      }

      monthlyTrends.add(MonthlyTrendPoint(
        monthLabel: DateFormat('MMM yy').format(mStart),
        monthDate: mStart,
        income: mIncome,
        expense: mExpense,
        savings: mIncome - mExpense,
      ));

      monthCursor = nextMonth;
    }

    // 11. Period Comparison Metrics (Automated)
    double prevIncome = 0;
    double prevExpenses = 0;

    if (previousPeriodTransactions != null) {
      for (final pt in previousPeriodTransactions) {
        if (pt.flow == TransactionFlow.income) prevIncome += pt.amount;
        if (pt.flow == TransactionFlow.expense) prevExpenses += pt.amount;
        if (pt.flow == TransactionFlow.refund) prevExpenses -= pt.amount;
      }
    } else if (dateRange.periodType != ReportPeriodType.allTime) {
      final prevRange = getPreviousPeriod(dateRange);

      // Previous period finance txs
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Finance') {
        for (final t in financialTransactions) {
          if (prevRange.contains(t.date)) {
            final lower = t.type.toLowerCase();
            if (lower == 'income') {
              prevIncome += t.amount;
            } else if (lower == 'expense') {
              prevExpenses += t.amount;
            } else if (lower == 'refund') {
              prevExpenses -= t.amount;
            }
          }
        }
      }
      // Previous period household
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Household') {
        for (final h in householdExpenses) {
          if (h.status.toLowerCase() == 'paid' && prevRange.contains(h.dueDate)) {
            prevExpenses += h.amount;
          }
        }
      }
      // Previous period school fees
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'SchoolFees') {
        for (final inst in feeInstallments) {
          final pDate = inst.paidDate ?? inst.dueDate;
          if ((inst.status.toLowerCase() == 'paid' || inst.paidAmount > 0) && prevRange.contains(pDate)) {
            prevExpenses += (inst.paidAmount > 0 ? inst.paidAmount : inst.amount);
          }
        }
      }
      // Previous period vehicle services
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Vehicle') {
        for (final s in vehicleServices) {
          if (prevRange.contains(s.serviceDate)) prevExpenses += s.totalCost;
        }
      }
      // Previous period property maintenances
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Property') {
        for (final pm in propertyMaintenances) {
          if (prevRange.contains(pm.date)) prevExpenses += pm.cost;
        }
      }
      // Previous period bills
      if (sourceModuleFilter == 'All' || sourceModuleFilter == 'Bills') {
        for (final b in bills) {
          if (b.status.toLowerCase() == 'paid' && prevRange.contains(b.dueDate)) {
            prevExpenses += b.amount;
          }
        }
      }
    }

    final double expenseChangePct = prevExpenses > 0
        ? ((totalExpenses - prevExpenses) / prevExpenses) * 100
        : 0.0;
    final double incomeChangePct = prevIncome > 0
        ? ((totalIncome - prevIncome) / prevIncome) * 100
        : 0.0;

    final baseSummary = FinancialPeriodSummary(
      dateRange: dateRange,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netSavings: netSavings,
      savingsRate: savingsRate,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      previousPeriodExpenses: prevExpenses,
      previousPeriodIncome: prevIncome,
      expenseChangePct: expenseChangePct,
      incomeChangePct: incomeChangePct,
      transactions: allPeriodTransactions,
      categoryBreakdowns: categoryBreakdowns,
      monthlyTrends: monthlyTrends,
      upcomingObligations: allUpcomingObligations,
      moduleTotals: moduleTotals,
    );
    final insights = generateInsights(baseSummary);
    return baseSummary.copyWith(insights: insights);
  }

  /// Generate smart financial insights based strictly on verified numbers
  static List<FinancialInsight> generateInsights(FinancialPeriodSummary summary) {
    final List<FinancialInsight> insights = [];

    // 1. Savings Rate Insight
    if (summary.totalIncome > 0) {
      if (summary.savingsRate >= 35) {
        insights.add(FinancialInsight(
          title: 'Outstanding Savings Rate',
          message:
              'You saved ${summary.savingsRate.toStringAsFixed(1)}% of your income this period. Your financial cushion is growing well.',
          icon: Icons.savings_rounded,
          color: Colors.green,
          type: 'positive',
        ));
      } else if (summary.savingsRate >= 15) {
        insights.add(FinancialInsight(
          title: 'Healthy Savings Rate',
          message:
              'You maintained a ${summary.savingsRate.toStringAsFixed(1)}% savings rate, meeting standard personal finance targets.',
          icon: Icons.check_circle_rounded,
          color: Colors.teal,
          type: 'positive',
        ));
      } else if (summary.savingsRate > 0) {
        insights.add(FinancialInsight(
          title: 'Low Savings Margin',
          message:
              'Your savings rate was ${summary.savingsRate.toStringAsFixed(1)}%. Review non-essential lifestyle expenses to build higher reserves.',
          icon: Icons.info_outline_rounded,
          color: Colors.amber.shade800,
          type: 'warning',
        ));
      } else {
        insights.add(FinancialInsight(
          title: 'Negative Cash Flow Alert',
          message:
              'Expenses exceeded total recorded income by ₹${(-summary.netSavings).toStringAsFixed(0)}. Check for emergency costs or delayed receivables.',
          icon: Icons.warning_rounded,
          color: Colors.red,
          type: 'warning',
        ));
      }
    }

    // 2. Dominant Category Insight
    if (summary.categoryBreakdowns.isNotEmpty) {
      final top = summary.categoryBreakdowns.first;
      insights.add(FinancialInsight(
        title: '${top.category} is Top Expense',
        message:
            '${top.category} constitutes ${top.percentage.toStringAsFixed(1)}% (₹${top.amount.toStringAsFixed(0)}) of all outgoing payments this period.',
        icon: top.icon,
        color: top.color,
        type: 'info',
      ));
    }

    // 3. Period-over-period trend insight
    if (summary.previousPeriodExpenses > 0) {
      if (summary.expenseChangePct < -5) {
        insights.add(FinancialInsight(
          title: 'Expenses Reduced',
          message:
              'Great discipline! Your total expenses decreased by ${(-summary.expenseChangePct).toStringAsFixed(1)}% compared to the previous period.',
          icon: Icons.trending_down_rounded,
          color: Colors.green,
          type: 'positive',
        ));
      } else if (summary.expenseChangePct > 10) {
        insights.add(FinancialInsight(
          title: 'Spending Increased',
          message:
              'Expenses are ${summary.expenseChangePct.toStringAsFixed(1)}% higher than the preceding period. Review discretionary categories.',
          icon: Icons.trending_up_rounded,
          color: Colors.orange.shade800,
          type: 'warning',
        ));
      }
    }

    // 4. Upcoming Obligations Insight
    final next30Days = summary.upcomingObligations
        .where((o) => o.daysRemaining >= 0 && o.daysRemaining <= 30)
        .toList();
    if (next30Days.isNotEmpty) {
      final total30 = next30Days.fold<double>(0, (sum, o) => sum + o.amount);
      insights.add(FinancialInsight(
        title: '${next30Days.length} Obligations in 30 Days',
        message:
            'You have ₹${total30.toStringAsFixed(0)} in bills, installments, or maintenance due in the next 30 days.',
        icon: Icons.alarm_on_rounded,
        color: Colors.indigo,
        type: 'info',
      ));
    }

    return insights;
  }
}
