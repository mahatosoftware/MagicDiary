import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/services/global_search_service.dart';
import 'package:magic_diary/core/services/magic_assistant_service.dart';
import 'package:magic_diary/features/reminders/models/reminder.dart';
import 'package:magic_diary/features/school_fees/models/school_fees_models.dart';
import 'package:magic_diary/features/vehicle/models/vehicle_models.dart';
import 'package:magic_diary/features/warranty/models/product.dart';
import 'package:magic_diary/features/personal/models/personal_models.dart';

void main() {
  group('Module A & K: Reminder Action Types & Date Categorization', () {
    test('Reminder properly sets actionType and priority', () {
      final rem = Reminder(
        id: 'rem_1',
        userId: 'u1',
        title: 'Electricity Bill',
        description: 'Pay electricity bill',
        module: 'Bills',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        actionType: 'Pay',
        priority: 'high',
        createdAt: DateTime.now(),
      );

      expect(rem.actionType, equals('Pay'));
      expect(rem.priority, equals('high'));
      expect(rem.isCompleted, isFalse);

      final map = rem.toMap();
      expect(map['actionType'], equals('Pay'));
      expect(map['priority'], equals('high'));

      final fromMap = Reminder.fromMap(map, 'rem_1');
      expect(fromMap.actionType, equals('Pay'));
      expect(fromMap.priority, equals('high'));
    });
  });

  group('Module D: School Fees Concessions, Refunds & Net Settlement', () {
    test('FeeInstallment net balance and settlement rules evaluate accurately', () {
      final fee = FeeInstallment(
        id: 'inst_1',
        feeStructureId: 'fs_1',
        childId: 'c1',
        title: 'Term 1 Tuition',
        installmentNumber: 1,
        amount: 20000.0,
        paidAmount: 15000.0,
        concessionAmount: 3000.0,
        refundAmount: 0.0,
        dueDate: DateTime(2026, 11, 1),
        status: 'partial',
      );

      // Billed: 20,000; Concession: 3,000 -> Net Payable: 17,000
      expect(fee.billedAmount, equals(20000.0));
      expect(fee.netPayable, equals(17000.0));
      // Paid: 15,000 -> Outstanding Balance: 2,000
      expect(fee.outstandingBalance, equals(2000.0));
      expect(fee.isSettled, isFalse);

      // Settle remaining 2,000
      final settledFee = fee.copyWith(paidAmount: 17000.0);
      expect(settledFee.outstandingBalance, equals(0.0));
      expect(settledFee.isSettled, isTrue);

      // With refund: 1,000 refund issued after payment
      final refundedFee = settledFee.copyWith(refundAmount: 1000.0);
      expect(refundedFee.outstandingBalance, equals(1000.0));
      expect(refundedFee.isSettled, isFalse);
    });
  });

  group('Module F: Vehicle Dual Service Reminders (Odometer & Date)', () {
    test('Vehicle odometer service milestone triggers when within threshold', () {
      final vehicle = Vehicle(
        id: 'veh_1',
        name: 'Family SUV',
        type: 'Car',
        brand: 'Hyundai',
        model: 'Creta',
        registrationNumber: 'KA01AB1234',
        purchaseDate: DateTime(2024, 1, 1),
        currentOdometer: 9600,
        lastServiceOdometer: 0,
        serviceIntervalKm: 10000,
        insuranceExpiry: DateTime(2027, 1, 1),
        pucExpiry: DateTime(2027, 1, 1),
      );

      // Next service at 10,000; current is 9,600 -> 400 km remaining (within 500 km threshold)
      expect(vehicle.nextServiceOdometer, equals(10000));
      expect(vehicle.kmUntilNextService, equals(400));
      expect(vehicle.isOdometerServiceDue, isTrue);

      final freshVehicle = vehicle.copyWith(currentOdometer: 8000);
      expect(freshVehicle.kmUntilNextService, equals(2000));
      expect(freshVehicle.isOdometerServiceDue, isFalse);
    });
  });

  group('Module B: Habits & Streaks', () {
    test('Habit completion and streak tracking evaluate correctly', () {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final habit = Habit(
        id: 'h_1',
        title: 'Morning Yoga',
        category: 'Mindfulness',
        streakCount: 5,
        bestStreak: 10,
        completedDates: [todayStr],
        createdAt: DateTime(2026, 1, 1),
      );

      expect(habit.isCompletedOn(today), isTrue);
      expect(habit.isCompletedOn(today.subtract(const Duration(days: 1))), isFalse);
    });
  });

  group('Global Search Engine Tests', () {
    test('GlobalSearchService searches across multiple diary modules seamlessly', () {
      final List<JournalEntry> journals = [
        JournalEntry(
          id: 'j_1',
          title: 'Trip to Manali',
          content: 'Snowfall in Solang valley with family',
          date: DateTime(2026, 10, 10),
          mood: 'Happy',
          person: 'Rahul',
          place: 'Manali',
          tags: ['vacation', 'family'],
        ),
      ];

      final List<Product> products = [
        Product(
          id: 'p_1',
          userId: 'u1',
          name: 'MacBook Pro',
          category: 'Electronics',
          brand: 'Apple',
          model: 'M3 Pro',
          serialNumber: 'C02XYZ123',
          purchaseDate: DateTime(2026, 5, 1),
          price: 199900.0,
          sellerInfo: 'Apple Store',
          hasWarranty: true,
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        ),
      ];

      final List<Vehicle> vehicles = [
        Vehicle(
          id: 'v_1',
          name: 'City Car',
          type: 'Car',
          brand: 'Honda',
          model: 'City ZX',
          registrationNumber: 'DL01XY9999',
          purchaseDate: DateTime(2025, 1, 1),
          currentOdometer: 15000,
          insuranceExpiry: DateTime(2027, 1, 1),
          pucExpiry: DateTime(2027, 1, 1),
        ),
      ];

      // 1. Search for 'Manali'
      final search1 = GlobalSearchService.search(
        query: 'Manali',
        journals: journals,
        products: products,
        vehicles: vehicles,
      );
      expect(search1.length, equals(1));
      expect(search1.first.module, equals('Personal'));
      expect(search1.first.title, equals('Trip to Manali'));

      // 2. Search for 'MacBook'
      final search2 = GlobalSearchService.search(
        query: 'macbook',
        journals: journals,
        products: products,
        vehicles: vehicles,
      );
      expect(search2.length, equals(1));
      expect(search2.first.module, equals('Warranty'));
      expect(search2.first.title, contains('MacBook Pro'));

      // 3. Search for vehicle registration
      final search3 = GlobalSearchService.search(
        query: 'DL01XY',
        journals: journals,
        products: products,
        vehicles: vehicles,
      );
      expect(search3.length, equals(1));
      expect(search3.first.module, equals('Vehicle'));
    });
  });

  group('Module O: Magic Assistant Proactive Insights Engine', () {
    test('Detects overdue tasks, closing return windows, and odometer milestones', () {
      final now = DateTime(2026, 10, 25);

      final overdueReminder = Reminder(
        id: 'r_overdue',
        userId: 'u1',
        title: 'Water Bill',
        description: 'Pay water bill',
        module: 'Bills',
        dueDate: DateTime(2026, 10, 20),
        status: 'pending',
        createdAt: DateTime(2026, 10, 1),
      );

      final expiringProduct = Product(
        id: 'p_return',
        userId: 'u1',
        name: 'Wireless Headphones',
        category: 'Electronics',
        brand: 'Sony',
        purchaseDate: DateTime(2026, 10, 20),
        price: 8990.0,
        sellerInfo: 'Amazon',
        hasWarranty: true,
        returnDeadline: DateTime(2026, 10, 27), // 2 days left
        createdAt: DateTime(2026, 10, 20),
        updatedAt: DateTime(2026, 10, 20),
      );

      final dueVehicle = Vehicle(
        id: 'v_odo',
        name: 'Scooter',
        type: 'Scooter',
        brand: 'Honda',
        model: 'Activa',
        registrationNumber: 'KA02CD5678',
        purchaseDate: DateTime(2024, 1, 1),
        currentOdometer: 4900,
        lastServiceOdometer: 0,
        serviceIntervalKm: 5000, // 100 km left -> isOdometerServiceDue == true
        insuranceExpiry: DateTime(2027, 1, 1),
        pucExpiry: DateTime(2027, 1, 1),
      );

      final insights = MagicAssistantService.generateInsights(
        now: now,
        reminders: [overdueReminder],
        products: [expiringProduct],
        vehicles: [dueVehicle],
      );

      expect(insights.any((i) => i.id == 'insight_overdue'), isTrue);
      expect(insights.any((i) => i.id == 'insight_return_p_return'), isTrue);
      expect(insights.any((i) => i.id == 'insight_odo_v_odo'), isTrue);
    });
  });
}
