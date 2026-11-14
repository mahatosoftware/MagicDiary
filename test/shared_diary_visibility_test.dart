import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/shared_diaries/models/shared_diary_models.dart';
import 'package:magic_diary/features/shared_diaries/repositories/shared_diary_repository.dart';
import 'package:magic_diary/core/security/diary_access_control_service.dart';
import 'package:magic_diary/core/diary_engine/models/diary_record.dart';
import 'package:magic_diary/core/diary_registry/diary_registry.dart';

void main() {
  group('Shared Diary Visibility & Deterministic ID Tests', () {
    test('generateShareId produces deterministic, safe, lowercased document IDs', () {
      final emailShareId = SharedDiaryRepository.generateShareId(
        ownerUid: 'user_owner_123',
        diaryId: 'groceries',
        target: 'Recipient.Family@Example.COM',
      );
      expect(emailShareId, equals('user_owner_123_groceries_recipient.family@example.com'));

      final uidShareId = SharedDiaryRepository.generateShareId(
        ownerUid: 'user_owner_123',
        diaryId: 'vehicle',
        target: 'recipient_uid_456',
      );
      expect(uidShareId, equals('user_owner_123_vehicle_recipient_uid_456'));
    });

    test('SharedDiaryAccess tracks pending vs claimed state and copyWith works properly', () {
      final pendingShare = SharedDiaryAccess(
        id: 'share_001',
        diaryId: 'bills',
        diaryName: 'Bills & Utilities',
        ownerUid: 'owner_1',
        ownerName: 'Alice',
        sharedWithUid: 'pending_bob@example.com',
        sharedWithEmail: 'bob@example.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.editor,
        shareEntireDiary: true,
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );

      expect(pendingShare.isPending, isTrue);
      expect(pendingShare.isExpired, isFalse);
      expect(pendingShare.permission.canAdd, isTrue);
      expect(pendingShare.permission.canEdit, isTrue);
      expect(pendingShare.permission.canManageAccess, isFalse);

      // Claim invitation with recipient's actual UID
      final claimedShare = pendingShare.copyWith(
        sharedWithUid: 'bob_firebase_uid_999',
        sharedWithName: 'Bob M.',
        updatedAt: DateTime(2026, 11, 14),
      );

      expect(claimedShare.isPending, isFalse);
      expect(claimedShare.sharedWithUid, equals('bob_firebase_uid_999'));
      expect(claimedShare.sharedWithName, equals('Bob M.'));
      expect(claimedShare.ownerUid, equals('owner_1'));
      expect(claimedShare.diaryId, equals('bills'));
    });

    test('SharedDiaryPermission grants appropriate capabilities across all 4 roles', () {
      const viewer = SharedDiaryPermission.viewer;
      expect(viewer.canAdd, isFalse);
      expect(viewer.canEdit, isFalse);
      expect(viewer.canManageAccess, isFalse);

      const contributor = SharedDiaryPermission.contributor;
      expect(contributor.canAdd, isTrue);
      expect(contributor.canEdit, isFalse);
      expect(contributor.canManageAccess, isFalse);

      const editor = SharedDiaryPermission.editor;
      expect(editor.canAdd, isTrue);
      expect(editor.canEdit, isTrue);
      expect(editor.canManageAccess, isFalse);

      const admin = SharedDiaryPermission.admin;
      expect(admin.canAdd, isTrue);
      expect(admin.canEdit, isTrue);
      expect(admin.canManageAccess, isTrue);
    });

    test('DiaryAccessControlService enforces role-based record access for shared diaries', () {
      final share = SharedDiaryAccess(
        id: 'share_test',
        diaryId: 'personal_finance',
        diaryName: 'Personal Finance',
        ownerUid: 'owner_user',
        ownerName: 'Owner User',
        sharedWithUid: 'contributor_user',
        sharedWithEmail: 'contrib@test.com',
        sharedWithName: 'Contributor',
        permission: SharedDiaryPermission.contributor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Can read shared diary
      final canRead = DiaryAccessControlService.canRead(
        currentUserId: 'contributor_user',
        diaryOwnerId: 'owner_user',
        shareAccess: share,
      );
      expect(canRead, isTrue);

      // 2. Can add records
      final canAdd = DiaryAccessControlService.canAdd(
        currentUserId: 'contributor_user',
        diaryOwnerId: 'owner_user',
        shareAccess: share,
      );
      expect(canAdd, isTrue);

      // 3. Contributor can edit their OWN created record
      final canEditOwn = DiaryAccessControlService.canEdit(
        currentUserId: 'contributor_user',
        diaryOwnerId: 'owner_user',
        recordCreatorId: 'contributor_user',
        shareAccess: share,
      );
      expect(canEditOwn, isTrue);

      // 4. Contributor cannot edit another person's record
      final canEditOther = DiaryAccessControlService.canEdit(
        currentUserId: 'contributor_user',
        diaryOwnerId: 'owner_user',
        recordCreatorId: 'owner_user',
        shareAccess: share,
      );
      expect(canEditOther, isFalse);

      // 5. Unrelated third party has no access
      final canReadThirdParty = DiaryAccessControlService.canRead(
        currentUserId: 'stranger_uid',
        diaryOwnerId: 'owner_user',
        shareAccess: null,
      );
      expect(canReadThirdParty, isFalse);
    });

    test('Granular record-level filtering respects grantedRecordIds when shareEntireDiary is false', () {
      final records = [
        DiaryRecord(
          id: 'rec_1',
          ownerId: 'owner_1',
          sourceDiaryId: 'notes',
          title: 'Public Record 1',
          recordDate: DateTime.now(),
          createdBy: 'owner_1',
          updatedBy: 'owner_1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        DiaryRecord(
          id: 'rec_2',
          ownerId: 'owner_1',
          sourceDiaryId: 'notes',
          title: 'Private Record 2',
          recordDate: DateTime.now(),
          createdBy: 'owner_1',
          updatedBy: 'owner_1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final granularShare = SharedDiaryAccess(
        id: 'share_gran',
        diaryId: 'notes',
        diaryName: 'Notes',
        ownerUid: 'owner_1',
        ownerName: 'Owner',
        sharedWithUid: 'friend_1',
        sharedWithEmail: 'friend@test.com',
        sharedWithName: 'Friend',
        permission: SharedDiaryPermission.viewer,
        shareEntireDiary: false,
        grantedRecordIds: ['rec_1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final visibleRecords = DiaryAccessControlService.filterRecordsForUser(
        allRecords: records,
        currentUserId: 'friend_1',
        diaryOwnerId: 'owner_1',
        shareAccess: granularShare,
      );

      expect(visibleRecords.length, equals(1));
      expect(visibleRecords.first.id, equals('rec_1'));
    });

    test('Mode 1 - Entire Diary with FutureRecordPolicy.existingOnly blocks post-cutoff records', () {
      final cutoff = DateTime(2026, 11, 10, 12, 0);
      final existingRecord = DiaryRecord(
        id: 'rec_old',
        ownerId: 'owner_1',
        sourceDiaryId: 'inventory',
        title: 'Household TV',
        recordDate: DateTime(2026, 11, 5),
        createdBy: 'owner_1',
        updatedBy: 'owner_1',
        createdAt: DateTime(2026, 11, 8),
        updatedAt: DateTime(2026, 11, 8),
      );

      final futureRecord = DiaryRecord(
        id: 'rec_future',
        ownerId: 'owner_1',
        sourceDiaryId: 'inventory',
        title: 'New Microwave',
        recordDate: DateTime(2026, 11, 12),
        createdBy: 'owner_1',
        updatedBy: 'owner_1',
        createdAt: DateTime(2026, 11, 12),
        updatedAt: DateTime(2026, 11, 12),
      );

      final share = SharedDiaryAccess(
        id: 'share_existing_only',
        diaryId: 'inventory',
        diaryName: 'Household Inventory',
        ownerUid: 'owner_1',
        ownerName: 'Debasish',
        sharedWithUid: 'recipient_1',
        sharedWithEmail: 'recipient@test.com',
        sharedWithName: 'Recipient',
        permission: SharedDiaryPermission.viewer,
        sharingMode: SharingMode.entire,
        futureRecordPolicy: FutureRecordPolicy.existingOnly,
        snapshotCutoffTime: cutoff,
        createdAt: cutoff,
        updatedAt: cutoff,
      );

      // Check record access helper
      expect(share.hasRecordAccess(existingRecord.id, existingRecord.createdAt), isTrue);
      expect(share.hasRecordAccess(futureRecord.id, futureRecord.createdAt), isFalse);

      // Check centralized service
      final visible = DiaryAccessControlService.filterRecordsForUser(
        allRecords: [existingRecord, futureRecord],
        currentUserId: 'recipient_1',
        diaryOwnerId: 'owner_1',
        shareAccess: share,
      );
      expect(visible.length, equals(1));
      expect(visible.first.id, equals('rec_old'));

      // countAccessibleRecords
      expect(share.countAccessibleRecords([existingRecord, futureRecord]), equals(1));
    });

    test('Mode 2 - Selected Records with 4-way SharedRecordAccessSummary computation', () {
      final records = List.generate(
        25,
        (i) => DiaryRecord(
          id: 'rec_$i',
          ownerId: 'owner_1',
          sourceDiaryId: 'vehicle',
          title: 'Vehicle Document $i',
          recordDate: DateTime(2026, 11, 1),
          createdBy: 'owner_1',
          updatedBy: 'owner_1',
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 1),
        ),
      );

      // In Debasish's vehicle example:
      // Total records: 25
      // Selected records: 3 ('rec_0', 'rec_1', 'rec_2')
      // Already shared with someone else: 2 ('rec_3', 'rec_4')
      // Remaining private: 20
      final selected = {'rec_0', 'rec_1', 'rec_2'};
      final otherShared = {'rec_3', 'rec_4'};

      final summary = SharedRecordAccessSummary.compute(
        allRecords: records,
        currentlySelectedRecordIds: selected,
        allOtherSharedRecordIds: otherShared,
      );

      expect(summary.totalRecords, equals(25));
      expect(summary.selectedRecords, equals(3));
      expect(summary.alreadySharedRecords, equals(2));
      expect(summary.remainingPrivateRecords, equals(20));
    });

    test('Access restrictions: attachment downloads, data exports, and field redactions', () {
      final fullRecord = DiaryRecord(
        id: 'rec_confidential',
        ownerId: 'owner_1',
        sourceDiaryId: 'legal',
        title: 'Employment Agreement',
        recordDate: DateTime(2026, 11, 1),
        createdBy: 'owner_1',
        updatedBy: 'owner_1',
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
        attachmentIds: ['att_contract_pdf', 'att_pan_jpg'],
        fields: {
          'salary': '1000000',
          'designation': 'Architect',
          'panNumber': 'ABCDE1234F',
        },
      );

      final restrictedShare = SharedDiaryAccess(
        id: 'share_restr',
        diaryId: 'legal',
        diaryName: 'Legal Diary',
        ownerUid: 'owner_1',
        ownerName: 'Debasish',
        sharedWithUid: 'reviewer_1',
        sharedWithEmail: 'reviewer@test.com',
        sharedWithName: 'Reviewer',
        permission: SharedDiaryPermission.viewer,
        allowAttachments: false,
        allowExport: false,
        restrictedFields: ['salary', 'panNumber'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Attachment check
      expect(
        DiaryAccessControlService.canAccessAttachment(
          currentUserId: 'reviewer_1',
          diaryOwnerId: 'owner_1',
          shareAccess: restrictedShare,
        ),
        isFalse,
      );

      // Owner always has attachment access
      expect(
        DiaryAccessControlService.canAccessAttachment(
          currentUserId: 'owner_1',
          diaryOwnerId: 'owner_1',
          shareAccess: restrictedShare,
        ),
        isTrue,
      );

      // Export check
      expect(
        DiaryAccessControlService.canExport(
          currentUserId: 'reviewer_1',
          diaryOwnerId: 'owner_1',
          shareAccess: restrictedShare,
        ),
        isFalse,
      );

      // Redacted fields check
      final filteredRecord = DiaryAccessControlService.filterRecordFieldsForUser(
        record: fullRecord,
        shareAccess: restrictedShare,
      );

      expect(filteredRecord.fields.containsKey('salary'), isFalse);
      expect(filteredRecord.fields.containsKey('panNumber'), isFalse);
      expect(filteredRecord.fields['designation'], equals('Architect'));
      expect(filteredRecord.attachmentIds, isEmpty);
    });

    test('Magic Circles integration: shared with circle sets circleId and circleName', () {
      final circleShare = SharedDiaryAccess(
        id: 'share_circle_family',
        diaryId: 'household_inventory',
        diaryName: 'Household Inventory',
        ownerUid: 'owner_1',
        ownerName: 'Debasish',
        recipientType: RecipientType.circle,
        circleId: 'circle_family_99',
        circleName: 'Mahato Family Circle',
        sharedWithUid: 'circle_family_99',
        sharedWithEmail: 'circle_family_99@magicdiary.internal',
        sharedWithName: 'Mahato Family Circle',
        permission: SharedDiaryPermission.editor,
        sharingMode: SharingMode.entire,
        futureRecordPolicy: FutureRecordPolicy.allFuture,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(circleShare.recipientType, equals(RecipientType.circle));
      expect(circleShare.circleId, equals('circle_family_99'));
      expect(circleShare.circleName, equals('Mahato Family Circle'));
      expect(circleShare.permission, equals(SharedDiaryPermission.editor));
      expect(circleShare.permission.canAdd, isTrue);
      expect(circleShare.permission.canEdit, isTrue);
    });

    test('Diary dropdown items are ordered alphabetically by name', () {
      final list = DiaryRegistry.predefinedDiariesAlphabetical;
      expect(list.length, equals(DiaryRegistry.predefinedDiaries.length));
      expect(list.first.name, equals('Assets & Valuables Diary'));
      for (int i = 0; i < list.length - 1; i++) {
        final current = list[i].name.toLowerCase();
        final next = list[i + 1].name.toLowerCase();
        expect(
          current.compareTo(next) <= 0,
          isTrue,
          reason: '${list[i].name} should precede ${list[i + 1].name}',
        );
      }
    });
  });
}
