import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/financial/models/financial_transaction.dart';
import 'package:magic_diary/core/financial/models/financial_obligation.dart';
import 'package:magic_diary/core/financial/models/recurring_schedule.dart';
import 'package:magic_diary/core/financial/models/financial_category.dart';
import 'package:magic_diary/core/financial/services/financial_reporting_service.dart';
import 'package:magic_diary/features/reports/models/report_models.dart';

void main() {
  group('Canonical FinancialTransaction Model Tests', () {
    test('Correctly converts major units (Rupees) to minor units (Paise)', () {
      final tx = FinancialTransaction.fromMajorUnits(
        id: 'tx_1',
        userId: 'user_1',
        type: TransactionType.expense,
        amountMajor: 1250.75,
        categoryId: 'household_electricity',
        sourceModule: 'household',
        sourceRecordId: 'h_101',
        description: 'Electricity Bill',
        transactionDate: DateTime(2026, 4, 15),
      );

      expect(tx.amountMinorUnits, 125075);
      expect(tx.amount, 1250.75);
      expect(tx.amountMajorUnits, 1250.75);
      expect(tx.currencyCode, 'INR');
      expect(tx.status, TransactionStatus.completed);
    });

    test('Generates deterministic ID for idempotent writes', () {
      final id1 = FinancialTransaction.generateDeterministicId('School_Fees', 'INST-9988');
      final id2 = FinancialTransaction.generateDeterministicId('school_fees', 'INST-9988');

      expect(id1, 'txn_school_fees_INST-9988');
      expect(id1, id2);
    });

    test('Serializes to map and deserializes accurately with legacy support', () {
      final original = FinancialTransaction.fromMajorUnits(
        id: 'tx_legacy',
        userId: 'u_100',
        type: TransactionType.income,
        amountMajor: 75000.0,
        categoryId: 'income_salary',
        sourceModule: 'finance',
        description: 'Monthly Salary',
        transactionDate: DateTime(2026, 4, 30),
      );

      final map = original.toMap();
      final restored = FinancialTransaction.fromMap(map, 'tx_legacy');

      expect(restored.id, 'tx_legacy');
      expect(restored.amountMinorUnits, 7500000);
      expect(restored.amount, 75000.0);
      expect(restored.type, TransactionType.income);
      expect(restored.categoryId, 'income_salary');

      // Test parsing from old legacy map containing only double 'amount' and string 'type'
      final legacyMap = {
        'id': 'legacy_1',
        'type': 'Income',
        'category': 'Salary',
        'amount': 50000.0,
        'date': '2026-04-01T10:00:00.000',
        'description': 'April Salary',
        'paymentMethod': 'Bank Transfer',
      };

      final parsedLegacy = FinancialTransaction.fromMap(legacyMap);
      expect(parsedLegacy.amountMinorUnits, 5000000);
      expect(parsedLegacy.amount, 50000.0);
      expect(parsedLegacy.type, TransactionType.income);
    });
  });

  group('FinancialObligation Model Tests', () {
    test('Calculates remaining amount, daysRemaining, and overdue status correctly', () {
      final futureDue = DateTime.now().add(const Duration(days: 10));
      final pastDue = DateTime.now().subtract(const Duration(days: 5));

      final obligationFuture = FinancialObligation.fromMajorUnits(
        id: 'ob_1',
        userId: 'u_1',
        title: 'Tuition Fee Q1',
        categoryId: 'education_school_fees',
        sourceModule: 'school_fees',
        expectedAmountMajor: 25000.0,
        paidAmountMajor: 10000.0,
        dueDate: futureDue,
      );

      expect(obligationFuture.expectedAmount, 25000.0);
      expect(obligationFuture.paidAmount, 10000.0);
      expect(obligationFuture.remainingAmount, 15000.0);
      expect(obligationFuture.isOverdue, isFalse);

      final obligationOverdue = FinancialObligation.fromMajorUnits(
        id: 'ob_2',
        userId: 'u_1',
        title: 'Gas Cylinder',
        categoryId: 'household_gas',
        sourceModule: 'household',
        expectedAmountMajor: 950.0,
        dueDate: pastDue,
        status: ObligationStatus.pending,
      );

      expect(obligationOverdue.isOverdue, isTrue);
    });
  });

  group('RecurringSchedule Model Tests', () {
    test('Parses various frequency representations accurately', () {
      expect(ScheduleFrequency.fromString('monthly'), ScheduleFrequency.monthly);
      expect(ScheduleFrequency.fromString('Monthly'), ScheduleFrequency.monthly);
      expect(ScheduleFrequency.fromString('Quarterly'), ScheduleFrequency.quarterly);
      expect(ScheduleFrequency.fromString('semi_annual'), ScheduleFrequency.semiAnnual);
      expect(ScheduleFrequency.fromString('Annual'), ScheduleFrequency.annual);
      expect(ScheduleFrequency.fromString('Bi-Weekly'), ScheduleFrequency.biWeekly);
    });
  });

  group('CategoryRegistry Tests', () {
    test('Correctly maps legacy category names and descriptions to stable IDs', () {
      expect(CategoryRegistry.mapLegacyToCategoryId('Salary', 'Monthly Pay'), 'income_salary');
      expect(CategoryRegistry.mapLegacyToCategoryId('Electricity', 'Bescom Bill'), 'household_electricity');
      expect(CategoryRegistry.mapLegacyToCategoryId('School Fees', 'DPS Term 1'), 'education_school_fees');
      expect(CategoryRegistry.mapLegacyToCategoryId('Vehicle Servicing', 'Honda Service Center'), 'vehicle_servicing');
      expect(CategoryRegistry.mapLegacyToCategoryId('Property Tax', 'BBMP Tax 2026'), 'property_tax');
      expect(CategoryRegistry.mapLegacyToCategoryId('SIP', 'HDFC Top 100'), 'financial_investment_transfer');
    });

    test('Identifies account transfers as balance movements excluded from standard expenses', () {
      final sipCat = CategoryRegistry.getCategory('financial_investment_transfer');
      final savingsCat = CategoryRegistry.getCategory('financial_savings_transfer');
      final groceryCat = CategoryRegistry.getCategory('household_groceries');

      expect(sipCat.isTransferOrBalanceMovement, isTrue);
      expect(savingsCat.isTransferOrBalanceMovement, isTrue);
      expect(groceryCat.isTransferOrBalanceMovement, isFalse);
    });
  });

  group('FinancialReportingService Double-Entry Accounting Tests', () {
    final testDateRange = ReportDateRange(
      start: DateTime(2026, 4, 1),
      end: DateTime(2026, 4, 30, 23, 59, 59),
      label: 'April 2026',
      periodType: ReportPeriodType.monthly,
      yearType: YearType.financialYear,
    );

    test('Computes Net Income, Net Expenses, Net Cash Flow, and Savings Rate accurately', () {
      final transactions = [
        // 1. Eligible Income: ₹1,00,000
        FinancialTransaction.fromMajorUnits(
          id: 't_inc_1',
          userId: 'u_1',
          type: TransactionType.income,
          amountMajor: 100000.0,
          categoryId: 'income_salary',
          sourceModule: 'finance',
          description: 'Salary',
          transactionDate: DateTime(2026, 4, 5),
        ),

        // 2. Eligible Expenses: Groceries ₹12,000, Electricity ₹3,000, School Fee ₹25,000
        FinancialTransaction.fromMajorUnits(
          id: 't_exp_1',
          userId: 'u_1',
          type: TransactionType.expense,
          amountMajor: 12000.0,
          categoryId: 'household_groceries',
          sourceModule: 'household',
          description: 'Supermarket Groceries',
          transactionDate: DateTime(2026, 4, 10),
        ),
        FinancialTransaction.fromMajorUnits(
          id: 't_exp_2',
          userId: 'u_1',
          type: TransactionType.expense,
          amountMajor: 3000.0,
          categoryId: 'household_electricity',
          sourceModule: 'household',
          description: 'Power Bill',
          transactionDate: DateTime(2026, 4, 12),
        ),
        FinancialTransaction.fromMajorUnits(
          id: 't_exp_3',
          userId: 'u_1',
          type: TransactionType.expense,
          amountMajor: 25000.0,
          categoryId: 'education_school_fees',
          sourceModule: 'school_fees',
          description: 'School Fees',
          transactionDate: DateTime(2026, 4, 15),
        ),

        // 3. Refund: ₹2,000 (Grocery return)
        FinancialTransaction.fromMajorUnits(
          id: 't_ref_1',
          userId: 'u_1',
          type: TransactionType.refund,
          amountMajor: 2000.0,
          categoryId: 'household_groceries',
          sourceModule: 'household',
          description: 'Grocery Refund',
          transactionDate: DateTime(2026, 4, 18),
        ),

        // 4. Transfer between own accounts: ₹15,000 (Mutual Fund SIP transfer)
        // MUST NOT be counted as income or expense!
        FinancialTransaction.fromMajorUnits(
          id: 't_trf_1',
          userId: 'u_1',
          type: TransactionType.transfer,
          amountMajor: 15000.0,
          categoryId: 'financial_investment_transfer',
          sourceModule: 'finance',
          description: 'SIP Auto-Debit',
          transactionDate: DateTime(2026, 4, 20),
        ),

        // 5. Cancelled transaction: ₹5,000 (MUST be excluded)
        FinancialTransaction.fromMajorUnits(
          id: 't_can_1',
          userId: 'u_1',
          type: TransactionType.expense,
          status: TransactionStatus.cancelled,
          amountMajor: 5000.0,
          categoryId: 'household_repairs',
          sourceModule: 'household',
          description: 'Cancelled Plumber Work',
          transactionDate: DateTime(2026, 4, 22),
        ),

        // 6. Soft-deleted transaction: ₹4,000 (MUST be excluded)
        FinancialTransaction.fromMajorUnits(
          id: 't_del_1',
          userId: 'u_1',
          type: TransactionType.expense,
          isDeleted: true,
          amountMajor: 4000.0,
          categoryId: 'lifestyle_shopping',
          sourceModule: 'finance',
          description: 'Deleted Purchase',
          transactionDate: DateTime(2026, 4, 24),
        ),
      ];

      final summary = FinancialReportingService.generateSummary(
        dateRange: testDateRange,
        allUserTransactions: transactions,
        allUserObligations: const [],
      );

      // Total Income = ₹1,00,000
      expect(summary.totalIncome, 100000.0);

      // Gross Expenses = 12000 + 3000 + 25000 = ₹40,000
      // Refund Offset = ₹2,000
      // Net Expenses = ₹38,000
      expect(summary.totalExpenses, 38000.0);

      // Net Savings = 100000 - 38000 = ₹62,000
      expect(summary.netSavings, 62000.0);

      // Savings Rate = (62000 / 100000) * 100 = 62.0%
      expect(summary.savingsRate, 62.0);

      // Check category breakdowns
      // Household Net = (12000 + 3000) - 2000 = ₹13,000
      // Education Net = ₹25,000
      final householdBreakdown = summary.categoryBreakdowns.firstWhere((b) => b.category == 'Household');
      final educationBreakdown = summary.categoryBreakdowns.firstWhere((b) => b.category == 'Education');

      expect(householdBreakdown.amount, 13000.0);
      expect(educationBreakdown.amount, 25000.0);
    });

    test('Excludes obligations from actual transaction cash flows', () {
      final transactions = [
        FinancialTransaction.fromMajorUnits(
          id: 't_1',
          userId: 'u_1',
          type: TransactionType.income,
          amountMajor: 50000.0,
          categoryId: 'income_salary',
          sourceModule: 'finance',
          description: 'Salary',
          transactionDate: DateTime(2026, 4, 1),
        ),
      ];

      final obligations = [
        FinancialObligation.fromMajorUnits(
          id: 'ob_1',
          userId: 'u_1',
          title: 'Upcoming Property Tax',
          categoryId: 'property_tax',
          sourceModule: 'property',
          expectedAmountMajor: 18000.0,
          dueDate: DateTime(2026, 4, 25),
        ),
      ];

      final summary = FinancialReportingService.generateSummary(
        dateRange: testDateRange,
        allUserTransactions: transactions,
        allUserObligations: obligations,
      );

      // Obligation of ₹18,000 must NOT be in totalExpenses!
      expect(summary.totalExpenses, 0.0);
      expect(summary.netSavings, 50000.0);
      expect(summary.upcomingObligations.length, 1);
      expect(summary.upcomingObligations.first.amount, 18000.0);
    });
  });
}
