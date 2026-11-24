import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_diary/core/calendar/services/calendar_service.dart';
import 'package:magic_diary/core/constants/event_types.dart';
import 'package:magic_diary/core/diary_engine/models/diary_record.dart';
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/core/security/diary_access_control_service.dart';
import 'package:magic_diary/core/utils/date_calculators.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/personal/models/personal_models.dart';
import 'package:magic_diary/features/reminders/models/reminder.dart';
import 'package:magic_diary/features/reminders/repositories/reminder_repository.dart';
import 'package:magic_diary/features/shared_diaries/models/shared_diary_models.dart';

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

    test('suppresses milestone year and birth/marriage year when isShared is true', () {
      final dob = DateTime(1996, 5, 12);
      final target = DateTime(2026, 5, 12);
      final sharedBdayLabel = DateCalculators.formatMilestoneLabel(
        dob,
        'Birthday',
        target,
        isShared: true,
      );
      expect(sharedBdayLabel, equals('Birthday'));
      expect(sharedBdayLabel.contains('1996'), isFalse);
      expect(sharedBdayLabel.contains('30'), isFalse);

      final anniv = DateTime(2016, 11, 20);
      final targetAnniv = DateTime(2026, 11, 20);
      final sharedAnnivLabel = DateCalculators.formatMilestoneLabel(
        anniv,
        'Anniversary',
        targetAnniv,
        isShared: true,
      );
      expect(sharedAnnivLabel, equals('Anniversary'));
      expect(sharedAnnivLabel.contains('2016'), isFalse);
      expect(sharedAnnivLabel.contains('10'), isFalse);
    });

    test('formatDateAndMonth extracts only date and month from string or DateTime', () {
      final formatted1 = DateCalculators.formatDateAndMonth('1990-10-24T00:00:00.000');
      expect(formatted1, equals('24 October'));

      final formatted2 = DateCalculators.formatDateAndMonth(DateTime(1985, 3, 15), pattern: 'd MMM');
      expect(formatted2, equals('15 Mar'));
    });

    test('formatDateForViewer shows only date and month for others and full date for owner', () {
      final date = DateTime(1992, 8, 14);

      // Owner sees full year
      final ownerView = DateCalculators.formatDateForViewer(
        date,
        isAnnual: true,
        isOwner: true,
      );
      expect(ownerView, equals('14 Aug 1992'));

      // Others (individual share or circle) see only date and month
      final othersView = DateCalculators.formatDateForViewer(
        date,
        isAnnual: true,
        isOwner: false,
      );
      expect(othersView, equals('14 Aug'));
      expect(othersView.contains('1992'), isFalse);
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

  group('Shared Diary & Circle Privacy for Birthdays and Anniversaries', () {
    const ownerId = 'user_owner_001';
    const collaboratorId = 'user_collab_002';

    final familyRecord = DiaryRecord(
      id: 'rec_fam_1',
      ownerId: ownerId,
      sourceDiaryId: 'family',
      title: 'Dad Profile',
      subtitle: 'Father',
      recordDate: DateTime(1965, 10, 24),
      fields: {
        'member_name': 'John Doe',
        'relation': 'Father',
        'date_of_birth': '1965-10-24T00:00:00.000',
        'anniversary': '1990-05-18T00:00:00.000',
        'phone': '9876543210',
      },
      createdBy: ownerId,
      updatedBy: ownerId,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final marriageRecord = DiaryRecord(
      id: 'rec_mar_1',
      ownerId: ownerId,
      sourceDiaryId: 'marriage',
      title: 'Our Wedding Anniversary',
      recordDate: DateTime(2015, 12, 10),
      fields: {
        'date': '2015-12-10T00:00:00.000',
        'milestone_title': 'Decade Celebration',
      },
      createdBy: ownerId,
      updatedBy: ownerId,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('Owner views full dates and birth/marriage years unaltered', () {
      final filtered = DiaryAccessControlService.filterRecordsForUser(
        allRecords: [familyRecord, marriageRecord],
        currentUserId: ownerId,
        diaryOwnerId: ownerId,
      );

      expect(filtered.length, equals(2));
      final fam = filtered.first;
      expect(fam.fields['date_of_birth'], equals('1965-10-24T00:00:00.000'));
      expect(fam.fields['anniversary'], equals('1990-05-18T00:00:00.000'));
    });

    test('Individual share with recipient masks birth year and anniversary year to date & month only', () {
      final shareAccess = SharedDiaryAccess(
        id: 'share_001',
        diaryId: 'family',
        diaryName: 'Family Diary',
        ownerUid: ownerId,
        ownerName: 'Owner',
        sharedWithUid: collaboratorId,
        sharedWithEmail: 'collab@magicdiary.app',
        sharedWithName: 'Collaborator',
        recipientType: RecipientType.user,
        shareEntireDiary: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final filtered = DiaryAccessControlService.filterRecordsForUser(
        allRecords: [familyRecord],
        currentUserId: collaboratorId,
        diaryOwnerId: ownerId,
        shareAccess: shareAccess,
      );

      expect(filtered.length, equals(1));
      final sanitized = filtered.first;

      // Other user MUST NOT see the year 1965 or 1990
      expect(sanitized.fields['date_of_birth'].toString().contains('1965'), isFalse);
      expect(sanitized.fields['anniversary'].toString().contains('1990'), isFalse);

      // Other user MUST only see date and month
      expect(sanitized.fields['date_of_birth'], equals('24 October'));
      expect(sanitized.fields['anniversary'], equals('18 May'));

      // Non-birthday fields remain unaffected
      expect(sanitized.fields['member_name'], equals('John Doe'));
      expect(sanitized.fields['relation'], equals('Father'));
    });

    test('Magic Circle share masks birth year and anniversary year to date & month only', () {
      // Circle share without individual shareAccess object
      final filtered = DiaryAccessControlService.filterRecordsForUser(
        allRecords: [familyRecord, marriageRecord],
        currentUserId: collaboratorId,
        diaryOwnerId: ownerId,
        isCircleShare: true,
      );

      expect(filtered.length, equals(2));
      final sanitizedFamily = filtered[0];
      final sanitizedMarriage = filtered[1];

      // Family diary check: only date and month
      expect(sanitizedFamily.fields['date_of_birth'], equals('24 October'));
      expect(sanitizedFamily.fields['anniversary'], equals('18 May'));
      expect(sanitizedFamily.fields['date_of_birth'].toString().contains('1965'), isFalse);

      // Marriage diary check: only date and month
      expect(sanitizedMarriage.fields['date'], equals('10 December'));
      expect(sanitizedMarriage.fields['date'].toString().contains('2015'), isFalse);
    });

    test('Event diary record with event_type: Birthday strictly masks year and subtitle for shared viewer', () {
      final birthdayEventRecord = DiaryRecord(
        id: 'rec_event_bday_1',
        ownerId: ownerId,
        sourceDiaryId: 'event',
        title: 'Alex',
        subtitle: '30th Birthday (Born 1995)',
        recordDate: DateTime(1995, 4, 12),
        fields: {
          'event_type': 'Birthday',
          'event_date': '1995-04-12T00:00:00.000',
          'category': 'Personal',
        },
        createdBy: ownerId,
        updatedBy: ownerId,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // 1. Owner view retains full birth year and milestone subtitle
      final ownerFiltered = DiaryAccessControlService.filterRecordsForUser(
        allRecords: [birthdayEventRecord],
        currentUserId: ownerId,
        diaryOwnerId: ownerId,
      );
      expect(ownerFiltered.first.fields['event_date'], equals('1995-04-12T00:00:00.000'));
      expect(ownerFiltered.first.subtitle, equals('30th Birthday (Born 1995)'));

      // 2. Shared viewer view masks year to date & month only, and cleans subtitle
      final sharedFiltered = DiaryAccessControlService.filterRecordsForUser(
        allRecords: [birthdayEventRecord],
        currentUserId: collaboratorId,
        diaryOwnerId: ownerId,
        isCircleShare: true,
      );
      final sanitized = sharedFiltered.first;

      // Must NOT contain 1995 or 30th
      expect(sanitized.fields['event_date'].toString().contains('1995'), isFalse);
      expect(sanitized.fields['event_date'], equals('12 April'));
      expect(sanitized.subtitle?.contains('1995') ?? false, isFalse);
      expect(sanitized.subtitle?.contains('30th') ?? false, isFalse);
      expect(sanitized.subtitle, equals('Birthday'));
    });

    test('sanitizeMilestoneOrYearText strips birth years, est years, and ordinal milestone labels', () {
      expect(DateCalculators.sanitizeMilestoneOrYearText('30th Birthday (Born 1996)'), equals('Birthday'));
      expect(DateCalculators.sanitizeMilestoneOrYearText('10th Anniversary (Est. 2016)'), equals('Anniversary'));
      expect(DateCalculators.sanitizeMilestoneOrYearText('Born 1996'), equals(''));
      expect(DateCalculators.sanitizeMilestoneOrYearText('Annual • 24 October'), equals('Annual • 24 October'));
    });

    test('Family Diary date_of_birth masks year in share circle for any member', () {
      final famRecord = DiaryRecord(
        id: 'rec_fam_bday',
        ownerId: ownerId,
        sourceDiaryId: 'family',
        title: 'Child Profile',
        subtitle: 'Daughter',
        recordDate: DateTime(2018, 9, 15),
        fields: {
          'member_name': 'Emma Doe',
          'relation': 'Child',
          'date_of_birth': '2018-09-15T00:00:00.000',
        },
        createdBy: ownerId,
        updatedBy: ownerId,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final circleFiltered = DiaryAccessControlService.filterRecordsForUser(
        allRecords: [famRecord],
        currentUserId: collaboratorId,
        diaryOwnerId: ownerId,
        isCircleShare: true,
      );

      expect(circleFiltered.first.fields['date_of_birth'], equals('15 September'));
      expect(circleFiltered.first.fields['date_of_birth'].toString().contains('2018'), isFalse);
    });
  });

  group('Categorized Event Type Registry Tests', () {
    test('contains all 6 required categories in order', () {
      const categories = EventTypeRegistry.categories;
      expect(categories.length, equals(6));
      expect(categories[0].title, equals('1. Personal & family'));
      expect(categories[1].title, equals('2. Religious & cultural occasions'));
      expect(categories[2].title, equals('3. Relationships & social'));
      expect(categories[3].title, equals('4. Professional & education'));
      expect(categories[4].title, equals('5. Property & important milestones'));
      expect(categories[5].title, equals('6. Custom'));
    });

    test('verifies all expected event types in Category 1: Personal & family', () {
      final types = EventTypeRegistry.categories[0].types;
      expect(types, containsAll([
        'Birthday',
        'Wedding Anniversary',
        'Engagement Anniversary',
        'Relationship Anniversary',
        'Naming Ceremony',
        'Graduation Anniversary',
        'Retirement Anniversary',
        'Family Reunion',
      ]));
    });

    test('verifies all expected event types in Category 2: Religious & cultural occasions', () {
      final types = EventTypeRegistry.categories[1].types;
      expect(types, containsAll([
        'Festival',
        'Religious Ceremony',
        'Puja / Prayer',
        'Housewarming / Griha Pravesh',
        'Naming Ceremony (Religious)',
        'Thread Ceremony',
        'Traditional Family Function',
        'Other Cultural Occasion',
      ]));
    });

    test('verifies all expected event types in Category 3: Relationships & social', () {
      final types = EventTypeRegistry.categories[2].types;
      expect(types, containsAll([
        'Friendship Anniversary',
        'First Meeting Anniversary',
        'Special Day',
        'Reunion',
        'Family Celebration',
        'Memorial Day',
        'Remembrance Day',
      ]));
    });

    test('verifies all expected event types in Category 4: Professional & education', () {
      final types = EventTypeRegistry.categories[3].types;
      expect(types, containsAll([
        'Work Anniversary',
        'Joining Anniversary',
        'Business Anniversary',
        'Company Foundation Day',
        'School / College Anniversary',
        'Exam Date',
        'Certification Anniversary',
      ]));
    });

    test('verifies all expected event types in Category 5: Property & important milestones', () {
      final types = EventTypeRegistry.categories[4].types;
      expect(types, containsAll([
        'House Purchase Anniversary',
        'Property Registration Date',
        'Vehicle Purchase Anniversary',
        'Loan Closure Anniversary',
        'Important Milestone',
        'Other Important Date',
      ]));
    });

    test('verifies Category 6: Custom contains Other', () {
      final types = EventTypeRegistry.categories[5].types;
      expect(types, contains('Other'));
    });

    test('maps types to correct categories and icons', () {
      final cat = EventTypeRegistry.getCategoryForType('House Purchase Anniversary');
      expect(cat?.title, equals('5. Property & important milestones'));

      final icon = EventTypeRegistry.getIconForType('Work Anniversary');
      expect(icon, equals(Icons.business_center_rounded));
    });
  });
}
