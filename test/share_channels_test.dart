import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/shared_diaries/models/shared_diary_models.dart';
import 'package:magic_diary/features/shared_diaries/repositories/shared_diary_repository.dart';
import 'package:magic_diary/features/shared_diaries/screens/claim_share_invite_screen.dart';
import 'package:magic_diary/features/shared_diaries/widgets/invite_link_ready_dialog.dart';
import 'package:magic_diary/features/shared_diaries/widgets/qr_code_scan_dialog.dart';

class FakeSharedDiaryRepository extends SharedDiaryRepository {
  final Map<String, OneTimeShareInvite> invites = {};
  final Map<String, UserProfile> usersByUsername = {};
  final Map<String, SharedDiaryAccess> shares = {};

  @override
  Future<UserProfile?> lookupUserByUsername(
    String username, {
    String? uidHint,
    String? displayNameHint,
    String? emailHint,
  }) async {
    if (uidHint != null && usersByUsername.values.any((u) => u.uid == uidHint)) {
      return usersByUsername.values.firstWhere((u) => u.uid == uidHint);
    }
    final clean = username.trim().replaceAll('@', '').toUpperCase();
    return usersByUsername[clean] ?? usersByUsername[clean.toLowerCase()];
  }

  @override
  Future<OneTimeShareInvite> createOneTimeShareInvite(OneTimeShareInvite invite) async {
    invites[invite.id] = invite;
    return invite;
  }

  @override
  Future<OneTimeShareInvite?> getShareInvite(String token) async {
    return invites[token];
  }

  @override
  Future<SharedDiaryAccess> claimOneTimeInvite({
    required String token,
    required UserProfile recipientUser,
  }) async {
    final invite = invites[token];
    if (invite == null) {
      throw Exception('Invite link not found or invalid.');
    }

    if (invite.ownerUid == recipientUser.uid) {
      throw Exception('You cannot claim your own share invite link.');
    }

    if (invite.isClaimed) {
      throw Exception('This invite link has already been used and cannot be claimed again.');
    }

    if (invite.isExpired) {
      throw Exception('This invite link has expired.');
    }

    final now = DateTime.now();
    final updatedInvite = OneTimeShareInvite(
      id: invite.id,
      diaryId: invite.diaryId,
      diaryName: invite.diaryName,
      ownerUid: invite.ownerUid,
      ownerName: invite.ownerName,
      permission: invite.permission,
      sharingMode: invite.sharingMode,
      grantedRecordIds: invite.grantedRecordIds,
      allowAttachments: invite.allowAttachments,
      allowComments: invite.allowComments,
      allowExport: invite.allowExport,
      restrictedFields: invite.restrictedFields,
      isOneTime: true,
      isClaimed: true,
      claimedByUid: recipientUser.uid,
      claimedByEmail: recipientUser.email,
      claimedByName: recipientUser.displayName,
      claimedAt: now,
      expiresAt: invite.expiresAt,
      createdAt: invite.createdAt,
      updatedAt: now,
    );
    invites[token] = updatedInvite;

    final primaryDocId = SharedDiaryRepository.generateShareId(
      ownerUid: invite.ownerUid,
      diaryId: invite.diaryId,
      target: recipientUser.email.isNotEmpty ? recipientUser.email : recipientUser.uid,
    );

    final access = SharedDiaryAccess(
      id: primaryDocId,
      diaryId: invite.diaryId,
      diaryName: invite.diaryName,
      ownerUid: invite.ownerUid,
      ownerName: invite.ownerName,
      recipientType: RecipientType.user,
      sharingMode: invite.sharingMode,
      futureRecordPolicy: FutureRecordPolicy.allFuture,
      sharedWithUid: recipientUser.uid,
      sharedWithEmail: recipientUser.email.toLowerCase(),
      sharedWithName: recipientUser.displayName,
      permission: invite.permission,
      shareEntireDiary: invite.sharingMode == SharingMode.entire,
      grantedRecordIds: invite.grantedRecordIds,
      allowAttachments: invite.allowAttachments,
      allowComments: invite.allowComments,
      allowExport: invite.allowExport,
      restrictedFields: invite.restrictedFields,
      status: ShareStatus.active,
      createdAt: now,
      updatedAt: now,
    );

    shares[primaryDocId] = access;
    return access;
  }
}

