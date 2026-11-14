import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/security/security.dart';
import 'package:magic_diary/core/diary_engine/models/diary_record.dart';
import 'package:magic_diary/features/shared_diaries/models/shared_diary_models.dart';
import 'package:magic_diary/features/magic_circles/models/magic_circle_models.dart';

void main() {
  group('Enterprise Security Hardening Test Suite', () {
    const userA = 'user_alice_123';
    const userB = 'user_bob_456';
    const userC = 'user_charlie_789';

    // 1. User A cannot read User B's private diary
    test('Scenario 1: User A cannot read User B\'s private diary without share access', () {
      final canRead = DiaryAccessControlService.canRead(
        currentUserId: userA,
        diaryOwnerId: userB,
        shareAccess: null,
      );
      expect(canRead, isFalse);

      final role = DiaryAccessControlService.evaluateRole(
        currentUserId: userA,
        diaryOwnerId: userB,
        shareAccess: null,
      );
      expect(role, equals(DiaryAccessRole.none));
    });

    // 2. User A cannot modify User B's records
    test('Scenario 2: User A cannot edit or delete User B\'s private records', () {
      final canEdit = DiaryAccessControlService.canEdit(
        currentUserId: userA,
        diaryOwnerId: userB,
        recordCreatorId: userB,
        shareAccess: null,
      );
      expect(canEdit, isFalse);

      final canDelete = DiaryAccessControlService.canDelete(
        currentUserId: userA,
        diaryOwnerId: userB,
        shareAccess: null,
      );
      expect(canDelete, isFalse);
    });

    // 3. Circle members cannot access unshared personal diaries
    test('Scenario 3: Circle membership does not grant access to unshared personal diaries', () {
      final circle = MagicCircle(
        id: 'circle_family_1',
        name: 'Family Circle',
        category: CircleCategory.family,
        ownerId: userA,
        memberUids: [userA, userB],
        members: [
          MagicCircleMember(uid: userA, email: 'alice@test.com', displayName: 'Alice', role: CircleRole.owner, joinedAt: DateTime.now()),
          MagicCircleMember(uid: userB, email: 'bob@test.com', displayName: 'Bob', role: CircleRole.editor, joinedAt: DateTime.now()),
        ],
        sharedDiaryIds: ['grocery_supplies', 'family_events'], // Only these are shared
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Explicitly shared diary
      expect(CirclePermissionService.isDiarySharedWithCircle(circle, 'grocery_supplies'), isTrue);

      // Private personal diaries owned by Alice (not in circle's sharedDiaryIds)
      expect(CirclePermissionService.isDiarySharedWithCircle(circle, 'personal_finance'), isFalse);
      expect(CirclePermissionService.isDiarySharedWithCircle(circle, 'tax'), isFalse);
      expect(CirclePermissionService.isDiarySharedWithCircle(circle, 'health'), isFalse);
    });

    // 4. A Viewer cannot modify records
    test('Scenario 4: A Viewer role can read but cannot add, edit, or delete records', () {
      final viewerAccess = SharedDiaryAccess(
        id: 'share_view_1',
        diaryId: 'vehicle',
        diaryName: 'Vehicle Diary',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userB,
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.viewer,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(DiaryAccessControlService.canRead(currentUserId: userB, diaryOwnerId: userA, shareAccess: viewerAccess), isTrue);
      expect(DiaryAccessControlService.canAdd(currentUserId: userB, diaryOwnerId: userA, shareAccess: viewerAccess), isFalse);
      expect(DiaryAccessControlService.canEdit(currentUserId: userB, diaryOwnerId: userA, recordCreatorId: userA, shareAccess: viewerAccess), isFalse);
      expect(DiaryAccessControlService.canDelete(currentUserId: userB, diaryOwnerId: userA, shareAccess: viewerAccess), isFalse);
    });

    // 5. A Contributor cannot change Circle ownership
    test('Scenario 5: A Contributor or Editor cannot change Circle ownership or promote members', () {
      final members = [
        MagicCircleMember(uid: userA, email: 'alice@test.com', displayName: 'Alice', role: CircleRole.owner, joinedAt: DateTime.now()),
        MagicCircleMember(uid: userB, email: 'bob@test.com', displayName: 'Bob', role: CircleRole.contributor, joinedAt: DateTime.now()),
        MagicCircleMember(uid: userC, email: 'charlie@test.com', displayName: 'Charlie', role: CircleRole.viewer, joinedAt: DateTime.now()),
      ];

      // Contributor Bob attempts to promote Charlie to Owner
      final canPromoteToOwner = CirclePermissionService.canModifyMemberRole(
        actorUid: userB,
        targetMemberUid: userC,
        circleOwnerId: userA,
        members: members,
        newRole: CircleRole.owner,
      );
      expect(canPromoteToOwner, isFalse);

      // Contributor Bob attempts to promote himself to Admin
      final canSelfPromote = CirclePermissionService.canModifyMemberRole(
        actorUid: userB,
        targetMemberUid: userB,
        circleOwnerId: userA,
        members: members,
        newRole: CircleRole.admin,
      );
      expect(canSelfPromote, isFalse);
    });

    // 6. A revoked member cannot read shared records
    test('Scenario 6: Expired or revoked share access immediately revokes read permissions', () {
      final expiredAccess = SharedDiaryAccess(
        id: 'share_exp_1',
        diaryId: 'property',
        diaryName: 'Property',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userB,
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.editor,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)), // Expired 1 hour ago
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      );

      expect(expiredAccess.isExpired, isTrue);
      expect(DiaryAccessControlService.canRead(currentUserId: userB, diaryOwnerId: userA, shareAccess: expiredAccess), isFalse);
      expect(DiaryAccessControlService.canAdd(currentUserId: userB, diaryOwnerId: userA, shareAccess: expiredAccess), isFalse);
    });

    // 7. An expired invitation cannot be accepted
    test('Scenario 7: An expired or revoked Circle invitation is invalid and rejected', () {
      final expiredInv = CircleInvitation(
        id: 'inv_1',
        circleId: 'circle_1',
        circleName: 'Test Circle',
        inviterUid: userA,
        inviterName: 'Alice',
        inviteeEmail: 'bob@test.com',
        role: 'editor',
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(expiredInv.isExpired, isTrue);
      expect(expiredInv.isValidPending, isFalse);

      final revokedInv = CircleInvitation(
        id: 'inv_2',
        circleId: 'circle_1',
        circleName: 'Test Circle',
        inviterUid: userA,
        inviterName: 'Alice',
        inviteeEmail: 'charlie@test.com',
        role: 'viewer',
        status: 'revoked',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      expect(revokedInv.isExpired, isFalse);
      expect(revokedInv.isValidPending, isFalse);
    });

    // 8. Privilege escalation check: User cannot self-elevate to Admin
    test('Scenario 8: Self-promotion and unauthorized privilege escalation is prevented', () {
      final members = [
        MagicCircleMember(uid: userA, email: 'alice@test.com', displayName: 'Alice', role: CircleRole.owner, joinedAt: DateTime.now()),
        MagicCircleMember(uid: userB, email: 'bob@test.com', displayName: 'Bob', role: CircleRole.admin, joinedAt: DateTime.now()),
        MagicCircleMember(uid: userC, email: 'charlie@test.com', displayName: 'Charlie', role: CircleRole.viewer, joinedAt: DateTime.now()),
      ];

      // Admin Bob attempts to promote Charlie to Owner (Only Owner can transfer ownership)
      final adminPromotesToOwner = CirclePermissionService.canModifyMemberRole(
        actorUid: userB,
        targetMemberUid: userC,
        circleOwnerId: userA,
        members: members,
        newRole: CircleRole.owner,
      );
      expect(adminPromotesToOwner, isFalse);

      // Admin Bob attempts to promote someone to Admin (Only Owner can appoint Admins)
      final adminAppointsAdmin = CirclePermissionService.canModifyMemberRole(
        actorUid: userB,
        targetMemberUid: userC,
        circleOwnerId: userA,
        members: members,
        newRole: CircleRole.admin,
      );
      expect(adminAppointsAdmin, isFalse);

      // Owner Alice can appoint Charlie as Editor
      final ownerAppointsEditor = CirclePermissionService.canModifyMemberRole(
        actorUid: userA,
        targetMemberUid: userC,
        circleOwnerId: userA,
        members: members,
        newRole: CircleRole.editor,
      );
      expect(ownerAppointsEditor, isTrue);
    });

    // 9. Unauthorized files & executables are blocked
    test('Scenario 9: Dangerous file extensions and oversized files are blocked before upload', () {
      // Dangerous executable
      final exeCheck = AttachmentSecurityService.validateFile(
        sizeBytes: 1024,
        mimeType: 'application/octet-stream',
        fileName: 'malware.exe',
      );
      expect(exeCheck, equals(FileValidationResult.dangerousExtension));

      // Script file
      final shCheck = AttachmentSecurityService.validateFile(
        sizeBytes: 500,
        mimeType: 'text/x-shellscript',
        fileName: 'payload.sh',
      );
      expect(shCheck, equals(FileValidationResult.dangerousExtension));

      // Oversized file (> 15MB)
      final largeCheck = AttachmentSecurityService.validateFile(
        sizeBytes: 16 * 1024 * 1024,
        mimeType: 'application/pdf',
        fileName: 'huge_document.pdf',
      );
      expect(largeCheck, equals(FileValidationResult.tooLarge));

      // Valid PDF document
      final validPdf = AttachmentSecurityService.validateFile(
        sizeBytes: 2 * 1024 * 1024,
        mimeType: 'application/pdf',
        fileName: 'property_tax_receipt.pdf',
      );
      expect(validPdf, equals(FileValidationResult.valid));
    });

    // 10. Record-level access filtering
    test('Scenario 10: Granular record sharing exposes only explicitly granted record IDs', () {
      final allRecords = [
        DiaryRecord(id: 'rec_1', ownerId: userA, sourceDiaryId: 'vehicle', title: 'Car Insurance', recordDate: DateTime.now(), createdBy: userA, updatedBy: userA, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        DiaryRecord(id: 'rec_2', ownerId: userA, sourceDiaryId: 'vehicle', title: 'PUC Receipt', recordDate: DateTime.now(), createdBy: userA, updatedBy: userA, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        DiaryRecord(id: 'rec_3', ownerId: userA, sourceDiaryId: 'vehicle', title: 'Private Repair Notes', recordDate: DateTime.now(), createdBy: userA, updatedBy: userA, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ];

      final selectiveShare = SharedDiaryAccess(
        id: 'share_selective',
        diaryId: 'vehicle',
        diaryName: 'Vehicle',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userB,
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.viewer,
        shareEntireDiary: false,
        grantedRecordIds: ['rec_1', 'rec_2'], // Only rec_1 and rec_2 granted
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final filtered = DiaryAccessControlService.filterRecordsForUser(
        allRecords: allRecords,
        currentUserId: userB,
        diaryOwnerId: userA,
        shareAccess: selectiveShare,
      );

      expect(filtered.length, equals(2));
      expect(filtered.map((r) => r.id), containsAll(['rec_1', 'rec_2']));
      expect(filtered.map((r) => r.id), isNot(contains('rec_3')));
    });

    // 11. Sensitive notification masking
    test('Scenario 11: Notification privacy masking hides sensitive financial and medical details', () {
      final maskedFinance = NotificationPrivacyService.maskSensitiveContent(
        rawTitle: '₹50,000 Loan EMI Overdue',
        rawBody: 'Your monthly EMI of ₹50,000 to HDFC Bank is overdue.',
        module: 'finance',
      );
      expect(maskedFinance['title'], equals('Financial Reminder'));
      expect(maskedFinance['body'], isNot(contains('50,000')));
      expect(maskedFinance['body'], isNot(contains('HDFC')));

      final maskedHealth = NotificationPrivacyService.maskSensitiveContent(
        rawTitle: 'Medicine Refill: Metformin 500mg',
        rawBody: 'Take Metformin 500mg after breakfast.',
        module: 'medicine',
      );
      expect(maskedHealth['title'], equals('Health & Wellness Reminder'));
      expect(maskedHealth['body'], isNot(contains('Metformin')));
    });

    // 12. Voice Assistant Security Boundaries
    test('Scenario 12: Voice assistants are blocked from financial transfers, payments, and account deletion', () {
      final scopes = ['read:reminders', 'read:calendar', 'write:tasks'];

      // Permitted read operations
      expect(VoiceIntegrationSecurityService.isOperationPermitted('read:reminders', scopes), isTrue);
      expect(VoiceIntegrationSecurityService.isOperationPermitted('write:tasks', scopes), isTrue);

      // Strictly prohibited operations
      expect(VoiceIntegrationSecurityService.isOperationPermitted('make_payment', scopes), isFalse);
      expect(VoiceIntegrationSecurityService.isOperationPermitted('execute_bank_transfer', scopes), isFalse);
      expect(VoiceIntegrationSecurityService.isOperationPermitted('delete_account', scopes), isFalse);
      expect(VoiceIntegrationSecurityService.isOperationPermitted('transfer_ownership', scopes), isFalse);
    });

    // 13. Rate Limiting Protection
    test('Scenario 13: Sliding-window rate limiting prevents brute-force attempts', () {
      final appCheck = AppCheckService();
      const testKey = 'test_action_rate_limit';

      // First 3 requests allowed (max 3)
      for (int i = 0; i < 3; i++) {
        final res = appCheck.checkRateLimit(key: testKey, maxRequests: 3, window: const Duration(minutes: 5));
        expect(res.isAllowed, isTrue);
      }

      // 4th request blocked
      final blocked = appCheck.checkRateLimit(key: testKey, maxRequests: 3, window: const Duration(minutes: 5));
      expect(blocked.isAllowed, isFalse);
      expect(blocked.remainingAttempts, equals(0));

      // Reset works
      appCheck.resetRateLimit(testKey);
      final afterReset = appCheck.checkRateLimit(key: testKey, maxRequests: 3, window: const Duration(minutes: 5));
      expect(afterReset.isAllowed, isTrue);
    });

    // 14. Sensitive Field Masking
    test('Scenario 14: DataEncryptionService accurately masks bank accounts, government IDs, and balances', () {
      expect(DataEncryptionService.maskAccountNumber('123456789012'), equals('•••• •••• 9012'));
      expect(DataEncryptionService.maskGovernmentId('ABCDE1234F'), equals('AB••••••4F'));
      expect(DataEncryptionService.maskCurrencyAmount(45000.0), equals('₹••••'));
    });

    // 15. Constant-time PIN hash verification
    test('Scenario 15: Constant-time hash verification resists timing attacks and matches salted inputs', () {
      const pin = '1234';
      final hash = DataEncryptionService.hashWithSalt(pin);

      expect(DataEncryptionService.verifyHash('1234', hash), isTrue);
      expect(DataEncryptionService.verifyHash('1235', hash), isFalse);
      expect(DataEncryptionService.verifyHash('', hash), isFalse);
    });

    // 16. Shared Diary Access Level Permissions
    test('Scenario 16: Contributor and Editor roles have write permissions while Viewer is restricted', () {
      final contributorAccess = SharedDiaryAccess(
        id: 'share_contrib_1',
        diaryId: 'vehicle',
        diaryName: 'Vehicle Diary',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userB,
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.contributor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final editorAccess = SharedDiaryAccess(
        id: 'share_editor_1',
        diaryId: 'vehicle',
        diaryName: 'Vehicle Diary',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userC,
        sharedWithEmail: 'charlie@test.com',
        sharedWithName: 'Charlie',
        permission: SharedDiaryPermission.editor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Contributor can read and add records, and edit their own contributed records
      expect(DiaryAccessControlService.canRead(currentUserId: userB, diaryOwnerId: userA, shareAccess: contributorAccess), isTrue);
      expect(DiaryAccessControlService.canAdd(currentUserId: userB, diaryOwnerId: userA, shareAccess: contributorAccess), isTrue);
      expect(DiaryAccessControlService.canEdit(currentUserId: userB, diaryOwnerId: userA, recordCreatorId: userB, shareAccess: contributorAccess), isTrue);
      expect(DiaryAccessControlService.canEdit(currentUserId: userB, diaryOwnerId: userA, recordCreatorId: userA, shareAccess: contributorAccess), isFalse);

      // Editor can read, add, and edit any record
      expect(DiaryAccessControlService.canRead(currentUserId: userC, diaryOwnerId: userA, shareAccess: editorAccess), isTrue);
      expect(DiaryAccessControlService.canAdd(currentUserId: userC, diaryOwnerId: userA, shareAccess: editorAccess), isTrue);
      expect(DiaryAccessControlService.canEdit(currentUserId: userC, diaryOwnerId: userA, recordCreatorId: userA, shareAccess: editorAccess), isTrue);
    });

    // 17. Shared Diary Pending Invitation Claiming Transition
    test('Scenario 17: Pending invitation transitions correctly when claimed by recipient UID', () {
      final pendingShare = SharedDiaryAccess(
        id: 'share_pending_1',
        diaryId: 'bills',
        diaryName: 'Household Bills',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: 'pending_bob@test.com',
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'bob',
        permission: SharedDiaryPermission.editor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(pendingShare.sharedWithUid.startsWith('pending_'), isTrue);

      // Recipient Bob claims the invite, transitioning sharedWithUid to userB
      final claimedShare = SharedDiaryAccess(
        id: pendingShare.id,
        diaryId: pendingShare.diaryId,
        diaryName: pendingShare.diaryName,
        ownerUid: pendingShare.ownerUid,
        ownerName: pendingShare.ownerName,
        sharedWithUid: userB,
        sharedWithEmail: pendingShare.sharedWithEmail,
        sharedWithName: pendingShare.sharedWithName,
        permission: pendingShare.permission,
        createdAt: pendingShare.createdAt,
        updatedAt: DateTime.now(),
      );

      expect(claimedShare.sharedWithUid, equals(userB));
      expect(claimedShare.ownerUid, equals(userA));
      expect(claimedShare.permission, equals(SharedDiaryPermission.editor));
      expect(DiaryAccessControlService.canRead(currentUserId: userB, diaryOwnerId: userA, shareAccess: claimedShare), isTrue);
      expect(DiaryAccessControlService.canAdd(currentUserId: userB, diaryOwnerId: userA, shareAccess: claimedShare), isTrue);
    });

    // 18. Complete Diary Sharing with existingOnly policy
    test('Scenario 18: Complete Diary Sharing with existingOnly policy blocks access to future records after snapshotCutoffTime', () {
      final cutoff = DateTime.now();
      final existingOnlyShare = SharedDiaryAccess(
        id: 'share_existing_only',
        diaryId: 'vehicle',
        diaryName: 'Vehicle',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userB,
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.viewer,
        sharingMode: SharingMode.entire,
        shareEntireDiary: true,
        futureRecordPolicy: FutureRecordPolicy.existingOnly,
        snapshotCutoffTime: cutoff,
        createdAt: cutoff,
        updatedAt: cutoff,
      );

      final oldRecord = DiaryRecord(
        id: 'rec_old',
        ownerId: userA,
        sourceDiaryId: 'vehicle',
        title: 'Past Oil Change',
        recordDate: cutoff.subtract(const Duration(days: 10)),
        createdAt: cutoff.subtract(const Duration(hours: 2)),
        updatedAt: cutoff.subtract(const Duration(hours: 2)),
        createdBy: userA,
        updatedBy: userA,
      );

      final futureRecord = DiaryRecord(
        id: 'rec_future',
        ownerId: userA,
        sourceDiaryId: 'vehicle',
        title: 'New Service Booking',
        recordDate: cutoff.add(const Duration(days: 5)),
        createdAt: cutoff.add(const Duration(hours: 1)),
        updatedAt: cutoff.add(const Duration(hours: 1)),
        createdBy: userA,
        updatedBy: userA,
      );

      expect(existingOnlyShare.hasRecordAccess(oldRecord.id, oldRecord.createdAt), isTrue);
      expect(existingOnlyShare.hasRecordAccess(futureRecord.id, futureRecord.createdAt), isFalse);

      expect(DiaryAccessControlService.canAccessRecord(record: oldRecord, currentUserId: userB, diaryOwnerId: userA, shareAccess: existingOnlyShare), isTrue);
      expect(DiaryAccessControlService.canAccessRecord(record: futureRecord, currentUserId: userB, diaryOwnerId: userA, shareAccess: existingOnlyShare), isFalse);

      final filtered = DiaryAccessControlService.filterRecordsForUser(
        allRecords: [oldRecord, futureRecord],
        currentUserId: userB,
        diaryOwnerId: userA,
        shareAccess: existingOnlyShare,
      );
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('rec_old'));
    });

    // 19. Complete Diary Sharing with allFuture policy
    test('Scenario 19: Complete Diary Sharing with allFuture policy allows access to both past and future records', () {
      final now = DateTime.now();
      final allFutureShare = SharedDiaryAccess(
        id: 'share_all_future',
        diaryId: 'vehicle',
        diaryName: 'Vehicle',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userB,
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.editor,
        sharingMode: SharingMode.entire,
        shareEntireDiary: true,
        futureRecordPolicy: FutureRecordPolicy.allFuture,
        createdAt: now,
        updatedAt: now,
      );

      final oldRecord = DiaryRecord(
        id: 'rec_past',
        ownerId: userA,
        sourceDiaryId: 'vehicle',
        title: 'Past Battery Replacement',
        recordDate: now.subtract(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
        createdBy: userA,
        updatedBy: userA,
      );

      final futureRecord = DiaryRecord(
        id: 'rec_future_new',
        ownerId: userA,
        sourceDiaryId: 'vehicle',
        title: 'Future Tire Rotation',
        recordDate: now.add(const Duration(days: 3)),
        createdAt: now.add(const Duration(hours: 5)),
        updatedAt: now.add(const Duration(hours: 5)),
        createdBy: userA,
        updatedBy: userA,
      );

      expect(allFutureShare.hasRecordAccess(oldRecord.id, oldRecord.createdAt), isTrue);
      expect(allFutureShare.hasRecordAccess(futureRecord.id, futureRecord.createdAt), isTrue);

      expect(DiaryAccessControlService.canAccessRecord(record: oldRecord, currentUserId: userB, diaryOwnerId: userA, shareAccess: allFutureShare), isTrue);
      expect(DiaryAccessControlService.canAccessRecord(record: futureRecord, currentUserId: userB, diaryOwnerId: userA, shareAccess: allFutureShare), isTrue);
    });

    // 20. Selected Record Sharing enforces grantedRecordIds list
    test('Scenario 20: Selected Record Sharing strictly restricts read to granted IDs and rejects ungranted records', () {
      final now = DateTime.now();
      final selectedShare = SharedDiaryAccess(
        id: 'share_selected_only',
        diaryId: 'property',
        diaryName: 'Property',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userC,
        sharedWithEmail: 'charlie@test.com',
        sharedWithName: 'Charlie',
        permission: SharedDiaryPermission.viewer,
        sharingMode: SharingMode.selected,
        shareEntireDiary: false,
        grantedRecordIds: ['doc_tax_2025', 'doc_lease_agreement'],
        createdAt: now,
        updatedAt: now,
      );

      expect(selectedShare.isSelectedMode, isTrue);

      final grantedRec = DiaryRecord(
        id: 'doc_tax_2025',
        ownerId: userA,
        sourceDiaryId: 'property',
        title: 'Property Tax 2025',
        recordDate: now,
        createdAt: now,
        updatedAt: now,
        createdBy: userA,
        updatedBy: userA,
      );

      final ungrantedRec = DiaryRecord(
        id: 'doc_private_deed',
        ownerId: userA,
        sourceDiaryId: 'property',
        title: 'Title Deed & Mortgage',
        recordDate: now,
        createdAt: now,
        updatedAt: now,
        createdBy: userA,
        updatedBy: userA,
      );

      expect(selectedShare.hasRecordAccess(grantedRec.id, grantedRec.createdAt), isTrue);
      expect(selectedShare.hasRecordAccess(ungrantedRec.id, ungrantedRec.createdAt), isFalse);

      expect(DiaryAccessControlService.canAccessRecord(record: grantedRec, currentUserId: userC, diaryOwnerId: userA, shareAccess: selectedShare), isTrue);
      expect(DiaryAccessControlService.canAccessRecord(record: ungrantedRec, currentUserId: userC, diaryOwnerId: userA, shareAccess: selectedShare), isFalse);
    });

    // 21. ShareStatus, attachment restriction, and restrictedFields masking
    test('Scenario 21: Revoked status, attachment restrictions, and restrictedFields redacting work seamlessly', () {
      final now = DateTime.now();
      final revokedShare = SharedDiaryAccess(
        id: 'share_revoked',
        diaryId: 'vehicle',
        diaryName: 'Vehicle',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userB,
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.editor,
        status: ShareStatus.revoked,
        createdAt: now,
        updatedAt: now,
      );

      expect(revokedShare.isActive, isFalse);
      expect(DiaryAccessControlService.canRead(currentUserId: userB, diaryOwnerId: userA, shareAccess: revokedShare), isFalse);

      final restrictedShare = SharedDiaryAccess(
        id: 'share_restricted',
        diaryId: 'vehicle',
        diaryName: 'Vehicle',
        ownerUid: userA,
        ownerName: 'Alice',
        sharedWithUid: userB,
        sharedWithEmail: 'bob@test.com',
        sharedWithName: 'Bob',
        permission: SharedDiaryPermission.viewer,
        allowAttachments: false,
        restrictedFields: ['privateNotes', 'confidentialCost'],
        createdAt: now,
        updatedAt: now,
      );

      final record = DiaryRecord(
        id: 'rec_car',
        ownerId: userA,
        sourceDiaryId: 'vehicle',
        title: 'Vehicle Audit',
        recordDate: now,
        fields: {
          'odometer': 12000,
          'privateNotes': 'Do not show buyer',
          'confidentialCost': 85000,
        },
        attachmentIds: ['att_1', 'att_2'],
        createdAt: now,
        updatedAt: now,
        createdBy: userA,
        updatedBy: userA,
      );

      expect(DiaryAccessControlService.canAccessAttachment(currentUserId: userB, diaryOwnerId: userA, shareAccess: restrictedShare), isFalse);

      final sanitized = DiaryAccessControlService.filterRecordFieldsForUser(record: record, shareAccess: restrictedShare);
      expect(sanitized.fields.containsKey('odometer'), isTrue);
      expect(sanitized.fields.containsKey('privateNotes'), isFalse);
      expect(sanitized.fields.containsKey('confidentialCost'), isFalse);
      expect(sanitized.attachmentIds, isEmpty);
    });

    // 22. SharedRecordAccessSummary accurate computation
    test('Scenario 22: SharedRecordAccessSummary correctly computes counts without double-counting', () {
      final records = [
        DiaryRecord(id: 'r1', ownerId: userA, sourceDiaryId: 'd', title: 'R1', recordDate: DateTime.now(), createdBy: userA, updatedBy: userA, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        DiaryRecord(id: 'r2', ownerId: userA, sourceDiaryId: 'd', title: 'R2', recordDate: DateTime.now(), createdBy: userA, updatedBy: userA, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        DiaryRecord(id: 'r3', ownerId: userA, sourceDiaryId: 'd', title: 'R3', recordDate: DateTime.now(), createdBy: userA, updatedBy: userA, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        DiaryRecord(id: 'r4', ownerId: userA, sourceDiaryId: 'd', title: 'R4', recordDate: DateTime.now(), createdBy: userA, updatedBy: userA, createdAt: DateTime.now(), updatedAt: DateTime.now()),
        DiaryRecord(id: 'r5', ownerId: userA, sourceDiaryId: 'd', title: 'R5', recordDate: DateTime.now(), createdBy: userA, updatedBy: userA, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ];

      final summary = SharedRecordAccessSummary.compute(
        allRecords: records,
        currentlySelectedRecordIds: {'r1', 'r2'},
        allOtherSharedRecordIds: {'r2', 'r3'},
      );

      expect(summary.totalRecords, equals(5));
      expect(summary.selectedRecords, equals(2));
      expect(summary.alreadySharedRecords, equals(1)); // r3 is already shared; r2 is in current selection
      expect(summary.remainingPrivateRecords, equals(2)); // r4 and r5 remain private
    });

    // 23. MagicCircle memberEmails visibility and pending membership transition
    test('Scenario 23: MagicCircle computes memberEmails, isMember matches email, and supports pending claim', () {
      final now = DateTime.now();
      final circle = MagicCircle(
        id: 'circle_fam',
        name: 'Family Circle',
        category: CircleCategory.family,
        ownerId: userA,
        createdAt: now,
        updatedAt: now,
        members: [
          MagicCircleMember(
            uid: userA,
            email: 'alice@test.com',
            displayName: 'Alice',
            role: CircleRole.owner,
            joinedAt: now,
            status: 'active',
          ),
          MagicCircleMember(
            uid: 'pending_bob@test.com',
            email: 'bob@test.com',
            displayName: 'Bob (Invited)',
            role: CircleRole.contributor,
            joinedAt: now,
            status: 'invited',
          ),
        ],
      );

      // Verify memberEmails is auto-populated and lowercased
      expect(circle.memberEmails, contains('alice@test.com'));
      expect(circle.memberEmails, contains('bob@test.com'));
      expect(circle.memberUids, contains(userA));
      expect(circle.memberUids.contains('pending_bob@test.com'), isFalse);

      // Verify isMember works with UID and with Email
      expect(circle.isMember(userA), isTrue);
      expect(circle.isMember('different_uid', 'bob@test.com'), isTrue);
      expect(circle.isMember('different_uid', 'BOB@TEST.COM'), isTrue);
      expect(circle.isMember('stranger_uid', 'stranger@test.com'), isFalse);

      // Verify Firestore serialization & deserialization
      final map = circle.toMap();
      expect(map['memberEmails'], isA<List>());
      expect((map['memberEmails'] as List).contains('bob@test.com'), isTrue);

      final reconstructed = MagicCircle.fromMap(map, 'circle_fam');
      expect(reconstructed.memberEmails, contains('bob@test.com'));
      expect(reconstructed.isMember('different_uid', 'bob@test.com'), isTrue);

      // Transition pending member to real UID
      final claimedMembers = reconstructed.members.map((m) {
        if (m.email.toLowerCase() == 'bob@test.com' && m.uid.startsWith('pending_')) {
          return m.copyWith(
            uid: userB,
            displayName: 'Bob M',
            status: 'active',
          );
        }
        return m;
      }).toList();

      final claimedCircle = reconstructed.copyWith(
        members: claimedMembers,
        memberUids: [userA, userB],
      );

      expect(claimedCircle.memberUids, contains(userB));
      expect(claimedCircle.isMember(userB), isTrue);
      final claimedBob = claimedCircle.members.firstWhere((m) => m.uid == userB);
      expect(claimedBob.status, equals('active'));
      expect(claimedBob.displayName, equals('Bob M'));
    });
  });
}
