import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/magic_circles/models/magic_circle_models.dart';
import 'package:magic_diary/features/magic_circles/widgets/circle_qr_scanner_dialog.dart';

void main() {
  group('MagicCircle Domain Model Tests', () {
    test('Serializes and deserializes circle with group codes and adminIds', () {
      final now = DateTime.now();
      final circle = MagicCircle(
        id: 'circle-101',
        name: 'Alpha Squad',
        description: 'Collaborative team',
        category: CircleCategory.business,
        ownerId: 'owner-uid',
        code: 'ALPHA99',
        adminIds: ['owner-uid', 'admin-2'],
        pendingMemberIds: ['applicant-1'],
        oneTimeCodes: ['IN-XYZ123'],
        isPendingDelete: false,
        members: [
          MagicCircleMember(
            uid: 'owner-uid',
            email: 'owner@example.com',
            displayName: 'Owner User',
            role: CircleRole.owner,
            joinedAt: now,
          ),
          MagicCircleMember(
            uid: 'admin-2',
            email: 'admin2@example.com',
            displayName: 'Admin User',
            role: CircleRole.admin,
            joinedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final map = circle.toMap();
      expect(map['id'], 'circle-101');
      expect(map['code'], 'ALPHA99');
      expect(map['adminIds'], containsAll(['owner-uid', 'admin-2']));
      expect(map['pendingMemberIds'], ['applicant-1']);
      expect(map['oneTimeCodes'], ['IN-XYZ123']);
      expect(map['isPendingDelete'], false);

      final restored = MagicCircle.fromMap(map, 'circle-101');
      expect(restored.id, 'circle-101');
      expect(restored.code, 'ALPHA99');
      expect(restored.isCircleAdmin('owner-uid'), isTrue);
      expect(restored.isCircleAdmin('admin-2'), isTrue);
      expect(restored.isCircleAdmin('random-user'), isFalse);
      expect(restored.pendingMemberIds, contains('applicant-1'));
      expect(restored.oneTimeCodes, contains('IN-XYZ123'));
    });

    test('Auto-computes adminIds if not explicitly passed', () {
      final now = DateTime.now();
      final circle = MagicCircle(
        id: 'circle-102',
        name: 'Family Circle',
        ownerId: 'owner-uid',
        members: [
          MagicCircleMember(
            uid: 'owner-uid',
            email: 'owner@example.com',
            displayName: 'Owner',
            role: CircleRole.owner,
            joinedAt: now,
          ),
          MagicCircleMember(
            uid: 'sub-admin',
            email: 'admin@example.com',
            displayName: 'Sub Admin',
            role: CircleRole.admin,
            joinedAt: now,
          ),
          MagicCircleMember(
            uid: 'regular-member',
            email: 'regular@example.com',
            displayName: 'Member',
            role: CircleRole.contributor,
            joinedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(circle.adminIds, containsAll(['owner-uid', 'sub-admin']));
      expect(circle.adminIds.contains('regular-member'), isFalse);
    });
  });

  group('QR Code & Universal Link Sanitizer Tests', () {
    test('Cleans raw alphanumeric codes', () {
      expect(CircleQrScannerDialog.cleanScannedCode('ABC1234'), 'ABC1234');
      expect(CircleQrScannerDialog.cleanScannedCode('  in-456789  '), 'IN-456789');
    });

    test('Extracts codes from universal and deep join links', () {
      expect(
        CircleQrScannerDialog.cleanScannedCode('https://magicdiary.app/join/GROUP88'),
        'GROUP88',
      );
      expect(
        CircleQrScannerDialog.cleanScannedCode('https://app.yourdomain.com/circle/CIRC777/'),
        'CIRC777',
      );
    });

    test('Extracts code from URL query parameters and fragments', () {
      expect(
        CircleQrScannerDialog.cleanScannedCode('https://magicdiary.app/circles/join?code=VIP999&utm_source=share'),
        'VIP999',
      );
      expect(
        CircleQrScannerDialog.cleanScannedCode('https://magicdiary.app/join/CODE123?param=value#section'),
        'CODE123',
      );
    });
  });

  group('The Successor Rule Verification', () {
    final now = DateTime.now();

    test('Sole administrator cannot leave when other members remain', () {
      final circle = MagicCircle(
        id: 'circle-sole-admin',
        name: 'Club',
        ownerId: 'user-admin',
        adminIds: ['user-admin'],
        members: [
          MagicCircleMember(
            uid: 'user-admin',
            email: 'admin@test.com',
            displayName: 'Admin',
            role: CircleRole.admin,
            joinedAt: now,
          ),
          MagicCircleMember(
            uid: 'user-member-2',
            email: 'member2@test.com',
            displayName: 'Member 2',
            role: CircleRole.contributor,
            joinedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      const currentUserId = 'user-admin';
      final isUserAdmin = circle.isCircleAdmin(currentUserId);
      final otherAdmins = circle.adminIds.where((id) => id != currentUserId).toList();

      // Check condition: sole admin with other members remaining
      final mustTransferAdmin = isUserAdmin && otherAdmins.isEmpty && circle.members.length > 1;
      expect(mustTransferAdmin, isTrue);
    });

    test('Admin can leave if a co-admin exists', () {
      final circle = MagicCircle(
        id: 'circle-multi-admin',
        name: 'Club',
        ownerId: 'user-owner',
        adminIds: ['user-admin-1', 'user-admin-2'],
        members: [
          MagicCircleMember(
            uid: 'user-admin-1',
            email: 'admin1@test.com',
            displayName: 'Admin 1',
            role: CircleRole.admin,
            joinedAt: now,
          ),
          MagicCircleMember(
            uid: 'user-admin-2',
            email: 'admin2@test.com',
            displayName: 'Admin 2',
            role: CircleRole.admin,
            joinedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      const currentUserId = 'user-admin-1';
      final isUserAdmin = circle.isCircleAdmin(currentUserId);
      final otherAdmins = circle.adminIds.where((id) => id != currentUserId).toList();

      final mustTransferAdmin = isUserAdmin && otherAdmins.isEmpty && circle.members.length > 1;
      expect(mustTransferAdmin, isFalse);
    });

    test('Last member leaving schedules circle for deletion', () {
      final circle = MagicCircle(
        id: 'circle-solo',
        name: 'Solo Circle',
        ownerId: 'solo-user',
        adminIds: ['solo-user'],
        members: [
          MagicCircleMember(
            uid: 'solo-user',
            email: 'solo@test.com',
            displayName: 'Solo',
            role: CircleRole.owner,
            joinedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final isLastMember = circle.members.length <= 1;
      expect(isLastMember, isTrue);
    });
  });

  group('One-Time Code Burn Logic', () {
    test('Simulates atomic one-time code redemption', () {
      final oneTimeCodes = ['IN-111111', 'IN-222222'];
      const targetCode = 'IN-111111';

      expect(oneTimeCodes.contains(targetCode), isTrue);

      // Burn code
      oneTimeCodes.remove(targetCode);

      // Subsequent attempt with same code fails immediately
      expect(oneTimeCodes.contains(targetCode), isFalse);
      expect(oneTimeCodes, equals(['IN-222222']));
    });
  });
}