class FakeUserNotifier extends UserNotifier {
  FakeUserNotifier(super.ref, UserProfile initialProfile) {
    state = initialProfile;
  }
}

class FakeAuthRepo extends AuthRepository {
  final UserProfile user;
  FakeAuthRepo(this.user);

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(user);
}

void main() {
  group('QR Code Scanner Parsing Tests', () {
    test('parses deep link magicdiary://share/invite/:token correctly', () {
      final res = QrScanResult.parse('magicdiary://share/invite/test-token-12345');
      expect(res.type, equals(QrScanType.inviteToken));
      expect(res.value, equals('test-token-12345'));
    });

    test('parses web link https://magicdiary.app/share/invite/:token correctly', () {
      final res = QrScanResult.parse('https://magicdiary.app/share/invite/web-token-99999');
      expect(res.type, equals(QrScanType.inviteToken));
      expect(res.value, equals('web-token-99999'));
    });

    test('parses user deep link magicdiary://user/:username correctly into uppercase', () {
      final res = QrScanResult.parse('magicdiary://user/k990ek5');
      expect(res.type, equals(QrScanType.username));
      expect(res.value, equals('K990EK5'));
    });

    test('parses @username string correctly into uppercase', () {
      final res = QrScanResult.parse('@alice77');
      expect(res.type, equals(QrScanType.username));
      expect(res.value, equals('ALICE77'));
    });

    test('parses exact 7-char username without @ prefix correctly into uppercase', () {
      final res = QrScanResult.parse('y3xm72b');
      expect(res.type, equals(QrScanType.username));
      expect(res.value, equals('Y3XM72B'));
    });

    test('parses standard email address correctly', () {
      final res = QrScanResult.parse('partner@example.com');
      expect(res.type, equals(QrScanType.email));
      expect(res.value, equals('partner@example.com'));
    });

    test('parses rich user deep link with metadata query parameters correctly', () {
      final res = QrScanResult.parse('magicdiary://user/KYZMPTR?uid=user_123&name=Bob%20Smith&email=bob%40example.com');
      expect(res.type, equals(QrScanType.username));
      expect(res.value, equals('KYZMPTR'));
      expect(res.uid, equals('user_123'));
      expect(res.displayName, equals('Bob Smith'));
      expect(res.email, equals('bob@example.com'));
    });

    test('parses JSON payload QR code correctly', () {
      final res = QrScanResult.parse('{"username":"KYZMPTR","uid":"user_123","displayName":"Bob Smith","email":"bob@example.com"}');
      expect(res.type, equals(QrScanType.username));
      expect(res.value, equals('KYZMPTR'));
      expect(res.uid, equals('user_123'));
      expect(res.displayName, equals('Bob Smith'));
      expect(res.email, equals('bob@example.com'));
    });

    test('parses raw UUID token as inviteToken', () {
      final res = QrScanResult.parse('c4a3b2c1-d4e5-6f7a-8b9c-0d1e2f3a4b5c');
      expect(res.type, equals(QrScanType.inviteToken));
      expect(res.value, equals('c4a3b2c1-d4e5-6f7a-8b9c-0d1e2f3a4b5c'));
    });

    test('parses email address with mailto: prefix correctly', () {
      final res = QrScanResult.parse('mailto:partner@example.com');
      expect(res.type, equals(QrScanType.email));
      expect(res.value, equals('partner@example.com'));
    });

    test('handles fallback plain text gracefully', () {
      final res = QrScanResult.parse('random note string with spaces');
      expect(res.type, equals(QrScanType.raw));
      expect(res.value, equals('random note string with spaces'));
    });
  });

  group('OneTimeShareInvite Model & Invariant Tests', () {
    test('generates valid deep link and web link URLs', () {
      final invite = OneTimeShareInvite(
        id: 'token_abc123',
        diaryId: 'bill_payment',
        diaryName: 'Bills & Utilities',
        ownerUid: 'owner_user_1',
        ownerName: 'Alice Smith',
        permission: SharedDiaryPermission.editor,
        createdAt: DateTime(2026, 11, 15),
      );

      expect(invite.deepLink, equals('https://magicdiary.mahato.in/join/token_abc123'));
      expect(invite.webLink, equals('https://magicdiary.mahato.in/join/token_abc123'));
      expect(invite.isOneTime, isTrue);
      expect(invite.isClaimed, isFalse);
      expect(invite.isExpired, isFalse);
      expect(invite.canBeClaimed, isTrue);
    });

    test('serializes to Map and deserializes from Map accurately', () {
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 7));
      final invite = OneTimeShareInvite(
        id: 'token_serialization_test',
        diaryId: 'vehicle_maintenance',
        diaryName: 'Vehicle Maintenance',
        ownerUid: 'uid_owner',
        ownerName: 'Bob Builder',
        permission: SharedDiaryPermission.contributor,
        sharingMode: SharingMode.selected,
        grantedRecordIds: ['rec_1', 'rec_2'],
        allowAttachments: true,
        allowComments: false,
        allowExport: true,
        restrictedFields: ['cost'],
        isOneTime: true,
        isClaimed: false,
        expiresAt: expiry,
        createdAt: now,
      );

      final map = invite.toMap();
      expect(map['id'], equals('token_serialization_test'));
      expect(map['diaryId'], equals('vehicle_maintenance'));
      expect(map['permission'], equals('contributor'));
      expect(map['sharingMode'], equals('selected'));
      expect(map['grantedRecordIds'], equals(['rec_1', 'rec_2']));
      expect(map['isOneTime'], isTrue);
      expect(map['isClaimed'], isFalse);

      final reconstructed = OneTimeShareInvite.fromMap(map, 'token_serialization_test');
      expect(reconstructed.id, equals('token_serialization_test'));
      expect(reconstructed.diaryId, equals('vehicle_maintenance'));
      expect(reconstructed.permission, equals(SharedDiaryPermission.contributor));
      expect(reconstructed.sharingMode, equals(SharingMode.selected));
      expect(reconstructed.grantedRecordIds, equals(['rec_1', 'rec_2']));
      expect(reconstructed.allowComments, isFalse);
      expect(reconstructed.allowExport, isTrue);
    });

    test('detects expired invitation and disables claim eligibility', () {
      final expiredInvite = OneTimeShareInvite(
        id: 'token_expired',
        diaryId: 'health_wellness',
        diaryName: 'Health & Wellness',
        ownerUid: 'owner_user_1',
        ownerName: 'Alice',
        permission: SharedDiaryPermission.viewer,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(expiredInvite.isExpired, isTrue);
      expect(expiredInvite.canBeClaimed, isFalse);
    });

    test('detects claimed invitation and disables re-claiming', () {
      final claimedInvite = OneTimeShareInvite(
        id: 'token_claimed',
        diaryId: 'health_wellness',
        diaryName: 'Health & Wellness',
        ownerUid: 'owner_user_1',
        ownerName: 'Alice',
        permission: SharedDiaryPermission.viewer,
        isClaimed: true,
        claimedByUid: 'recipient_uid_2',
        claimedByName: 'Charlie',
        claimedAt: DateTime.now(),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(claimedInvite.isClaimed, isTrue);
      expect(claimedInvite.canBeClaimed, isFalse);
    });
  });

  group('SharedDiaryRepository Multi-Channel & Atomic Claim Invariants', () {
    late FakeSharedDiaryRepository repo;
    final owner = UserProfile(
      uid: 'owner_uid_100',
      email: 'owner@example.com',
      displayName: 'Alice Owner',
      username: 'ALICE99',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final recipient = UserProfile(
      uid: 'recipient_uid_200',
      email: 'bob@example.com',
      displayName: 'Bob Recipient',
      username: 'BOB8888',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      repo = FakeSharedDiaryRepository();
      repo.usersByUsername['ALICE99'] = owner;
      repo.usersByUsername['BOB8888'] = recipient;
    });

    test('lookupUserByUsername finds registered users by exact 7-char alphanumeric username', () async {
      final found = await repo.lookupUserByUsername('bob8888');
      expect(found, isNotNull);
      expect(found!.uid, equals('recipient_uid_200'));
      expect(found.displayName, equals('Bob Recipient'));

      final withAt = await repo.lookupUserByUsername('@alice99');
      expect(withAt, isNotNull);
      expect(withAt!.uid, equals('owner_uid_100'));

      final notFound = await repo.lookupUserByUsername('nonexistent');
      expect(notFound, isNull);
    });

    test('claims one-time invite on first invocation and grants SharedDiaryAccess', () async {
      final invite = OneTimeShareInvite(
        id: 'one_time_token_1',
        diaryId: 'bill_payment',
        diaryName: 'Bills & Utilities',
        ownerUid: owner.uid,
        ownerName: owner.displayName,
        permission: SharedDiaryPermission.editor,
        createdAt: DateTime.now(),
      );
      await repo.createOneTimeShareInvite(invite);

      // Verify invite stored
      final fetched = await repo.getShareInvite('one_time_token_1');
      expect(fetched, isNotNull);
      expect(fetched!.canBeClaimed, isTrue);

      // First claim succeeds
      final access = await repo.claimOneTimeInvite(
        token: 'one_time_token_1',
        recipientUser: recipient,
      );

      expect(access.ownerUid, equals(owner.uid));
      expect(access.sharedWithUid, equals(recipient.uid));
      expect(access.diaryId, equals('bill_payment'));
      expect(access.permission, equals(SharedDiaryPermission.editor));

      // Invite is now marked claimed
      final afterClaim = await repo.getShareInvite('one_time_token_1');
      expect(afterClaim!.isClaimed, isTrue);
      expect(afterClaim.claimedByUid, equals(recipient.uid));
      expect(afterClaim.canBeClaimed, isFalse);
    });

    test('atomic transaction rejects second attempt with already-claimed error', () async {
      final invite = OneTimeShareInvite(
        id: 'one_time_token_2',
        diaryId: 'personal_finance',
        diaryName: 'Personal Finance',
        ownerUid: owner.uid,
        ownerName: owner.displayName,
        permission: SharedDiaryPermission.viewer,
        createdAt: DateTime.now(),
      );
      await repo.createOneTimeShareInvite(invite);

      // First claim
      await repo.claimOneTimeInvite(
        token: 'one_time_token_2',
        recipientUser: recipient,
      );

      // Second claim attempt MUST throw exception to guarantee single-use invariant
      final thirdParty = UserProfile(
        uid: 'third_party_300',
        email: 'charlie@example.com',
        displayName: 'Charlie',
        username: 'charl99',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => repo.claimOneTimeInvite(
          token: 'one_time_token_2',
          recipientUser: thirdParty,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('already been used and cannot be claimed again'),
        )),
      );
    });

    test('rejects claiming by the owner themselves', () async {
      final invite = OneTimeShareInvite(
        id: 'one_time_token_3',
        diaryId: 'subscriptions',
        diaryName: 'Subscriptions',
        ownerUid: owner.uid,
        ownerName: owner.displayName,
        permission: SharedDiaryPermission.admin,
        createdAt: DateTime.now(),
      );
      await repo.createOneTimeShareInvite(invite);

      expect(
        () => repo.claimOneTimeInvite(
          token: 'one_time_token_3',
          recipientUser: owner,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('cannot claim your own share invite link'),
        )),
      );
    });

    test('rejects claiming an expired invite link', () async {
      final invite = OneTimeShareInvite(
        id: 'one_time_token_4',
        diaryId: 'subscriptions',
        diaryName: 'Subscriptions',
        ownerUid: owner.uid,
        ownerName: owner.displayName,
        permission: SharedDiaryPermission.admin,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await repo.createOneTimeShareInvite(invite);

      expect(
        () => repo.claimOneTimeInvite(
          token: 'one_time_token_4',
          recipientUser: recipient,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('invite link has expired'),
        )),
      );
    });
  });

  group('InviteLinkReadyDialog & ClaimShareInviteScreen UI Tests', () {
    testWidgets('InviteLinkReadyDialog displays one-time deep link, QR code, and copy button', (tester) async {
      final invite = OneTimeShareInvite(
        id: 'dialog_token_xyz',
        diaryId: 'bill_payment',
        diaryName: 'Bills & Utilities',
        ownerUid: 'uid_1',
        ownerName: 'Alice',
        permission: SharedDiaryPermission.editor,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => InviteLinkReadyDialog.show(ctx, invite),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify Dialog header
      expect(find.text('One-Time Invite Link Ready!'), findsOneWidget);

      // Verify Diary name in dialog subtitle
      expect(find.textContaining('Bills & Utilities'), findsOneWidget);

      // Verify Deep link URL is displayed
      expect(find.text('https://magicdiary.mahato.in/join/dialog_token_xyz'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Tap Done closes dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('One-Time Invite Link Ready!'), findsNothing);
    });

    testWidgets('ClaimShareInviteScreen renders unclaimed invite and allows claiming', (tester) async {
      final repo = FakeSharedDiaryRepository();
      final recipient = UserProfile(
        uid: 'claim_recipient_1',
        email: 'claim@example.com',
        displayName: 'Claim Recipient',
        username: 'recip01',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final invite = OneTimeShareInvite(
        id: 'valid_claim_token',
        diaryId: 'bill_payment',
        diaryName: 'Bills & Utilities',
        ownerUid: 'owner_user_77',
        ownerName: 'Sarah Connor',
        permission: SharedDiaryPermission.editor,
        createdAt: DateTime.now(),
      );
      await repo.createOneTimeShareInvite(invite);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepo(recipient)),
            sharedDiaryRepositoryProvider.overrideWithValue(repo),
            userProfileProvider.overrideWith((ref) => FakeUserNotifier(ref, recipient)),
          ],
          child: const MaterialApp(
            home: ClaimShareInviteScreen(token: 'valid_claim_token'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify invitation UI details
      expect(find.text('Shared Diary Invitation'), findsOneWidget);
      expect(find.text('Bills & Utilities'), findsOneWidget);
      expect(find.text('Shared by Sarah Connor'), findsOneWidget);
      expect(find.text('Editor (Add & Edit)'), findsOneWidget);
      expect(find.text('One-Time Usable Deep Link'), findsOneWidget);
      expect(find.text('Accept & Claim Access'), findsOneWidget);

      // Tap Accept & Claim Access
      await tester.tap(find.text('Accept & Claim Access'));
      await tester.pumpAndSettle();

      // Repository invite should now be claimed
      final updatedInvite = await repo.getShareInvite('valid_claim_token');
      expect(updatedInvite!.isClaimed, isTrue);
      expect(updatedInvite.claimedByUid, equals(recipient.uid));
    });

    testWidgets('ClaimShareInviteScreen displays already claimed state when link was used', (tester) async {
      final repo = FakeSharedDiaryRepository();
      final recipient = UserProfile(
        uid: 'claim_recipient_2',
        email: 'recipient2@example.com',
        displayName: 'Recipient Two',
        username: 'recip02',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final claimedInvite = OneTimeShareInvite(
        id: 'already_claimed_token',
        diaryId: 'bill_payment',
        diaryName: 'Bills & Utilities',
        ownerUid: 'owner_user_77',
        ownerName: 'Sarah Connor',
        permission: SharedDiaryPermission.viewer,
        isClaimed: true,
        claimedByUid: 'other_user_99',
        claimedByName: 'Someone Else',
        claimedAt: DateTime.now().subtract(const Duration(hours: 2)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await repo.createOneTimeShareInvite(claimedInvite);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepo(recipient)),
            sharedDiaryRepositoryProvider.overrideWithValue(repo),
            userProfileProvider.overrideWith((ref) => FakeUserNotifier(ref, recipient)),
          ],
          child: const MaterialApp(
            home: ClaimShareInviteScreen(token: 'already_claimed_token'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify claimed warning banner
      expect(find.textContaining('already been claimed'), findsOneWidget);
      expect(find.text('Accept & Claim Access'), findsNothing);
    });
  });
}
