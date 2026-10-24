import 'package:flutter/material.dart';

enum ReportPeriodType {
  monthly,
  quarterly,
  halfYearly,
  annual,
  allTime,
  custom,
}

enum YearType {
  financialYear, // Indian FY: 01 Apr – 31 Mar
  calendarYear,  // 01 Jan – 31 Dec
}

enum TransactionFlow {
  income,
  expense,
  transfer,
  refund,
}

class ReportDateRange {
  final DateTime start;
  final DateTime end;
  final String label;
  final ReportPeriodType periodType;
  final YearType yearType;

  const ReportDateRange({
    required this.start,
    required this.end,
    required this.label,
    required this.periodType,
    this.yearType = YearType.financialYear,
  });

  /// Robust calendar-day boundary check immune to UTC/Local timezone and millisecond variations
  bool contains(DateTime date) {
    if (periodType == ReportPeriodType.allTime) return true;
    final d = date.toLocal();
    final s = start.toLocal();
    final e = end.toLocal();

    final dateDay = DateTime(d.year, d.month, d.day);
    final startDay = DateTime(s.year, s.month, s.day);
    final endDay = DateTime(e.year, e.month, e.day);

    return (dateDay.isAtSameMomentAs(startDay) || dateDay.isAfter(startDay)) &&
           (dateDay.isAtSameMomentAs(endDay) || dateDay.isBefore(endDay));
  }
}

class UnifiedTransaction {
  final String id;
  final String title;
  final TransactionFlow flow;
  final String category;
  final String subcategory;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String sourceModule; // 'Finance', 'Household', 'SchoolFees', 'Vehicle', 'Property', 'Bills'
  final String? linkedRecordId;
  final String? notes;
  final String status; // 'completed', 'pending', 'paid', 'unpaid'

  const UnifiedTransaction({
    required this.id,
    required this.title,
    required this.flow,
    required this.category,
    required this.subcategory,
    required this.amount,
    required this.date,
    this.paymentMethod = 'UPI',
    required this.sourceModule,
    this.linkedRecordId,
    this.notes,
    this.status = 'completed',
  });
}

class UpcomingObligation {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime dueDate;
  final String status;
  final String sourceModule;
  final String? linkedItem;

  const UpcomingObligation({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.sourceModule,
    this.linkedItem,
  });

  int get daysRemaining => dueDate.difference(DateTime.now()).inDays;
}

class CategoryBreakdown {
  final String category;
  final double amount;
  final double percentage;
  final int count;
  final Color color;
  final IconData icon;

  const CategoryBreakdown({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.count,
    required this.color,
    required this.icon,
  });
}

class MonthlyTrendPoint {
  final String monthLabel; // e.g. "Apr 2026", "May 2026"
  final DateTime monthDate;
  final double income;
  final double expense;
  final double savings;

  const MonthlyTrendPoint({
    required this.monthLabel,
    required this.monthDate,
    required this.income,
    required this.expense,
    required this.savings,
  });
}

class FinancialPeriodSummary {
  final ReportDateRange dateRange;
  final double totalIncome;
  final double totalExpenses;
  final double netSavings;
  final double savingsRate; // Percentage
  final double openingBalance;
  final double closingBalance;
  final double previousPeriodExpenses;
  final double previousPeriodIncome;
  final double expenseChangePct;
  final double incomeChangePct;
  final List<UnifiedTransaction> transactions;
  final List<CategoryBreakdown> categoryBreakdowns;
  final List<MonthlyTrendPoint> monthlyTrends;
  final List<UpcomingObligation> upcomingObligations;
  final Map<String, double> moduleTotals; // Expense sum per source module
  final List<FinancialInsight> insights;

  const FinancialPeriodSummary({
    required this.dateRange,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netSavings,
    required this.savingsRate,
    this.openingBalance = 0.0,
    this.closingBalance = 0.0,
    required this.previousPeriodExpenses,
    required this.previousPeriodIncome,
    required this.expenseChangePct,
    required this.incomeChangePct,
    required this.transactions,
    required this.categoryBreakdowns,
    required this.monthlyTrends,
    required this.upcomingObligations,
    this.moduleTotals = const {},
    this.insights = const [],
  });

  bool get isDeficit => netSavings < 0;

  FinancialPeriodSummary copyWith({
    ReportDateRange? dateRange,
    double? totalIncome,
    double? totalExpenses,
    double? netSavings,
    double? savingsRate,
    double? openingBalance,
    double? closingBalance,
    double? previousPeriodExpenses,
    double? previousPeriodIncome,
    double? expenseChangePct,
    double? incomeChangePct,
    List<UnifiedTransaction>? transactions,
    List<CategoryBreakdown>? categoryBreakdowns,
    List<MonthlyTrendPoint>? monthlyTrends,
    List<UpcomingObligation>? upcomingObligations,
    Map<String, double>? moduleTotals,
    List<FinancialInsight>? insights,
  }) {
    return FinancialPeriodSummary(
      dateRange: dateRange ?? this.dateRange,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      netSavings: netSavings ?? this.netSavings,
      savingsRate: savingsRate ?? this.savingsRate,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      previousPeriodExpenses: previousPeriodExpenses ?? this.previousPeriodExpenses,
      previousPeriodIncome: previousPeriodIncome ?? this.previousPeriodIncome,
      expenseChangePct: expenseChangePct ?? this.expenseChangePct,
      incomeChangePct: incomeChangePct ?? this.incomeChangePct,
      transactions: transactions ?? this.transactions,
      categoryBreakdowns: categoryBreakdowns ?? this.categoryBreakdowns,
      monthlyTrends: monthlyTrends ?? this.monthlyTrends,
      upcomingObligations: upcomingObligations ?? this.upcomingObligations,
      moduleTotals: moduleTotals ?? this.moduleTotals,
      insights: insights ?? this.insights,
    );
  }
}

class FinancialInsight {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String type; // 'positive', 'warning', 'info', 'neutral'

  const FinancialInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.type,
  });
}
