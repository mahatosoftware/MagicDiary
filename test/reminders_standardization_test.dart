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
  });
}
