import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/reminders/models/reminder.dart';

void main() {
  group('Standardized Reminders Across Diaries Tests', () {
    final now = DateTime(2026, 10, 24, 12, 0, 0);

    test('Reminder model serializes and deserializes with all standardized fields', () {
      final dueDate = DateTime(2026, 10, 25, 10, 0, 0);
      final reminder = Reminder(
        id: 'reminder_school_inst_1',
        userId: 'user_test',
        title: 'School Fee: Aarav - Term 2 Tuition',
        description: 'Fee installment #2 of ₹25000 due for Aarav.',
        module: 'SchoolFees',
        status: 'pending',
        dueDate: dueDate,
        relatedId: 'inst_1',
        amount: 25000.0,
        currencyCode: 'INR',
        actionRoute: '/school-fees',
        createdAt: now,
      );

      final map = reminder.toMap();
      expect(map['title'], contains('Aarav'));
      expect(map['amount'], equals(25000.0));
      expect(map['module'], equals('SchoolFees'));
      expect(map['actionRoute'], equals('/school-fees'));

      final fromMap = Reminder.fromMap(map, 'reminder_school_inst_1');
      expect(fromMap.id, equals('reminder_school_inst_1'));
      expect(fromMap.title, equals(reminder.title));
      expect(fromMap.amount, equals(25000.0));
      expect(fromMap.currencyCode, equals('INR'));
      expect(fromMap.actionRoute, equals('/school-fees'));
    });

    test('Reminder date categorization (Today, Overdue, Upcoming) evaluates accurately', () {
      final todayReminder = Reminder(
        id: 'rem_today',
        userId: 'u1',
        title: 'Electricity Bill Due',
        description: 'Pay today',
        module: 'Bills',
        status: 'pending',
        dueDate: DateTime(2026, 10, 24, 18, 30),
        createdAt: now,
      );

      final overdueReminder = Reminder(
        id: 'rem_overdue',
        userId: 'u1',
        title: 'Car Insurance Expired',
        description: 'Expired 2 days ago',
        module: 'Vehicle',
        status: 'pending',
        dueDate: DateTime(2026, 10, 22),
        createdAt: now,
      );

      final upcomingReminder = Reminder(
        id: 'rem_upcoming',
        userId: 'u1',
        title: 'Property Tax',
        description: 'Due next week',
        module: 'Property',
        status: 'pending',
        dueDate: DateTime(2026, 10, 30),
        createdAt: now,
      );

      final completedReminder = Reminder(
        id: 'rem_completed',
        userId: 'u1',
        title: 'Broadband Bill',
        description: 'Paid yesterday',
        module: 'Bills',
        status: 'completed',
        dueDate: DateTime(2026, 10, 24, 9, 0),
        completedAt: DateTime(2026, 10, 23),
        createdAt: now,
      );

      // Verify today
      expect(todayReminder.isToday(now), isTrue);
      expect(todayReminder.isOverdue(now), isFalse);
      expect(todayReminder.isUpcoming(now), isFalse);
      expect(todayReminder.daysUntil(now), equals(0));

      // Verify overdue
      expect(overdueReminder.isOverdue(now), isTrue);
      expect(overdueReminder.isToday(now), isFalse);
      expect(overdueReminder.isUpcoming(now), isFalse);
      expect(overdueReminder.daysUntil(now), equals(-2));

      // Verify upcoming
      expect(upcomingReminder.isUpcoming(now), isTrue);
      expect(upcomingReminder.isToday(now), isFalse);
      expect(upcomingReminder.isOverdue(now), isFalse);
      expect(upcomingReminder.daysUntil(now), equals(6));

      // Verify completed is not marked overdue or today
      expect(completedReminder.isCompleted, isTrue);
      expect(completedReminder.isOverdue(now), isFalse);
      expect(completedReminder.isToday(now), isFalse);
    });

    test('Reminder copyWith properly updates payment and completion metadata', () {
      final initial = Reminder(
        id: 'rem_hh_1',
        userId: 'u1',
        title: 'Piped Gas Bill',
        description: 'Mahanagar Gas bill',
        module: 'Household',
        status: 'pending',
        dueDate: DateTime(2026, 10, 28),
        amount: 850.0,
        createdAt: now,
      );

      final completed = initial.copyWith(
        status: 'completed',
        completedAt: now,
      );

      expect(completed.id, equals('rem_hh_1'));
      expect(completed.status, equals('completed'));
      expect(completed.completedAt, equals(now));
      expect(completed.amount, equals(850.0));
      expect(completed.module, equals('Household'));
    });

    test('Updating diary entries synchronizes reminder details and preserves immutable fields', () {
      final initialDueDate = DateTime(2026, 11, 15);
      final initialTaxReminder = Reminder(
        id: 'reminder_prop_p1_tax',
        userId: 'user_123',
        title: 'Property Tax: Sunrise Apartment',
        description: 'Annual property tax of ₹12000 for Flat 402, Sunrise.',
        module: 'Property',
        status: 'pending',
        dueDate: initialDueDate,
        relatedId: 'p1',
        amount: 12000.0,
        actionRoute: '/property',
        actionType: 'Pay',
        priority: 'medium',
        createdAt: now,
      );

      // User updates Property: changes title, address, tax amount, and tax due date
      final updatedDueDate = DateTime(2026, 12, 1);
      final updatedTaxReminder = initialTaxReminder.copyWith(
        title: 'Property Tax: Sunrise Villa 402',
        description: 'Annual property tax of ₹15000 for Villa 402, Sunrise.',
        amount: 15000.0,
        dueDate: updatedDueDate,
      );

      expect(updatedTaxReminder.id, equals('reminder_prop_p1_tax'));
      expect(updatedTaxReminder.userId, equals('user_123'));
      expect(updatedTaxReminder.createdAt, equals(now)); // Immutable createdAt preserved
      expect(updatedTaxReminder.title, equals('Property Tax: Sunrise Villa 402'));
      expect(updatedTaxReminder.amount, equals(15000.0));
      expect(updatedTaxReminder.dueDate, equals(updatedDueDate));
      expect(updatedTaxReminder.description, contains('₹15000'));
    });

    test('Updating vehicle service or insurance updates reminder metadata', () {
      final oldExpiry = DateTime(2026, 11, 20);
      final initialInsurance = Reminder(
        id: 'reminder_veh_v1_insurance',
        userId: 'u1',
        title: 'Vehicle Insurance: Honda City',
        description: 'Insurance policy for Honda City (KA01AB1234) expires on 20 Nov 2026.',
        module: 'Vehicle',
        status: 'pending',
        dueDate: oldExpiry,
        relatedId: 'v1',
        actionRoute: '/vehicle',
        actionType: 'Renew',
        priority: 'high',
        createdAt: now,
      );

      // Vehicle renewed for next year
      final newExpiry = DateTime(2027, 11, 20);
      final updatedInsurance = initialInsurance.copyWith(
        title: 'Vehicle Insurance: Honda City ZX',
        description: 'Insurance policy for Honda City ZX (KA01AB1234) expires on 20 Nov 2027.',
        dueDate: newExpiry,
        status: 'pending',
      );

      expect(updatedInsurance.id, equals('reminder_veh_v1_insurance'));
      expect(updatedInsurance.dueDate, equals(newExpiry));
      expect(updatedInsurance.title, contains('ZX'));
      expect(updatedInsurance.createdAt, equals(now));
    });

    test('Updating product warranty details synchronizes reminder properly', () {
      final initialWarranty = Reminder(
        id: 'reminder_prod_prod1_warranty',
        userId: 'u1',
        title: 'Warranty Ending: Microwave Oven',
        description: 'Manufacturer warranty for Samsung Microwave Oven expires soon.',
        module: 'Warranty',
        status: 'pending',
        dueDate: DateTime(2026, 12, 10),
        relatedId: 'prod1',
        actionRoute: '/warranty',
        actionType: 'Renew',
        createdAt: now,
      );

      // Extended warranty purchased: updated end date and title
      final extendedDate = DateTime(2028, 12, 10);
      final updatedWarranty = initialWarranty.copyWith(
        title: 'Warranty Ending: Samsung Convection Microwave',
        dueDate: extendedDate,
      );

      expect(updatedWarranty.dueDate, equals(extendedDate));
      expect(updatedWarranty.title, contains('Samsung Convection'));
      expect(updatedWarranty.createdAt, equals(now));
    });
  });
}
