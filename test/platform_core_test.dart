import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/diary_registry/diary_registry.dart';
import 'package:magic_diary/core/diary_registry/diary_category.dart';
import 'package:magic_diary/core/diary_registry/diary_definition.dart';
import 'package:magic_diary/core/diary_engine/models/diary_record.dart';
import 'package:magic_diary/core/calendar/services/calendar_service.dart';
import 'package:magic_diary/features/shared_diaries/models/shared_diary_models.dart';
import 'package:magic_diary/features/magic_circles/models/magic_circle_models.dart';
import 'package:magic_diary/features/reminders/models/reminder.dart';
import 'package:magic_diary/features/bills/models/bills_models.dart';
import 'package:magic_diary/features/vehicle/models/vehicle_models.dart';

void main() {
  group('Phase 1: Centralized Diary Registry Tests', () {
    test('Diary Registry contains exactly 45 predefined subdiaries', () {
      expect(DiaryRegistry.predefinedDiaries.length, equals(45));
    });

    test('All 45 diaries have unique IDs and non-empty metadata', () {
      final ids = <String>{};
      for (final diary in DiaryRegistry.predefinedDiaries) {
        expect(diary.id.isNotEmpty, isTrue);
        expect(ids.contains(diary.id), isFalse, reason: 'Duplicate diary ID: ${diary.id}');
        ids.add(diary.id);
        expect(diary.name.isNotEmpty, isTrue);
        expect(diary.description.isNotEmpty, isTrue);
        expect(diary.categoryId.isNotEmpty, isTrue);
      }
    });

    test('All 8 Categories contain the correct count of predefined subdiaries', () {
      final financial = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.financial);
      final homeProperty = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.homeAndProperty);
      final vehicleTravel = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.vehicleAndTravel);
      final familyEducation = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.familyAndEducation);
      final assetsProtection = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.assetsAndProtection);
      final healthWellbeing = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.healthAndWellbeing);
      final lifestyle = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.lifestyleAndOrganization);
      final specialPurpose = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.specialPurpose);

      expect(financial.length, equals(6));
      expect(homeProperty.length, equals(4));
      expect(vehicleTravel.length, equals(3));
      expect(familyEducation.length, equals(4));
      expect(assetsProtection.length, equals(3));
      expect(healthWellbeing.length, equals(6));
      expect(lifestyle.length, equals(9));
      expect(specialPurpose.length, equals(10));

      final total = financial.length +
          homeProperty.length +
          vehicleTravel.length +
          familyEducation.length +
          assetsProtection.length +
          healthWellbeing.length +
          lifestyle.length +
          specialPurpose.length;
      expect(total, equals(45));
    });

    test('Default sharing classifications conform to specifications', () {
      final personalJournal = DiaryRegistry.getDiaryById('personal_journal');
      final investment = DiaryRegistry.getDiaryById('investment');
      final billPayment = DiaryRegistry.getDiaryById('bill_payment');
      final personalFinance = DiaryRegistry.getDiaryById('personal_finance');

      expect(personalJournal?.defaultSharingClassification, equals(DefaultSharingClassification.privateByDefault));
      expect(investment?.defaultSharingClassification, equals(DefaultSharingClassification.privateByDefault));
      expect(billPayment?.defaultSharingClassification, equals(DefaultSharingClassification.sharedByNature));
      expect(personalFinance?.defaultSharingClassification, equals(DefaultSharingClassification.selectiveSharing));
    });

    test('Home Maintenance Diary contains Water Purifier filter replacement option and keywords', () {
      final homeMaintenance = DiaryRegistry.getDiaryById('home_maintenance');
      expect(homeMaintenance, isNotNull);
      final serviceTypeField = homeMaintenance!.suggestedFields.firstWhere((f) => f.key == 'service_type');
      expect(serviceTypeField.dropdownOptions, contains('Water Purifier / Filter Replacement'));
      expect(homeMaintenance.keywords, contains('water purifier'));
      expect(homeMaintenance.keywords, contains('filter replacement'));
    });
  });

  group('Phase 1: Universal Diary Engine & Custom Fields Tests', () {
    test('DiaryRecord correctly serializes, deserializes, and masks restricted fields', () {
      final now = DateTime(2026, 11, 14, 10, 0);
      final record = DiaryRecord(
        id: 'rec_1001',
        ownerId: 'user_abc',
        sourceDiaryId: 'insurance',
        circleId: 'circle_family',
        title: 'Star Health Family Policy',
        subtitle: 'Annual Comprehensive Health Cover',
        recordDate: now,
        amount: 28500.0,
        currency: 'INR',
        tags: ['health', 'insurance', 'family'],
        fields: {
          'policy_number': 'SH-99281-2026',
          'company': 'Star Health',
          'sum_insured': 1500000.0,
        },
        restrictedFields: ['policy_number'],
        isPrivate: false,
        createdBy: 'user_abc',
        updatedBy: 'user_abc',
        createdAt: now,
        updatedAt: now,
      );

      expect(record.isFieldRestricted('policy_number'), isTrue);
      expect(record.isFieldRestricted('company'), isFalse);

      final map = record.toMap();
      expect(map['title'], equals('Star Health Family Policy'));
      expect(map['amount'], equals(28500.0));
      expect(map['restrictedFields'], contains('policy_number'));

      final restored = DiaryRecord.fromMap(map, 'rec_1001');
      expect(restored.id, equals('rec_1001'));
      expect(restored.ownerId, equals('user_abc'));
      expect(restored.fields['company'], equals('Star Health'));
      expect(restored.fields['sum_insured'], equals(1500000.0));
      expect(restored.restrictedFields, contains('policy_number'));
    });
  });

  group('Phase 1: Universal Calendar Aggregation Tests', () {
    test('CalendarService aggregates events across multiple diaries and circle tasks', () {
      final today = DateTime(2026, 11, 14, 15, 0);

      final reminder = Reminder(
        id: 'rem_1',
        userId: 'user_1',
        title: 'Renew Passport',
        description: 'Check renewal documents',
        module: 'Personal',
        dueDate: today,
        createdAt: today,
      );

      final bill = Bill(
        id: 'bill_1',
        userId: 'user_1',
        billAccountId: 'acc_elec',
        billPeriod: 'Nov 2026',
        billDate: today,
        dueDate: today,
        amount: 2450.0,
      );

      final vehicle = Vehicle(
        id: 'veh_1',
        name: 'Honda City',
        type: 'Car',
        brand: 'Honda',
        model: 'City ZX',
        registrationNumber: 'MH-02-CD-1234',
        purchaseDate: DateTime(2024, 1, 1),
        currentOdometer: 15000,
        insuranceExpiry: today,
        pucExpiry: today,
      );

      final events = CalendarService.aggregateEvents(
        reminders: [reminder],
        bills: [bill],
        vehicles: [vehicle],
      );

      expect(events.length, equals(4));
      expect(events.any((e) => e.title.contains('Passport')), isTrue);
      expect(events.any((e) => e.title.contains('Nov 2026')), isTrue);
      expect(events.any((e) => e.title.contains('Insurance Renewal: Honda City')), isTrue);
      expect(events.any((e) => e.title.contains('PUC Expiry: Honda City')), isTrue);
    });
  });

  group('Phase 1: Shared Diaries & Magic Circles Models Tests', () {
    test('SharedDiaryAccess tracks permissions and expiration properly', () {
      final now = DateTime.now();
      final share = SharedDiaryAccess(
        id: 'share_123',
        diaryId: 'bill_payment',
        diaryName: 'Household Bills',
        ownerUid: 'owner_1',
        ownerName: 'Debasish',
        sharedWithUid: 'member_2',
        sharedWithEmail: 'member@family.org',
        sharedWithName: 'Priya',
        permission: SharedDiaryPermission.editor,
        expiresAt: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      expect(share.isExpired, isFalse);
      expect(share.permission.canEdit, isTrue);
      expect(share.permission.canManageAccess, isFalse);

      final expiredShare = SharedDiaryAccess(
        id: 'share_expired',
        diaryId: 'vehicle',
        diaryName: 'Car Diary',
        ownerUid: 'owner_1',
        ownerName: 'Debasish',
        sharedWithUid: 'member_3',
        sharedWithEmail: 'temp@friend.org',
        sharedWithName: 'Friend',
        expiresAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
      );
      expect(expiredShare.isExpired, isTrue);
    });

    test('MagicCircle models support roles, responsibilities and split expenses', () {
      final now = DateTime.now();
      final owner = MagicCircleMember(
        uid: 'user_owner',
        email: 'owner@home.com',
        displayName: 'Owner',
        role: CircleRole.owner,
        joinedAt: now,
      );
      final member = MagicCircleMember(
        uid: 'user_member',
        email: 'member@home.com',
        displayName: 'Member',
        role: CircleRole.contributor,
        joinedAt: now,
      );

      final circle = MagicCircle(
        id: 'circle_family',
        name: 'Family Circle',
        category: CircleCategory.family,
        ownerId: owner.uid,
        members: [owner, member],
        sharedDiaryIds: ['bill_payment', 'grocery_supplies', 'vehicle'],
        createdAt: now,
        updatedAt: now,
      );

      expect(circle.isMember('user_owner'), isTrue);
      expect(circle.isMember('user_member'), isTrue);
      expect(circle.isMember('unknown'), isFalse);
      expect(circle.members.length, equals(2));
      expect(circle.memberUids, containsAll(['user_owner', 'user_member']));
      expect(circle.sharedDiaryIds.length, equals(3));

      // Serialization and Deserialization with memberUids
      final map = circle.toMap();
      expect(map['memberUids'], containsAll(['user_owner', 'user_member']));
      final deserialized = MagicCircle.fromMap(map, circle.id);
      expect(deserialized.memberUids, containsAll(['user_owner', 'user_member']));

      // Task responsibility
      final task = CircleResponsibilityTask(
        id: 'task_1',
        circleId: circle.id,
        title: 'Service Water Purifier',
        assignedToUid: member.uid,
        assignedToName: member.displayName,
        createdByUid: owner.uid,
        dueDate: now.add(const Duration(days: 2)),
        priority: 'high',
        status: 'assigned',
        createdAt: now,
      );
      expect(task.isCompleted, isFalse);

      // Shared Expense
      final expense = CircleExpense(
        id: 'exp_1',
        circleId: circle.id,
        title: 'Supermarket Groceries',
        amount: 3600.0,
        paidByUid: owner.uid,
        paidByName: owner.displayName,
        participantUids: [owner.uid, member.uid],
        splitType: 'equal',
        splitMatrix: {
          owner.uid: 1800.0,
          member.uid: 1800.0,
        },
        expenseDate: now,
      );
      expect(expense.amount, equals(3600.0));
      expect(expense.splitMatrix[owner.uid], equals(1800.0));
      expect(expense.splitMatrix[member.uid], equals(1800.0));
    });
  });
}
