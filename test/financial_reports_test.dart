import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/reports/models/report_models.dart';
import 'package:magic_diary/features/reports/services/financial_analytics_service.dart';
import 'package:magic_diary/features/finance/models/finance_models.dart';
import 'package:magic_diary/features/household/models/household_models.dart';
import 'package:magic_diary/features/vehicle/models/vehicle_models.dart';
import 'package:magic_diary/features/bills/models/bills_models.dart';

void main() {
  group('FinancialAnalyticsService Date Range Calculation Tests', () {
    test('Monthly Date Range matches start and end of month', () {
      final ref = DateTime(2026, 10, 15);
      final range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.monthly,
        referenceDate: ref,
        yearType: YearType.financialYear,
      );

      expect(range.start.year, equals(2026));
      expect(range.start.month, equals(10));
      expect(range.start.day, equals(1));
      expect(range.end.month, equals(10));
      expect(range.end.day, equals(31));
      expect(range.label, equals('October 2026'));
    });

    test('Quarterly Date Range for Indian Financial Year (Apr - Mar)', () {
      // Q1: April - June
      final q1Range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.quarterly,
        referenceDate: DateTime(2026, 5, 10),
        yearType: YearType.financialYear,
      );
      expect(q1Range.start, equals(DateTime(2026, 4, 1)));
      expect(q1Range.end.month, equals(6));
      expect(q1Range.end.day, equals(30));
      expect(q1Range.label, contains('Q1'));

      // Q2: July - September
      final q2Range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.quarterly,
        referenceDate: DateTime(2026, 8, 20),
        yearType: YearType.financialYear,
      );
      expect(q2Range.start, equals(DateTime(2026, 7, 1)));
      expect(q2Range.end.month, equals(9));
      expect(q2Range.end.day, equals(30));
      expect(q2Range.label, contains('Q2'));

      // Q3: October - December
      final q3Range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.quarterly,
        referenceDate: DateTime(2026, 11, 5),
        yearType: YearType.financialYear,
      );
      expect(q3Range.start, equals(DateTime(2026, 10, 1)));
      expect(q3Range.end.month, equals(12));
      expect(q3Range.end.day, equals(31));
      expect(q3Range.label, contains('Q3'));

      // Q4: January - March
      final q4Range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.quarterly,
        referenceDate: DateTime(2027, 2, 14),
        yearType: YearType.financialYear,
      );
      expect(q4Range.start, equals(DateTime(2027, 1, 1)));
      expect(q4Range.end.month, equals(3));
      expect(q4Range.end.day, equals(31));
      expect(q4Range.label, contains('Q4'));
    });

    test('Quarterly Date Range for Calendar Year (Jan - Dec)', () {
      final q1Range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.quarterly,
        referenceDate: DateTime(2026, 2, 10),
        yearType: YearType.calendarYear,
      );
      expect(q1Range.start, equals(DateTime(2026, 1, 1)));
      expect(q1Range.end.month, equals(3));
      expect(q1Range.end.day, equals(31));
      expect(q1Range.label, equals('Q1 2026'));

      final q4Range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.quarterly,
        referenceDate: DateTime(2026, 11, 20),
        yearType: YearType.calendarYear,
      );
      expect(q4Range.start, equals(DateTime(2026, 10, 1)));
      expect(q4Range.end.month, equals(12));
      expect(q4Range.end.day, equals(31));
      expect(q4Range.label, equals('Q4 2026'));
    });

    test('Half-Yearly Date Range for Indian FY and Calendar Year', () {
      // Indian FY H1: Apr - Sep
      final h1FY = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.halfYearly,
        referenceDate: DateTime(2026, 6, 1),
        yearType: YearType.financialYear,
      );
      expect(h1FY.start, equals(DateTime(2026, 4, 1)));
      expect(h1FY.end.month, equals(9));
      expect(h1FY.end.day, equals(30));
      expect(h1FY.label, contains('H1'));

      // Indian FY H2: Oct - Mar
      final h2FY = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.halfYearly,
        referenceDate: DateTime(2026, 11, 1),
        yearType: YearType.financialYear,
      );
      expect(h2FY.start, equals(DateTime(2026, 10, 1)));
      expect(h2FY.end.year, equals(2027));
      expect(h2FY.end.month, equals(3));
      expect(h2FY.end.day, equals(31));
      expect(h2FY.label, contains('H2'));

      // Calendar Year H1: Jan - Jun
      final h1Cal = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.halfYearly,
        referenceDate: DateTime(2026, 3, 1),
        yearType: YearType.calendarYear,
      );
      expect(h1Cal.start, equals(DateTime(2026, 1, 1)));
      expect(h1Cal.end.month, equals(6));
      expect(h1Cal.end.day, equals(30));
    });

    test('Annual Date Range for Indian FY and Calendar Year', () {
      final fyRange = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.annual,
        referenceDate: DateTime(2026, 10, 1),
        yearType: YearType.financialYear,
      );
      expect(fyRange.start, equals(DateTime(2026, 4, 1)));
      expect(fyRange.end.year, equals(2027));
      expect(fyRange.end.month, equals(3));
      expect(fyRange.end.day, equals(31));

      final calRange = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.annual,
        referenceDate: DateTime(2026, 10, 1),
        yearType: YearType.calendarYear,
      );
      expect(calRange.start, equals(DateTime(2026, 1, 1)));
      expect(calRange.end.month, equals(12));
      expect(calRange.end.day, equals(31));
    });

    test('Custom Date Range respects user bounds', () {
      final start = DateTime(2026, 8, 15);
      final end = DateTime(2026, 9, 25);
      final range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.custom,
        referenceDate: DateTime(2026, 8, 15),
        customStart: start,
        customEnd: end,
      );
      expect(range.start, equals(start));
      expect(range.end.year, equals(2026));
      expect(range.end.month, equals(9));
      expect(range.end.day, equals(25));
    });

    test('Previous Period calculation for Monthly works across year boundaries', () {
      final janRange = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.monthly,
        referenceDate: DateTime(2026, 1, 15),
      );
      final prevRange = FinancialAnalyticsService.getPreviousPeriod(janRange);
      expect(prevRange.start.year, equals(2025));
      expect(prevRange.start.month, equals(12));
      expect(prevRange.end.month, equals(12));
      expect(prevRange.end.day, equals(31));
    });
  });

  group('Category Mapping Tests', () {
    test('Correctly maps keywords to top-level expense categories', () {
      expect(FinancialAnalyticsService.mapToTopCategory('Utilities', 'Electricity bill BESCOM'), equals('Household'));
      expect(FinancialAnalyticsService.mapToTopCategory('Grocery', 'Monthly BigBasket vegetables and milk'), equals('Household'));
      expect(FinancialAnalyticsService.mapToTopCategory('Education', 'DPS School Term 2 fees'), equals('Education'));
      expect(FinancialAnalyticsService.mapToTopCategory('Vehicle', 'Shell Petrol & diesel fill up'), equals('Vehicle'));
      expect(FinancialAnalyticsService.mapToTopCategory('Property', 'Municipal Corporation Property Tax'), equals('Property'));
      expect(FinancialAnalyticsService.mapToTopCategory('Finance', 'HDFC Home Loan EMI deduction'), equals('Financial'));
      expect(FinancialAnalyticsService.mapToTopCategory('Medical', 'Apollo pharmacy medicines and doctor visit'), equals('Healthcare'));
      expect(FinancialAnalyticsService.mapToTopCategory('Entertainment', 'Netflix monthly subscription'), equals('Lifestyle'));
      expect(FinancialAnalyticsService.mapToTopCategory('Misc', 'Some random unmapped expense'), equals('Other'));
    });
  });

  group('Unified Financial Aggregation Tests', () {
    test('Calculates Total Income, Total Expenses, Net Savings, and Savings Rate', () {
      final dateRange = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.monthly,
        referenceDate: DateTime(2026, 10, 15),
      );

      final financialTxns = [
        FinancialTransaction(
          id: 'ft_1',
          type: 'Income',
          category: 'Salary',
          amount: 150000.0,
          date: DateTime(2026, 10, 1),
          description: 'Monthly Tech Salary',
          paymentMethod: 'NetBanking',
        ),
        FinancialTransaction(
          id: 'ft_2',
          type: 'Expense',
          category: 'Shopping',
          amount: 12000.0,
          date: DateTime(2026, 10, 5),
          description: 'Lifestyle shopping',
          paymentMethod: 'Credit Card',
        ),
        // Internal transfer -> MUST NOT affect Income or Expense
        FinancialTransaction(
          id: 'ft_3',
          type: 'Transfer',
          category: 'Bank Transfer',
          amount: 25000.0,
          date: DateTime(2026, 10, 8),
          description: 'Transfer to Savings Account',
          paymentMethod: 'UPI',
        ),
        // Refund -> Reduces net expense
        FinancialTransaction(
          id: 'ft_4',
          type: 'Refund',
          category: 'Refund',
          amount: 2000.0,
          date: DateTime(2026, 10, 10),
          description: 'Amazon return refund',
          paymentMethod: 'Credit Card',
        ),
      ];

      final householdExpenses = [
        HouseholdExpense(
          id: 'hh_1',
          category: 'Electricity',
          providerName: 'BESCOM',
          amount: 3500.0,
          dueDate: DateTime(2026, 10, 12),
          status: 'paid',
          period: 'Oct 2026',
        ),
      ];

      final vehicleServices = [
        ServiceRecord(
          id: 'srv_1',
          vehicleId: 'veh_1',
          serviceDate: DateTime(2026, 10, 15),
          odometerReading: 12000,
          serviceType: 'Regular Service',
          workPerformed: 'Oil and filter change',
          totalCost: 6500.0,
          serviceCenter: 'Hyundai Service',
        ),
      ];

      final summary = FinancialAnalyticsService.generateReport(
        dateRange: dateRange,
        financialTransactions: financialTxns,
        householdExpenses: householdExpenses,
        children: const [],
        feeInstallments: const [],
        vehicles: const [],
        vehicleServices: vehicleServices,
        properties: const [],
        propertyMaintenances: const [],
        billAccounts: const [],
        bills: const [],
        reminders: const [],
      );

      // Expected Income: 150,000
      expect(summary.totalIncome, equals(150000.0));

      // Expected Expenses: 12,000 (Shopping) - 2,000 (Refund) + 3,500 (Electricity) + 6,500 (Service) = 20,000
      expect(summary.totalExpenses, equals(20000.0));

      // Net Savings: 150,000 - 20,000 = 130,000
      expect(summary.netSavings, equals(130000.0));

      // Savings Rate: (130,000 / 150,000) * 100 = 86.666...%
      expect(summary.savingsRate, closeTo(86.67, 0.05));

      // Check category breakdowns
      expect(summary.categoryBreakdowns.isNotEmpty, isTrue);
      final categories = summary.categoryBreakdowns.map((c) => c.category).toList();
      expect(categories, contains('Lifestyle'));
      expect(categories, contains('Household'));
      expect(categories, contains('Vehicle'));

      // Insights should contain a positive savings insight
      expect(summary.insights.isNotEmpty, isTrue);
      final hasSavingsInsight = summary.insights.any((i) => i.title.contains('Savings Rate'));
      expect(hasSavingsInsight, isTrue);
    });

    test('Zero income edge case produces 0.0% savings rate without division by zero', () {
      final dateRange = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.monthly,
        referenceDate: DateTime(2026, 10, 15),
      );

      final householdExpenses = [
        HouseholdExpense(
          id: 'hh_1',
          category: 'Grocery',
          providerName: 'BigBasket',
          amount: 5000.0,
          dueDate: DateTime(2026, 10, 5),
          status: 'paid',
          period: 'Oct 2026',
        ),
      ];

      final summary = FinancialAnalyticsService.generateReport(
        dateRange: dateRange,
        financialTransactions: const [],
        householdExpenses: householdExpenses,
        children: const [],
        feeInstallments: const [],
        vehicles: const [],
        vehicleServices: vehicleServicesMock,
        properties: const [],
        propertyMaintenances: const [],
        billAccounts: const [],
        bills: const [],
        reminders: const [],
      );

      expect(summary.totalIncome, equals(0.0));
      expect(summary.totalExpenses, equals(5000.0));
      expect(summary.netSavings, equals(-5000.0));
      expect(summary.savingsRate, equals(0.0));
      expect(summary.isDeficit, isTrue);
    });

    test('Calendar day normalization accurately captures boundary transactions despite UTC offsets', () {
      final range = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.monthly,
        referenceDate: DateTime(2026, 10, 15),
      );

      // First day of month at start of day
      final firstDayTx = DateTime.parse('2026-10-01T00:00:00.000Z');
      // Last day of month at late hour
      final lastDayTx = DateTime.parse('2026-10-31T23:30:00.000Z');
      // Previous month last day
      final prevMonthTx = DateTime.parse('2026-09-30T23:59:59.000Z');

      expect(range.contains(firstDayTx), isTrue);
      expect(range.contains(lastDayTx), isTrue);
      expect(range.contains(prevMonthTx), isFalse);
    });

    test('Accurately integrates Bills module into expenses and upcoming obligations', () {
      final dateRange = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.monthly,
        referenceDate: DateTime(2026, 10, 15),
      );

      final billAccounts = [
        BillAccount(
          id: 'acc_1',
          userId: 'u1',
          name: 'Airtel Broadband',
          category: 'Telecom',
          providerName: 'Airtel',
          accountNumber: 'ACC-1234',
          billingCycle: 'Monthly',
          dueDayOfMonth: 15,
          defaultAmount: 1499.0,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      final bills = [
        // Paid bill -> added to expenses
        Bill(
          id: 'b_1',
          billAccountId: 'acc_1',
          userId: 'u1',
          billPeriod: 'Oct 2026',
          billDate: DateTime(2026, 10, 1),
          dueDate: DateTime(2026, 10, 10),
          amount: 1499.0,
          status: 'paid',
        ),
        // Unpaid bill -> added to upcoming obligations
        Bill(
          id: 'b_2',
          billAccountId: 'acc_1',
          userId: 'u1',
          billPeriod: 'Nov 2026',
          billDate: DateTime(2026, 10, 25),
          dueDate: DateTime(2026, 11, 10),
          amount: 1499.0,
          status: 'unpaid',
        ),
      ];

      final summary = FinancialAnalyticsService.generateReport(
        dateRange: dateRange,
        financialTransactions: const [],
        householdExpenses: const [],
        children: const [],
        feeInstallments: const [],
        vehicles: const [],
        vehicleServices: const [],
        properties: const [],
        propertyMaintenances: const [],
        billAccounts: billAccounts,
        bills: bills,
        reminders: const [],
      );

      // Paid bill included in total expenses
      expect(summary.totalExpenses, equals(1499.0));
      expect(summary.transactions.any((t) => t.sourceModule == 'Bills'), isTrue);

      // Unpaid bill included in upcoming obligations
      expect(summary.upcomingObligations.any((o) => o.sourceModule == 'Bills'), isTrue);
    });

    test('Source Module Filter isolates data to selected module', () {
      final dateRange = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.monthly,
        referenceDate: DateTime(2026, 10, 15),
      );

      final financeTx = [
        FinancialTransaction(
          id: 'ft_1',
          type: 'Expense',
          category: 'Shopping',
          amount: 5000.0,
          date: DateTime(2026, 10, 5),
          description: 'Shopping',
          paymentMethod: 'UPI',
        ),
      ];

      final household = [
        HouseholdExpense(
          id: 'hh_1',
          category: 'Electricity',
          providerName: 'BESCOM',
          amount: 2500.0,
          dueDate: DateTime(2026, 10, 10),
          status: 'paid',
          period: 'Oct 2026',
        ),
      ];

      // Report with 'Finance' filter only
      final financeSummary = FinancialAnalyticsService.generateReport(
        dateRange: dateRange,
        financialTransactions: financeTx,
        householdExpenses: household,
        children: const [],
        feeInstallments: const [],
        vehicles: const [],
        vehicleServices: const [],
        properties: const [],
        propertyMaintenances: const [],
        billAccounts: const [],
        bills: const [],
        reminders: const [],
        sourceModuleFilter: 'Finance',
      );

      expect(financeSummary.totalExpenses, equals(5000.0));
      expect(financeSummary.transactions.length, equals(1));
      expect(financeSummary.transactions.first.sourceModule, equals('Finance'));
    });

    test('Calculates Opening and Closing Balance accurately', () {
      final dateRange = FinancialAnalyticsService.getDateRange(
        periodType: ReportPeriodType.monthly,
        referenceDate: DateTime(2026, 10, 15),
      );

      // Prior month transactions (September)
      final financeTx = [
        FinancialTransaction(
          id: 'ft_sep_inc',
          type: 'Income',
          category: 'Salary',
          amount: 100000.0,
          date: DateTime(2026, 9, 1),
          description: 'Sep Salary',
          paymentMethod: 'NetBanking',
        ),
        FinancialTransaction(
          id: 'ft_sep_exp',
          type: 'Expense',
          category: 'Shopping',
          amount: 40000.0,
          date: DateTime(2026, 9, 15),
          description: 'Sep Expenses',
          paymentMethod: 'UPI',
        ),
        // Current month transactions (October)
        FinancialTransaction(
          id: 'ft_oct_inc',
          type: 'Income',
          category: 'Salary',
          amount: 100000.0,
          date: DateTime(2026, 10, 1),
          description: 'Oct Salary',
          paymentMethod: 'NetBanking',
        ),
        FinancialTransaction(
          id: 'ft_oct_exp',
          type: 'Expense',
          category: 'Groceries',
          amount: 30000.0,
          date: DateTime(2026, 10, 10),
          description: 'Oct Expenses',
          paymentMethod: 'UPI',
        ),
      ];

      final summary = FinancialAnalyticsService.generateReport(
        dateRange: dateRange,
        financialTransactions: financeTx,
        householdExpenses: const [],
        children: const [],
        feeInstallments: const [],
        vehicles: const [],
        vehicleServices: const [],
        properties: const [],
        propertyMaintenances: const [],
        billAccounts: const [],
        bills: const [],
        reminders: const [],
      );

      // Opening balance = 100,000 - 40,000 = 60,000
      expect(summary.openingBalance, equals(60000.0));
      // Net savings for October = 100,000 - 30,000 = 70,000
      expect(summary.netSavings, equals(70000.0));
      // Closing balance = 60,000 + 70,000 = 130,000
      expect(summary.closingBalance, equals(130000.0));
    });
  });
}

const List<ServiceRecord> vehicleServicesMock = [];
