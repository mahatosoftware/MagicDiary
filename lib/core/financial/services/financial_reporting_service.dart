import 'package:intl/intl.dart';
import '../models/financial_transaction.dart';
import '../models/financial_obligation.dart';
import '../models/financial_category.dart';
import '../../../../features/reports/models/report_models.dart';

/// Centralized, audited financial reporting service.
/// Enforces consistent double-entry accounting rules, refund offsetting,
/// and transfer exclusion across all reports in Magic Diary.
class FinancialReportingService {
  /// Check whether a transaction is an eligible completed actual movement
  static bool isEligibleActual(FinancialTransaction tx) {
    if (tx.isDeleted) return false;
    if (tx.status != TransactionStatus.completed) return false;
    return true;
  }

  /// Check whether a transaction is a transfer between user's own accounts
  static bool isAccountTransfer(FinancialTransaction tx) {
    if (tx.type == TransactionType.transfer) return true;
    final category = CategoryRegistry.getCategory(tx.categoryId);
    return category.isTransferOrBalanceMovement;
  }

  /// Generate the canonical financial summary for any given date range
  static FinancialPeriodSummary generateSummary({
    required ReportDateRange dateRange,
    required List<FinancialTransaction> allUserTransactions,
    required List<FinancialObligation> allUserObligations,
    String sourceModuleFilter = 'All', // 'All' or specific sourceModule
    String? categoryFilter,
  }) {
    // 1. Separate period transactions from all transactions
    final eligibleAll = allUserTransactions.where(isEligibleActual).toList();

    // Opening balance calculation: sum of all cash movements strictly BEFORE dateRange.start
    double openingBalance = 0.0;
    for (final tx in eligibleAll) {
      if (tx.transactionDate.isBefore(dateRange.start)) {
        if (!isAccountTransfer(tx)) {
          if (tx.type == TransactionType.income) {
            openingBalance += tx.amount;
          } else if (tx.type == TransactionType.expense) {
            openingBalance -= tx.amount;
          } else if (tx.type == TransactionType.refund) {
            openingBalance += tx.amount; // Refund replenishes balance
          }
        }
      }
    }

    // Filter transactions within the selected period
    var periodTransactions = eligibleAll.where((tx) => dateRange.contains(tx.transactionDate)).toList();

    if (sourceModuleFilter != 'All') {
      periodTransactions = periodTransactions
          .where((tx) => tx.sourceModule.toLowerCase() == sourceModuleFilter.toLowerCase())
          .toList();
    }

    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      periodTransactions = periodTransactions.where((tx) {
        final cat = CategoryRegistry.getCategory(tx.categoryId);
        return cat.id == categoryFilter || cat.parentCategory == categoryFilter || tx.categoryId == categoryFilter;
      }).toList();
    }

    // 2. Compute Financial Totals according to standard rules
    double grossIncome = 0.0;
    double grossExpenses = 0.0;
    double totalRefunds = 0.0;

    final Map<String, double> categoryExpenseMap = {};
    final Map<String, int> categoryCountMap = {};
    final Map<String, double> moduleTotals = {
      'Finance': 0.0,
      'Household': 0.0,
      'Bills': 0.0,
      'SchoolFees': 0.0,
      'Vehicle': 0.0,
      'Property': 0.0,
    };

    final List<UnifiedTransaction> unifiedList = [];

