import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/magic_circles/models/circle_candidate_member.dart';
import 'package:magic_diary/features/magic_circles/models/magic_circle_models.dart';
import 'package:magic_diary/features/magic_circles/providers/connected_users_provider.dart';
import 'package:magic_diary/features/magic_circles/widgets/circle_invite_ready_dialog.dart';
import 'package:magic_diary/features/shared_diaries/widgets/qr_code_scan_dialog.dart';

void main() {
  group('Circle Multi-Channel Sharing & Creation Test Suite', () {
    const ownerUid = 'user_owner_001';
    const ownerEmail = 'owner@example.com';
    const ownerName = 'Circle Owner';

    // -------------------------------------------------------------
    // Channel 1: Username Channel
    // -------------------------------------------------------------
    test('Channel 1: Username resolution builds active candidate member', () {
      const username = 'KYZMPTR';
      final usernameRegex = RegExp(r'^[A-NP-Z1-9]{7}$');
      expect(usernameRegex.hasMatch(username), isTrue);
      expect(usernameRegex.hasMatch('KYZM0TR'), isFalse, reason: 'No zero 0');
      expect(usernameRegex.hasMatch('KYZMOTR'), isFalse, reason: 'No letter O');
      expect(usernameRegex.hasMatch('kyzmptr'), isFalse, reason: 'Must be uppercase');

      const candidate = CircleCandidateMember(
        uid: 'user_alice_123',
        email: 'alice@magicdiary.internal',
        displayName: 'Alice M',
        username: username,
        role: CircleRole.contributor,
        status: 'active',
        channel: 'username',
      );

      expect(candidate.isRegisteredUser, isTrue);
      expect(candidate.channel, equals('username'));

      final member = candidate.toMagicCircleMember();
      expect(member.uid, equals('user_alice_123'));
      expect(member.status, equals('active'));
      expect(member.role, equals(CircleRole.contributor));
    });

    // -------------------------------------------------------------
    // Channel 2: QR Code Scan Channel
    // -------------------------------------------------------------
    test('Channel 2: QR code parser detects user profile and circle invite tokens', () {
      // 1. User profile deep link
      final profileQr = QrScanResult.parse(
          'magicdiary://user/KYZMPTR?uid=user_alice_123&name=Alice%20M&email=alice%40example.com');
      expect(profileQr.type, equals(QrScanType.username));
      expect(profileQr.value, equals('KYZMPTR'));
      expect(profileQr.uid, equals('user_alice_123'));
      expect(profileQr.displayName, equals('Alice M'));
      expect(profileQr.email, equals('alice@example.com'));

      // 2. Circle invite link
      final circleInviteQr = QrScanResult.parse('magicdiary://circle/invite/token-xyz-123');
      expect(circleInviteQr.type, equals(QrScanType.circleInviteToken));
      expect(circleInviteQr.value, equals('token-xyz-123'));

      // Candidate member from QR
      final qrCandidate = CircleCandidateMember(
        uid: profileQr.uid,
        email: profileQr.email!,
        displayName: profileQr.displayName!,
        username: profileQr.value,
        role: CircleRole.editor,
        status: 'active',
        channel: 'qr',
      );

      expect(qrCandidate.isRegisteredUser, isTrue);
      expect(qrCandidate.channel, equals('qr'));
      expect(qrCandidate.role, equals(CircleRole.editor));
    });

    // -------------------------------------------------------------
    // Channel 3: Email Channel
    // -------------------------------------------------------------
    test('Channel 3: Email input creates invited candidate with pending UID fallback', () {
      const email = 'new_friend@example.com';
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      expect(emailRegex.hasMatch(email), isTrue);

      const candidate = CircleCandidateMember(
        email: email,
        displayName: 'new_friend',
        role: CircleRole.viewer,
        status: 'invited',
        channel: 'email',
      );

      expect(candidate.isRegisteredUser, isFalse);
      expect(candidate.channel, equals('email'));

      final member = candidate.toMagicCircleMember();
      expect(member.uid, equals('pending_new_friend@example.com'));
      expect(member.status, equals('invited'));
      expect(member.role, equals(CircleRole.viewer));
    });

    // -------------------------------------------------------------
    // Channel 4: Frequently Used Contacts Channel
    // -------------------------------------------------------------
    test('Channel 4: Frequent contact selection creates candidate member', () {
      const candidate = CircleCandidateMember(
        email: 'frequent.colleague@company.com',
        displayName: 'Colleague Bob',
        username: 'BOB789X',
        role: CircleRole.contributor,
        status: 'invited',
        channel: 'contacts',
      );

      expect(candidate.channel, equals('contacts'));
      expect(candidate.displayName, equals('Colleague Bob'));
      expect(candidate.username, equals('BOB789X'));
    });

    // -------------------------------------------------------------
    // Channel 5: Shareable Invite Link Channel
    // -------------------------------------------------------------
    test('Channel 5: CircleInviteReadyDialog formats deep link and WhatsApp / SMS messages', () {
      const circleId = 'circle_goa_trip_2026';
      const circleName = 'Goa Trip 2026';
      const token = 'token-secure-abc-987';

      const dialog = CircleInviteReadyDialog(
        circleId: circleId,
        circleName: circleName,
        token: token,
      );

      expect(dialog.deepLink, equals('https://magicdiary.mahato.in/join/token-secure-abc-987'));
      expect(dialog.shareMessage, contains('Goa Trip 2026'));
      expect(dialog.shareMessage, contains('https://magicdiary.mahato.in/join/token-secure-abc-987'));
    });

    // -------------------------------------------------------------
    // Channel 6: Existing Connected Users Channel
    // -------------------------------------------------------------
    test('Channel 6: ConnectedUser aggregates previous collaborators with origin context', () {
      const connectedUser = ConnectedUser(
        uid: 'user_charlie_555',
        email: 'charlie@family.org',
        displayName: 'Charlie Uncle',
        username: 'CHARLIE',
        sourceDescription: 'Member of "Family Circle"',
        interactionCount: 7,
      );

      expect(connectedUser.sourceDescription, contains('Family Circle'));
      expect(connectedUser.interactionCount, equals(7));

      final candidate = CircleCandidateMember(
        uid: connectedUser.uid,
        email: connectedUser.email,
        displayName: connectedUser.displayName,
        username: connectedUser.username,
        role: CircleRole.admin,
        status: 'active',
        channel: 'existing_users',
      );

      expect(candidate.isRegisteredUser, isTrue);
      expect(candidate.channel, equals('existing_users'));
      expect(candidate.role, equals(CircleRole.admin));
    });

    // -------------------------------------------------------------
    // Multi-Channel Circle Creation & Automatic Member Indexing
    // -------------------------------------------------------------
    test('Circle Creation with members from all channels populates memberUids and memberEmails correctly', () {
      final now = DateTime.now();

      final ownerMember = MagicCircleMember(
        uid: ownerUid,
        email: ownerEmail,
        displayName: ownerName,
        role: CircleRole.owner,
        joinedAt: now,
        status: 'active',
      );

      const candidates = [
        // 1. Username
        CircleCandidateMember(
          uid: 'user_alice_123',
          email: 'alice@test.com',
          displayName: 'Alice',
          username: 'ALICE12',
          role: CircleRole.editor,
          status: 'active',
          channel: 'username',
        ),
        // 2. QR Code
        CircleCandidateMember(
          uid: 'user_bob_456',
          email: 'bob@test.com',
          displayName: 'Bob',
          username: 'BOB3456',
          role: CircleRole.contributor,
          status: 'active',
          channel: 'qr',
        ),
        // 3. Email
        CircleCandidateMember(
          email: 'new_user@test.com',
          displayName: 'New User',
          role: CircleRole.viewer,
          status: 'invited',
          channel: 'email',
        ),
        // 4. Contacts
        CircleCandidateMember(
          email: 'contact@test.com',
          displayName: 'Contact Dave',
          role: CircleRole.contributor,
          status: 'invited',
          channel: 'contacts',
        ),
        // 6. Existing Connected User
        CircleCandidateMember(
          uid: 'user_charlie_789',
          email: 'charlie@test.com',
          displayName: 'Charlie',
          role: CircleRole.admin,
          status: 'active',
          channel: 'existing_users',
        ),
      ];

      final members = [
        ownerMember,
        ...candidates.map((c) => c.toMagicCircleMember(joinedAt: now)),
      ];

      final circle = MagicCircle(
        id: 'circle_test_multi_channel',
        name: 'Omnichannel Test Circle',
        description: 'Testing all 6 channels',
        category: CircleCategory.family,
        ownerId: ownerUid,
        members: members,
        createdAt: now,
        updatedAt: now,
      );

      // Verify member count
      expect(circle.members.length, equals(6));

      // Verify memberUids contains ONLY real UIDs (including owner) and NO pending_ UIDs
      expect(circle.memberUids, containsAll([ownerUid, 'user_alice_123', 'user_bob_456', 'user_charlie_789']));
      expect(circle.memberUids.any((uid) => uid.startsWith('pending_')), isFalse);
      expect(circle.memberUids.length, equals(4));

      // Verify memberEmails contains all 6 member emails
      expect(
        circle.memberEmails,
        containsAll([
          ownerEmail.toLowerCase(),
          'alice@test.com',
          'bob@test.com',
          'new_user@test.com',
          'contact@test.com',
          'charlie@test.com',
        ]),
      );
      expect(circle.memberEmails.length, equals(6));

      // Verify candidate equality and deduplication
      const duplicateAlice = CircleCandidateMember(
        uid: 'user_alice_123',
        email: 'different_email@test.com',
        displayName: 'Alice Duplicate',
        channel: 'email',
      );
      expect(candidates.contains(duplicateAlice), isTrue);
    });

    // -------------------------------------------------------------
    // UI Dialog Widget Test
    // -------------------------------------------------------------
    testWidgets('CircleInviteReadyDialog renders deep link, QR code, and copy actions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircleInviteReadyDialog(
              circleId: 'circle_widget_test',
              circleName: 'Test Family',
              token: 'test-token-12345',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Circle Invite Link Ready!'), findsOneWidget);
      expect(find.textContaining('Test Family'), findsWidgets);
      expect(find.text('https://magicdiary.mahato.in/join/test-token-12345'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS / Other'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
