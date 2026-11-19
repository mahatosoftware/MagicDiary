import 'package:flutter/material.dart';

enum OutflowHorizon {
  month, // Next Month (~30 days)
  quarter, // Next Quarter (~90 days / 3 months)
  year, // Next Year (~365 days / 12 months)
}

extension OutflowHorizonExtension on OutflowHorizon {
  String get label {
    switch (this) {
      case OutflowHorizon.month:
        return 'Next Month';
      case OutflowHorizon.quarter:
        return 'Next Quarter';
      case OutflowHorizon.year:
        return 'Next Year';
    }
  }

  String get subtitle {
    switch (this) {
      case OutflowHorizon.month:
        return 'Next 30 Days';
      case OutflowHorizon.quarter:
        return 'Next 3 Months';
      case OutflowHorizon.year:
        return 'Next 12 Months';
    }
  }

  int get days {
    switch (this) {
      case OutflowHorizon.month:
        return 30;
      case OutflowHorizon.quarter:
        return 90;
      case OutflowHorizon.year:
        return 365;
    }
  }

  int get monthCount {
    switch (this) {
      case OutflowHorizon.month:
        return 1;
      case OutflowHorizon.quarter:
        return 3;
      case OutflowHorizon.year:
        return 12;
    }
  }
}

class OutflowItem {
  final String id;
  final String title;
  final String category; // 'Bills & Utilities', 'Loans & EMIs', 'School & Education', 'Vehicle & Transport', 'Property & Housing', 'Domestic Help', 'Household & Living', 'Other'
  final double amount;
  final DateTime dueDate;
  final bool isRecurring;
  final bool isFixed; // Fixed (EMI, salary, school fee) vs Variable (utilities, groceries)
  final bool isEstimate;
  final bool isOverdue;
  final String? sourceRecordId;
  final String? route;

  const OutflowItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.dueDate,
    this.isRecurring = false,
    this.isFixed = true,
    this.isEstimate = false,
    this.isOverdue = false,
    this.sourceRecordId,
    this.route,
  });
}

class OutflowCategorySummary {
  final String category;
  final double totalAmount;
  final double percentage; // 0.0 to 1.0
  final int itemCount;
  final IconData icon;
  final Color color;

  const OutflowCategorySummary({
    required this.category,
    required this.totalAmount,
    required this.percentage,
    required this.itemCount,
    required this.icon,
    required this.color,
  });
}

class MonthlyOutflowPoint {
  final DateTime monthDate;
  final String monthLabel; // e.g. "Dec 2026"
  final double totalAmount;
  final double fixedAmount;
  final double variableAmount;
  final int obligationCount;
  final bool isPeakMonth;

  const MonthlyOutflowPoint({
    required this.monthDate,
    required this.monthLabel,
    required this.totalAmount,
    required this.fixedAmount,
    required this.variableAmount,
    required this.obligationCount,
    this.isPeakMonth = false,
  });
}

class OutflowHorizonReport {
  final OutflowHorizon horizon;
  final DateTime startDate;
  final DateTime endDate;
  final double totalOutflow;
  final double fixedOutflow;
  final double variableOutflow;
  final double averageMonthlyOutflow;
  final List<OutflowCategorySummary> categoryBreakdown;
  final List<MonthlyOutflowPoint> monthlyTrend;
  final List<OutflowItem> allItems;

  const OutflowHorizonReport({
    required this.horizon,
    required this.startDate,
    required this.endDate,
    required this.totalOutflow,
    required this.fixedOutflow,
    required this.variableOutflow,
    required this.averageMonthlyOutflow,
    required this.categoryBreakdown,
    required this.monthlyTrend,
    required this.allItems,
  });

  double get fixedPercentage => totalOutflow > 0 ? (fixedOutflow / totalOutflow) : 0.0;
  double get variablePercentage => totalOutflow > 0 ? (variableOutflow / totalOutflow) : 0.0;
}