    for (final tx in periodTransactions) {
      final isTransfer = isAccountTransfer(tx);
      final cat = CategoryRegistry.getCategory(tx.categoryId);
      final parentCat = cat.parentCategory;

      // Track module contribution
      final modKey = _normalizeModuleKey(tx.sourceModule);
      if (moduleTotals.containsKey(modKey)) {
        moduleTotals[modKey] = moduleTotals[modKey]! + tx.amount;
      }

      // Convert to UnifiedTransaction for drill-down views
      TransactionFlow flow;
      if (isTransfer) {
        flow = TransactionFlow.transfer;
      } else if (tx.type == TransactionType.income) {
        flow = TransactionFlow.income;
      } else if (tx.type == TransactionType.refund) {
        flow = TransactionFlow.refund;
      } else {
        flow = TransactionFlow.expense;
      }

      unifiedList.add(UnifiedTransaction(
        id: tx.id,
        title: tx.description.isNotEmpty ? tx.description : cat.displayName,
        flow: flow,
        category: parentCat,
        subcategory: cat.displayName,
        amount: tx.amount,
        date: tx.transactionDate,
        paymentMethod: tx.paymentMethod ?? 'UPI',
        sourceModule: modKey,
        linkedRecordId: tx.sourceRecordId,
        notes: tx.notes,
        status: tx.status.name,
      ));

      if (isTransfer) {
        continue; // Account transfers do not affect net income or expenses
      }

      switch (tx.type) {
        case TransactionType.income:
          grossIncome += tx.amount;
          break;

        case TransactionType.expense:
          grossExpenses += tx.amount;
          categoryExpenseMap[parentCat] = (categoryExpenseMap[parentCat] ?? 0.0) + tx.amount;
          categoryCountMap[parentCat] = (categoryCountMap[parentCat] ?? 0) + 1;
          break;

        case TransactionType.refund:
        case TransactionType.reimbursement:
          totalRefunds += tx.amount;
          // Offset against expense category if present
          if (categoryExpenseMap.containsKey(parentCat)) {
            final cur = categoryExpenseMap[parentCat]!;
            categoryExpenseMap[parentCat] = (cur - tx.amount).clamp(0.0, double.infinity);
          }
          break;

        case TransactionType.transfer:
        case TransactionType.adjustment:
          break;
      }
    }

    // Net accounting
    final double netExpenses = (grossExpenses - totalRefunds).clamp(0.0, double.infinity);
    final double netSavings = grossIncome - netExpenses;
    final double savingsRate = grossIncome > 0 ? ((netSavings / grossIncome) * 100).clamp(-100.0, 100.0) : 0.0;
    final double closingBalance = openingBalance + netSavings;

    // 3. Category Breakdowns
    final List<CategoryBreakdown> breakdowns = [];
    final totalSpentForPercentages = netExpenses > 0 ? netExpenses : grossExpenses;

    categoryExpenseMap.forEach((catName, spent) {
      if (spent > 0) {
        final pct = totalSpentForPercentages > 0 ? (spent / totalSpentForPercentages) * 100 : 0.0;
        final sampleCat = CategoryRegistry.getByParent(catName).firstOrNull ?? CategoryRegistry.getCategory('other_miscellaneous');
        breakdowns.add(CategoryBreakdown(
          category: catName,
          amount: spent,
          percentage: pct,
          count: categoryCountMap[catName] ?? 1,
          color: sampleCat.color,
          icon: sampleCat.icon,
        ));
      }
    });
    breakdowns.sort((a, b) => b.amount.compareTo(a.amount));

    // 4. Monthly Trend Points
    final List<MonthlyTrendPoint> monthlyTrends = _computeMonthlyTrends(periodTransactions, dateRange);

    // 5. Previous Period Comparison
    final prevRange = getPreviousPeriod(dateRange);
    double prevIncome = 0.0;
    double prevExpenses = 0.0;

    for (final tx in eligibleAll) {
      if (prevRange.contains(tx.transactionDate) && !isAccountTransfer(tx)) {
        if (tx.type == TransactionType.income) {
          prevIncome += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          prevExpenses += tx.amount;
        } else if (tx.type == TransactionType.refund) {
          prevExpenses = (prevExpenses - tx.amount).clamp(0.0, double.infinity);
        }
      }
    }

    final double expenseChangePct = prevExpenses > 0
        ? ((netExpenses - prevExpenses) / prevExpenses) * 100
        : 0.0;
    final double incomeChangePct = prevIncome > 0
        ? ((grossIncome - prevIncome) / prevIncome) * 100
        : 0.0;

    // 6. Upcoming Obligations Integration
    final List<UpcomingObligation> obligationsList = [];
    final now = DateTime.now();

