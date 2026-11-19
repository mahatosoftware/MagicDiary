import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/bills/models/bills_models.dart';
import 'package:magic_diary/features/cash_forecast/models/outflow_forecast_models.dart';
import 'package:magic_diary/features/cash_forecast/services/outflow_forecast_service.dart';
import 'package:magic_diary/features/domestic_help/models/domestic_help_models.dart';
import 'package:magic_diary/features/school_fees/models/school_fees_models.dart';
import 'package:magic_diary/features/vehicle/models/vehicle_models.dart';

void main() {
  group('OutflowForecastService Multi-Horizon Projection Tests', () {
    final now = DateTime(2026, 11, 20);

    test('Next Month horizon projects 1 month of recurring obligations', () {
      final vehicles = [
        Vehicle(
          id: 'veh_1',
          name: 'Creta',
          type: 'Car',
          brand: 'Hyundai',
          model: 'Creta',
          registrationNumber: 'KA01AB1234',
          purchaseDate: DateTime(2024, 1, 1),
          currentOdometer: 25000,
          insuranceExpiry: DateTime(2027, 5, 10),
          pucExpiry: DateTime(2027, 2, 1),
          loanEmiAmount: 18500.0,
        ),
      ];

      final workers = [
        DomesticWorker(
          id: 'w_1',
          householdId: 'h_1',
          name: 'Sunita',
          role: 'Cook',
          phone: '9876543210',
          baseSalary: 8000.0,
          paymentDueDay: 5,
          startDate: DateTime(2025, 1, 1),
        ),
      ];

      final report = OutflowForecastService.generateReport(
        horizon: OutflowHorizon.month,
        now: now,
        vehicles: vehicles,
        domesticWorkers: workers,
      );

      expect(report.horizon, OutflowHorizon.month);
      expect(report.monthlyTrend.length, 1);
      // Vehicle EMI (18,500) + Cook Salary (8,000) = 26,500
      expect(report.totalOutflow, 26500.0);
      expect(report.fixedOutflow, 26500.0);
      expect(report.allItems.length, 2);
    });

    test('Next Quarter horizon projects 3 months of recurring obligations and includes term fees', () {
      final vehicles = [
        Vehicle(
          id: 'veh_1',
          name: 'Creta',
          type: 'Car',
          brand: 'Hyundai',
          model: 'Creta',
          registrationNumber: 'KA01AB1234',
          purchaseDate: DateTime(2024, 1, 1),
          currentOdometer: 25000,
          insuranceExpiry: DateTime(2027, 5, 10),
          pucExpiry: DateTime(2027, 2, 1),
          loanEmiAmount: 18500.0,
        ),
      ];

      final feeInstallments = [
        FeeInstallment(
          id: 'fee_term_2',
          feeStructureId: 'struct_1',
          childId: 'child_1',
          installmentNumber: 2,
          title: 'Term 2 Tuition Fee',
          dueDate: DateTime(2027, 1, 15),
          amount: 35000.0,
        ),
      ];

      final report = OutflowForecastService.generateReport(
        horizon: OutflowHorizon.quarter,
        now: now,
        vehicles: vehicles,
        feeInstallments: feeInstallments,
      );

      expect(report.horizon, OutflowHorizon.quarter);
      expect(report.monthlyTrend.length, 3);
      // 3 months of vehicle EMI = 18,500 * 3 = 55,500 + School Fee 35,000 + PUC Renewal (Feb 1) 150 = 90,650
      expect(report.totalOutflow, 90650.0);
      expect(report.categoryBreakdown.any((c) => c.category == OutflowForecastService.catSchool), isTrue);
      expect(report.categoryBreakdown.any((c) => c.category == OutflowForecastService.catLoans), isTrue);
    });

    test('Next Year horizon projects 12 months with peak month detection', () {
      final vehicles = [
        Vehicle(
          id: 'veh_1',
          name: 'Creta',
          type: 'Car',
          brand: 'Hyundai',
          model: 'Creta',
          registrationNumber: 'KA01AB1234',
          purchaseDate: DateTime(2024, 1, 1),
          currentOdometer: 25000,
          insuranceExpiry: DateTime(2027, 5, 10), // in 6 months
          pucExpiry: DateTime(2027, 2, 1),
          loanEmiAmount: 10000.0,
        ),
      ];

      final report = OutflowForecastService.generateReport(
        horizon: OutflowHorizon.year,
        now: now,
        vehicles: vehicles,
      );

      expect(report.horizon, OutflowHorizon.year);
      expect(report.monthlyTrend.length, 12);
      // 12 months EMI = 120,000 + Insurance 12,000 + PUC 150 = 132,150
      expect(report.totalOutflow, 132150.0);
      expect(report.monthlyTrend.any((m) => m.isPeakMonth), isTrue);
    });

    test('BillAccounts with monthly and annual cycles are projected accurately', () {
      final accounts = [
        BillAccount(
          id: 'acc_net',
          userId: 'u1',
          name: 'Airtel Broadband',
          category: 'Utility',
          providerName: 'Airtel',
          accountNumber: '12345',
          billingCycle: 'Monthly',
          dueDayOfMonth: 15,
          defaultAmount: 1200.0,
          createdAt: now,
        ),
        BillAccount(
          id: 'acc_prime',
          userId: 'u1',
          name: 'Amazon Prime',
          category: 'Subscription',
          providerName: 'Amazon',
          accountNumber: '999',
          billingCycle: 'Yearly',
          dueDayOfMonth: 1,
          defaultAmount: 1499.0,
          renewalDate: DateTime(2027, 3, 1),
          createdAt: now,
        ),
      ];

      final report = OutflowForecastService.generateReport(
        horizon: OutflowHorizon.quarter,
        now: now,
        billAccounts: accounts,
      );

      expect(report.allItems.isNotEmpty, isTrue);
      final broadbandItems = report.allItems.where((i) => i.title.contains('Airtel Broadband'));
      expect(broadbandItems.isNotEmpty, isTrue);
    });
  });
}
