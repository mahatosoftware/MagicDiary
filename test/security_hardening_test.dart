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
  });
}