    for (final ob in allUserObligations) {
      if (ob.status != ObligationStatus.paid && ob.status != ObligationStatus.cancelled) {
        obligationsList.add(UpcomingObligation(
          id: ob.id,
          title: ob.title,
          category: CategoryRegistry.getCategory(ob.categoryId).parentCategory,
          amount: ob.remainingAmount,
          dueDate: ob.dueDate,
          status: ob.dueDate.isBefore(now) ? 'overdue' : 'pending',
          sourceModule: _normalizeModuleKey(ob.sourceModule),
          linkedItem: ob.notes,
        ));
      }
    }
    obligationsList.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return FinancialPeriodSummary(
      dateRange: dateRange,
      totalIncome: grossIncome,
      totalExpenses: netExpenses,
      netSavings: netSavings,
      savingsRate: savingsRate,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      categoryBreakdowns: breakdowns,
      monthlyTrends: monthlyTrends,
      upcomingObligations: obligationsList,
      transactions: unifiedList,
      previousPeriodIncome: prevIncome,
      previousPeriodExpenses: prevExpenses,
      expenseChangePct: expenseChangePct,
      incomeChangePct: incomeChangePct,
      moduleTotals: moduleTotals,
    );
  }

  /// Get the immediately previous period for period-over-period comparison
  static ReportDateRange getPreviousPeriod(ReportDateRange current) {
    switch (current.periodType) {
      case ReportPeriodType.monthly:
        final prevMonthDate = DateTime(current.start.year, current.start.month - 1, 1);
        final nextMonth = prevMonthDate.month == 12
            ? DateTime(prevMonthDate.year + 1, 1, 1)
            : DateTime(prevMonthDate.year, prevMonthDate.month + 1, 1);
        final end = nextMonth.subtract(const Duration(milliseconds: 1));
        return ReportDateRange(
          start: prevMonthDate,
          end: end,
          label: DateFormat('MMMM yyyy').format(prevMonthDate),
          periodType: current.periodType,
          yearType: current.yearType,
        );

      case ReportPeriodType.quarterly:
      case ReportPeriodType.halfYearly:
      case ReportPeriodType.annual:
      case ReportPeriodType.custom:
        final duration = current.end.difference(current.start);
        final prevEnd = current.start.subtract(const Duration(milliseconds: 1));
        final prevStart = prevEnd.subtract(duration);
        return ReportDateRange(
          start: prevStart,
          end: prevEnd,
          label: 'Previous Period',
          periodType: current.periodType,
          yearType: current.yearType,
        );

      case ReportPeriodType.allTime:
        return current;
    }
  }

  static List<MonthlyTrendPoint> _computeMonthlyTrends(
    List<FinancialTransaction> transactions,
    ReportDateRange dateRange,
  ) {
    final Map<String, MonthlyTrendPoint> monthMap = {};

    DateTime cursor = DateTime(dateRange.start.year, dateRange.start.month, 1);
    final endMonth = DateTime(dateRange.end.year, dateRange.end.month, 1);

    while (!cursor.isAfter(endMonth)) {
      final key = DateFormat('yyyy-MM').format(cursor);
      final label = DateFormat('MMM yyyy').format(cursor);
      monthMap[key] = MonthlyTrendPoint(
        monthLabel: label,
        monthDate: cursor,
        income: 0.0,
        expense: 0.0,
        savings: 0.0,
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    for (final tx in transactions) {
      if (isAccountTransfer(tx)) continue;
      final key = DateFormat('yyyy-MM').format(tx.transactionDate);
      if (monthMap.containsKey(key)) {
        final existing = monthMap[key]!;
        double inc = existing.income;
        double exp = existing.expense;

        if (tx.type == TransactionType.income) {
          inc += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          exp += tx.amount;
        } else if (tx.type == TransactionType.refund) {
          exp = (exp - tx.amount).clamp(0.0, double.infinity);
        }

        monthMap[key] = MonthlyTrendPoint(
          monthLabel: existing.monthLabel,
          monthDate: existing.monthDate,
          income: inc,
          expense: exp,
          savings: inc - exp,
        );
      }
    }

    return monthMap.values.toList();
  }

  static String _normalizeModuleKey(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('finance')) return 'Finance';
    if (lower.contains('household')) return 'Household';
    if (lower.contains('bill')) return 'Bills';
    if (lower.contains('school') || lower.contains('education') || lower.contains('fee')) return 'SchoolFees';
    if (lower.contains('vehicle')) return 'Vehicle';
    if (lower.contains('property')) return 'Property';
    return 'Finance';
  }
}
