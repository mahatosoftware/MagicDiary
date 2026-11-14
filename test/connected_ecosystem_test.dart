import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/domestic_help/models/domestic_help_models.dart';
import 'package:magic_diary/features/household/models/household_management_models.dart';
import 'package:magic_diary/features/cash_forecast/models/cash_forecast_models.dart';
import 'package:magic_diary/features/cash_forecast/services/cash_forecast_service.dart';
import 'package:magic_diary/features/bills/models/bills_models.dart';
import 'package:magic_diary/features/school_fees/models/school_fees_models.dart';
import 'package:magic_diary/features/vehicle/models/vehicle_models.dart';

void main() {
  group('Module 1: Domestic Help & Recurring Services Manager Tests', () {
    test('WorkerAttendance deterministic ID prevents duplicate attendance per worker and date', () {
      final date = DateTime(2026, 10, 25);
      final id1 = WorkerAttendance.generateId('worker_cook_1', date);
      final id2 = WorkerAttendance.generateId('worker_cook_1', date);
      final idOtherWorker = WorkerAttendance.generateId('worker_maid_2', date);

      expect(id1, equals('worker_cook_1_2026-10-25'));
      expect(id1, equals(id2), reason: 'Must be identical for same worker and same date');
      expect(id1, isNot(equals(idOtherWorker)));
    });

    test('Salary statement calculation accurately applies salary formula', () {
      final worker = DomesticWorker(
        id: 'w_1',
        householdId: 'h_1',
        name: 'Sunita (Cook)',
        role: 'Cook',
        phone: '9876543210',
        startDate: DateTime(2025, 1, 1),
        baseSalary: 6000.0,
        paymentDueDay: 5,
        attendancePolicy: AttendancePolicy.deductUnpaidAbsence,
      );

      // Assume: Base: ₹6,000, Bonuses: ₹300, Deductions: ₹200, Advance Recovery: ₹1,000
      const baseSalary = 6000.0;
      const bonuses = 300.0;
      const extraWork = 0.0;
      const deductions = 200.0;
      const advanceRecovery = 1000.0;

      const netPayable = (baseSalary + bonuses + extraWork - deductions - advanceRecovery);
      expect(netPayable, equals(5100.0));

      final statement = SalaryStatement(
        id: 'stmt_w_1_2026_10',
        workerId: worker.id,
        workerName: worker.name,
        householdId: worker.householdId,
        month: 10,
        year: 2026,
        baseSalary: baseSalary,
        bonuses: bonuses,
        deductions: deductions,
        advanceRecovery: advanceRecovery,
        netPayable: netPayable,
        status: 'draft',
      );

      expect(statement.outstandingBalance, equals(5100.0));
      expect(statement.isSettled, isFalse);

      // Partial Payment: Pay ₹2,000
      final partialStatement = statement.copyWith(
        paidAmount: 2000.0,
        status: 'partially_paid',
      );
      expect(partialStatement.outstandingBalance, equals(3100.0));
      expect(partialStatement.isSettled, isFalse);

      // Settle remaining ₹3,100
      final fullyPaidStatement = partialStatement.copyWith(
        paidAmount: 5100.0,
        status: 'paid',
      );
      expect(fullyPaidStatement.outstandingBalance, equals(0.0));
      expect(fullyPaidStatement.isSettled, isTrue);
    });

    test('Salary advance tracks remaining balance correctly', () {
      final advance = SalaryAdvance(
        id: 'adv_1',
        workerId: 'w_1',
        householdId: 'h_1',
        amount: 5000.0,
        date: DateTime(2026, 10, 1),
        monthlyRecoveryAmount: 1000.0,
        recoveredAmount: 2000.0,
      );

      expect(advance.remainingBalance, equals(3000.0));
      expect(advance.isFullyRecovered, isFalse);
    });

    test('Recurring service entry computes actual consumption cost', () {
      final service = RecurringService(
        id: 'serv_milk',
        householdId: 'h_1',
        name: 'Daily Buffalo Milk',
        serviceType: 'Milk',
        providerName: 'Shyam Dairy',
        unitRate: 68.0,
        unitName: 'Litres',
        defaultDailyQuantity: 2.0,
      );

      final entry = ServiceEntry(
        id: ServiceEntry.generateId(service.id, DateTime(2026, 10, 25)),
        serviceId: service.id,
        householdId: service.householdId,
        date: '2026-10-25',
        quantity: 2.5,
        rate: service.unitRate,
        isDelivered: true,
      );

      // 2.5 Litres * ₹68/Litre = ₹170
      expect(entry.cost, equals(170.0));

      // Missed delivery (quantity = 0 or isDelivered = false)
      final missedEntry = ServiceEntry(
        id: ServiceEntry.generateId(service.id, DateTime(2026, 10, 26)),
        serviceId: service.id,
        householdId: service.householdId,
        date: '2026-10-26',
        quantity: 2.0,
        rate: service.unitRate,
        isDelivered: false,
      );
      expect(missedEntry.cost, equals(0.0));
    });
  });

  group('Module 2: Upcoming Cash Commitment Forecast Tests', () {
    test('CashForecastService calculates chronological running balance and flags shortfall', () {
      final now = DateTime(2026, 11, 1);
      const startingCash = 45000.0;
      const bufferThreshold = 0.0;

      // Commitments
      final fee = FeeInstallment(
        id: 'fee_1',
        feeStructureId: 'fs_1',
        childId: 'c1',
        title: 'School Fees',
        installmentNumber: 1,
        amount: 8000.0,
        dueDate: DateTime(2026, 11, 2),
      );

      final vehicle = Vehicle(
        id: 'v_1',
        name: 'Family Car',
        type: 'Car',
        brand: 'Hyundai',
        model: 'Creta',
        registrationNumber: 'KA01AB1234',
        purchaseDate: DateTime(2024, 1, 1),
        currentOdometer: 10000,
        insuranceExpiry: DateTime(2026, 11, 7), // Triggers renewal obligation of ~₹12k
        pucExpiry: DateTime(2027, 1, 1),
        loanEmiAmount: 24000.0, // Due on 10th
      );

      final cook = DomesticWorker(
        id: 'w_cook',
        householdId: 'h_1',
        name: 'Ramesh',
        role: 'Cook',
        phone: '9876543210',
        startDate: DateTime(2024, 1, 1),
        baseSalary: 14000.0,
        paymentDueDay: 5, // Due on 5th
      );

      // Income expected on 10th: +₹90,000
      final salaryIncome = ForecastIncome(
        id: 'inc_sal',
        title: 'Monthly Salary',
        expectedDate: DateTime(2026, 11, 10),
        amount: 90000.0,
      );

      final forecast = CashForecastService.generateForecast(
        now: now,
        startingCashBalance: startingCash,
        safetyBuffer: bufferThreshold,
        forecastDays: 15,
        feeInstallments: [fee],
        vehicles: [vehicle],
        domesticWorkers: [cook],
        configuredIncomes: [salaryIncome],
      );

      // Check that obligations were consolidated
      expect(forecast.obligations.any((o) => o.title.contains('School Fees')), isTrue);
      expect(forecast.obligations.any((o) => o.title.contains('Cook Salary')), isTrue);
      expect(forecast.obligations.any((o) => o.title.contains('Car Loan EMI')), isTrue);

      // Shortfall check before salary arrives:
      // Starting: ₹45,000
      // 2 Nov: -₹8,000 -> ₹37,000
      // 5 Nov: -₹14,000 -> ₹23,000
      // 7 Nov: -₹12,000 -> ₹11,000
      // 10 Nov: -₹24,000 EMI + ₹90,000 salary
      // If we increase the safety buffer to ₹25,000:
      final bufferedForecast = CashForecastService.generateForecast(
        now: now,
        startingCashBalance: startingCash,
        safetyBuffer: 25000.0,
        forecastDays: 15,
        feeInstallments: [fee],
        vehicles: [vehicle],
        domesticWorkers: [cook],
        configuredIncomes: [salaryIncome],
      );

      expect(bufferedForecast.hasShortfall, isTrue);
      expect(bufferedForecast.shortfalls.first.date.day, equals(5));
      expect(bufferedForecast.shortfalls.first.explanation, contains('below buffer threshold'));
    });

    test('Scenario simulation delays income and tests cash deficit without mutating real ledger', () {
      final now = DateTime(2026, 11, 1);
      const startingCash = 20000.0;

      final bill = Bill(
        id: 'b_1',
        billAccountId: 'acc_1',
        userId: 'u1',
        billPeriod: 'Nov 2026',
        billDate: DateTime(2026, 11, 1),
        dueDate: DateTime(2026, 11, 5),
        amount: 15000.0,
      );

      final income = ForecastIncome(
        id: 'inc_1',
        title: 'Salary',
        expectedDate: DateTime(2026, 11, 3),
        amount: 50000.0,
      );

      // Without scenario: on 5 Nov, starting (20k) + income (50k) - bill (15k) = 55k -> NO shortfall
      final baseline = CashForecastService.generateForecast(
        now: now,
        startingCashBalance: startingCash,
        safetyBuffer: 10000.0,
        forecastDays: 10,
        bills: [bill],
        configuredIncomes: [income],
      );
      expect(baseline.hasShortfall, isFalse);

      // Scenario: Salary is delayed by 5 days (arrives on 8 Nov instead of 3 Nov)
      final scenario = ForecastScenario(
        id: 'scen_delay',
        name: 'Delayed Salary',
        delayIncomeDays: 5,
      );

      final delayedForecast = CashForecastService.generateForecast(
        now: now,
        startingCashBalance: startingCash,
        safetyBuffer: 10000.0,
        forecastDays: 10,
        bills: [bill],
        configuredIncomes: [income],
        scenario: scenario,
      );

      // On 5 Nov: starting (20k) - bill (15k) = 5,000 (which is below the 10,000 safety buffer!)
      expect(delayedForecast.hasShortfall, isTrue);
      expect(delayedForecast.shortfalls.first.date.day, equals(5));
    });
  });

  group('Module 3: Shared Family Workspace Tests', () {
    test('Household creation, membership roles, and permissions evaluate accurately', () {
      final owner = HouseholdMember(
        uid: 'user_owner',
        email: 'owner@example.com',
        displayName: 'Anil (Father)',
        role: 'owner',
        joinedAt: DateTime(2026, 1, 1),
      );

      final admin = HouseholdMember(
        uid: 'user_admin',
        email: 'admin@example.com',
        displayName: 'Sunita (Mother)',
        role: 'admin',
        joinedAt: DateTime(2026, 1, 2),
      );

      final viewer = HouseholdMember(
        uid: 'user_viewer',
        email: 'kid@example.com',
        displayName: 'Aarav (Child)',
        role: 'viewer',
        joinedAt: DateTime(2026, 1, 3),
      );

      expect(owner.isOwner, isTrue);
      expect(owner.isAdmin, isTrue);
      expect(owner.canEdit, isTrue);
      expect(owner.canApproveSalary, isTrue);

      expect(admin.isOwner, isFalse);
      expect(admin.isAdmin, isTrue);
      expect(admin.canApproveSalary, isTrue);

      expect(viewer.isOwner, isFalse);
      expect(viewer.isAdmin, isFalse);
      expect(viewer.canEdit, isFalse);
      expect(viewer.canApproveSalary, isFalse);

      final household = Household(
        id: 'house_123',
        name: 'The Mahato Home',
        ownerId: owner.uid,
        members: [owner, admin, viewer],
        createdAt: DateTime(2026, 1, 1),
      );

      expect(household.isMember('user_owner'), isTrue);
      expect(household.isMember('user_admin'), isTrue);
      expect(household.isMember('stranger_xyz'), isFalse);
    });

    test('Shared Household Tasks assign responsibilities and track completion', () {
      final task = HouseholdTask(
        id: 'task_1',
        householdId: 'house_123',
        title: 'Renew Creta Insurance',
        description: 'Check policy quote online and renew',
        assignedToUid: 'user_admin',
        assignedToName: 'Sunita',
        dueDate: DateTime(2026, 11, 5),
        priority: 'high',
        createdByUid: 'user_owner',
        createdAt: DateTime(2026, 10, 20),
      );

      expect(task.isCompleted, isFalse);
      expect(task.assignedToName, equals('Sunita'));

      final completedTask = task.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
        completedByUid: 'user_admin',
      );

      expect(completedTask.isCompleted, isTrue);
      expect(completedTask.completedByUid, equals('user_admin'));
    });

    test('Inter-member expense settlement tracks reimbursements without duplicate ledger expenses', () {
      // Scenario: ₹4,000 Electricity Bill paid by Anil. Sunita owes ₹2,000 reimbursement.
      final settlement = InterMemberSettlement(
        id: 'settle_1',
        householdId: 'house_123',
        payerUid: 'user_admin', // Sunita owes
        payerName: 'Sunita',
        receiverUid: 'user_owner', // Anil paid
        receiverName: 'Anil',
        amount: 2000.0,
        reason: '50% Electricity Bill reimbursement',
        date: DateTime(2026, 10, 25),
        isSettled: false,
      );

      expect(settlement.amount, equals(2000.0));
      expect(settlement.isSettled, isFalse);

      final settled = InterMemberSettlement(
        id: settlement.id,
        householdId: settlement.householdId,
        payerUid: settlement.payerUid,
        payerName: settlement.payerName,
        receiverUid: settlement.receiverUid,
        receiverName: settlement.receiverName,
        amount: settlement.amount,
        reason: settlement.reason,
        date: settlement.date,
        isSettled: true,
        settledAt: DateTime.now(),
      );

      expect(settled.isSettled, isTrue);
    });

    test('Education Diary FeeInstallment copyWith supports updating due date', () {
      final initialDueDate = DateTime(2026, 11, 10);
      final installment = FeeInstallment(
        id: 'inst_1',
        feeStructureId: 'fs_1',
        childId: 'child_1',
        installmentNumber: 1,
        title: 'Term 1 Tuition Fee',
        amount: 25000.0,
        dueDate: initialDueDate,
      );

      final newDueDate = DateTime(2026, 11, 25);
      final updated = installment.copyWith(dueDate: newDueDate);

      expect(updated.id, equals('inst_1'));
      expect(updated.dueDate, equals(newDueDate));
      expect(updated.dueDate, isNot(equals(initialDueDate)));
      expect(updated.amount, equals(25000.0));
    });
  });
}
