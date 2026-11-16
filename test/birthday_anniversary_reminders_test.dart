import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_diary/core/calendar/services/calendar_service.dart';
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/core/utils/date_calculators.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/personal/models/personal_models.dart';
import 'package:magic_diary/features/reminders/models/reminder.dart';
import 'package:magic_diary/features/reminders/repositories/reminder_repository.dart';

class FakeUserNotifier extends UserNotifier {
  FakeUserNotifier(super.ref, UserProfile initialUser) {
    state = initialUser;
  }
}

class FakeAuthRepo extends AuthRepository {
  final UserProfile user;
  FakeAuthRepo(this.user);

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(user);
}

class FakeReminderRepository extends ReminderRepository {
  final List<Reminder> reminders;
  FakeReminderRepository({this.reminders = const []});

  @override
  Future<List<Reminder>> getReminders(String userId) async => reminders;
}

void main() {
  group('Birthday & Anniversary Recurrence Calculations', () {
    final fixedNow = DateTime(2026, 11, 15, 12, 0); // Reference: Nov 15, 2026

    test('calculates next occurrence for historical birthday that already passed this year', () {
      final dob = DateTime(1990, 5, 12, 9, 0);
      final next = DateCalculators.calculateNextOccurrence(dob, fixedNow);

      expect(next.year, equals(2027));
      expect(next.month, equals(5));
      expect(next.day, equals(12));
    });

    test('calculates next occurrence for upcoming anniversary in the same year', () {
      final anniv = DateTime(2018, 11, 20, 9, 0); // 5 days from Nov 15, 2026
      final next = DateCalculators.calculateNextOccurrence(anniv, fixedNow);

      expect(next.year, equals(2026));
      expect(next.month, equals(11));
      expect(next.day, equals(20));
    });

    test('calculates next occurrence when birthday is today', () {
      final dob = DateTime(1995, 11, 15, 9, 0);
      final next = DateCalculators.calculateNextOccurrence(dob, fixedNow);

      expect(next.year, equals(2026));
      expect(next.month, equals(11));
      expect(next.day, equals(15));
    });

    test('handles leap year Feb 29 birth date gracefully on non-leap year', () {
      final leapDob = DateTime(2000, 2, 29);
      final next = DateCalculators.calculateNextOccurrence(leapDob, fixedNow);

      // 2026 is non-leap, and Feb 2026 has already passed, so next is 2027 (non-leap) -> Feb 28
      expect(next.year, equals(2027));
      expect(next.month, equals(2));
      expect(next.day, equals(28));
    });

    test('retains future date if event is scheduled for next year', () {
      final futureWedding = DateTime(2027, 8, 20);
      final next = DateCalculators.calculateNextOccurrence(futureWedding, fixedNow);

      expect(next.year, equals(2027));
      expect(next.month, equals(8));
      expect(next.day, equals(20));
    });

    test('formats milestone labels correctly with ordinal suffixes', () {
      final dob = DateTime(1996, 5, 12);
      final target = DateTime(2026, 5, 12);
      final label = DateCalculators.formatMilestoneLabel(dob, 'Birthday', target);
      expect(label, equals('30th Birthday (Born 1996)'));

      final anniv = DateTime(2016, 11, 20);
      final targetAnniv = DateTime(2026, 11, 20);
      final annivLabel = DateCalculators.formatMilestoneLabel(anniv, 'Anniversary', targetAnniv);
      expect(annivLabel, equals('10th Anniversary (Est. 2016)'));
    });
  });

  group('Reminders Provider Synthesis & Stale Date Normalization', () {
    final mockUser = UserProfile(
      uid: 'user_test',
      email: 'user@magicdiary.app',
      displayName: 'Test User',
      username: 'testuser',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('proactively synthesizes reminders from specialEventsProvider only if due within next 30 days', () async {
      final now = DateTime.now();
      final dueIn5Days = now.add(const Duration(days: 5));
      final dueIn45Days = now.add(const Duration(days: 45));

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepo(mockUser)),
          userProfileProvider.overrideWith((ref) => FakeUserNotifier(ref, mockUser)),
          specialEventsProvider.overrideWith((ref) async => [
                SpecialEvent(
                  id: 'evt_near_bday',
                  title: "Mom's Birthday",
                  eventType: 'Birthday',
                  date: DateTime(1965, dueIn5Days.month, dueIn5Days.day),
                  giftIdeas: 'Saree and perfume',
                ),
                SpecialEvent(
                  id: 'evt_far_anniv',
                  title: 'Wedding Anniversary',
                  eventType: 'Anniversary',
                  date: DateTime(2015, dueIn45Days.month, dueIn45Days.day),
                ),
              ]),
          reminderRepositoryProvider.overrideWith((ref) => FakeReminderRepository()),
          propertiesProvider.overrideWith((ref) async => []),
        ],
      );

      final reminders = await container.read(remindersProvider.future);
      // Only the event due in 5 days should be synthesized into reminders; event in 45 days is excluded
      expect(reminders.length, equals(1));

      final momReminder = reminders.first;
      expect(momReminder.id, equals('reminder_evt_evt_near_bday'));
      expect(momReminder.title, equals("Birthday: Mom's Birthday"));
      expect(momReminder.module, equals('Personal'));
      expect(momReminder.description, contains('Birthday (Born 1965)'));
      expect(momReminder.description, contains('Saree and perfume'));
    });

    test('normalizes existing stored reminders and filters out those outside the next 30 days window', () async {
      final now = DateTime.now();
      final dueIn10Days = now.add(const Duration(days: 10));
      final dueIn90Days = now.add(const Duration(days: 90));

      final nearReminder = Reminder(
        id: 'reminder_evt_near',
        userId: 'user_test',
        title: "Dad's Birthday",
        description: 'Dad birthday celebration',
        module: 'Personal',
        status: 'pending',
        dueDate: DateTime(1955, dueIn10Days.month, dueIn10Days.day), // Historical birth year, due in 10 days
        createdAt: DateTime.now(),
      );

      final farReminder = Reminder(
        id: 'reminder_evt_far',
        userId: 'user_test',
        title: "Friend's Birthday",
        description: 'Friend birthday celebration',
        module: 'Personal',
        status: 'pending',
        dueDate: DateTime(1990, dueIn90Days.month, dueIn90Days.day), // Historical birth year, due in 90 days
        createdAt: DateTime.now(),
      );

      final regularBillReminder = Reminder(
        id: 'reminder_bill_1',
        userId: 'user_test',
        title: 'Electricity Bill',
        description: 'Monthly electricity bill',
        module: 'Bills',
        status: 'pending',
        dueDate: now.add(const Duration(days: 40)), // Regular reminder outside 30 days is retained
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepo(mockUser)),
          userProfileProvider.overrideWith((ref) => FakeUserNotifier(ref, mockUser)),
          specialEventsProvider.overrideWith((ref) async => []),
          reminderRepositoryProvider.overrideWith((ref) => FakeReminderRepository(
                reminders: [nearReminder, farReminder, regularBillReminder],
              )),
          propertiesProvider.overrideWith((ref) async => []),
        ],
      );

      final reminders = await container.read(remindersProvider.future);
      // nearReminder (10 days) + regularBillReminder (non-annual) should be present; farReminder (90 days) excluded
      expect(reminders.length, equals(2));

      final ids = reminders.map((r) => r.id).toSet();
      expect(ids.contains('reminder_evt_near'), isTrue);
      expect(ids.contains('reminder_bill_1'), isTrue);
      expect(ids.contains('reminder_evt_far'), isFalse);

      final normalizedNear = reminders.firstWhere((r) => r.id == 'reminder_evt_near');
      expect(normalizedNear.dueDate.year, greaterThanOrEqualTo(now.year));
      expect(normalizedNear.dueDate.month, equals(dueIn10Days.month));
      expect(normalizedNear.dueDate.day, equals(dueIn10Days.day));
    });
  });

  group('Calendar Service Aggregation for Birthdays and Anniversaries', () {
    test('aggregates special events with next upcoming occurrence and avoids duplicate with reminders', () {
      final specialEvent = SpecialEvent(
        id: 'ev_123',
        title: "Sister's Birthday",
        eventType: 'Birthday',
        date: DateTime(1998, 7, 24),
      );

      final events = CalendarService.aggregateEvents(
        reminders: const [],
        specialEvents: [specialEvent],
      );

      expect(events.length, equals(1));
      final calEvent = events.first;
      expect(calEvent.id, equals('event_ev_123'));
      expect(calEvent.title, equals("Sister's Birthday"));
      expect(calEvent.startTime.year, greaterThanOrEqualTo(DateTime.now().year));
      expect(calEvent.startTime.month, equals(7));
      expect(calEvent.startTime.day, equals(24));
      expect(calEvent.subtitle, contains('Birthday (Born 1998)'));
    });
  });
}
