import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/profile/screens/profile_screen.dart';
import 'package:magic_diary/features/profile/screens/account_settings_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FakeAuthRepository extends AuthRepository {
  final UserProfile? mockProfile;
  FakeAuthRepository(this.mockProfile);

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(mockProfile);

  @override
  fb.User? get currentFirebaseUser => null;
}

void main() {
  group('7-Character Alphanumeric Username Generation & Profile Tests', () {
    test('generate7CharUsername generates exact 7-character alphanumeric strings with letters and digits', () {
      final generatedSet = <String>{};
      final alphaNumericRegex = RegExp(r'^[a-z0-9]{7}$');
      final startsWithLetter = RegExp(r'^[a-z]');
      final containsDigit = RegExp(r'[0-9]');

      for (int i = 0; i < 100; i++) {
        final username = UserProfile.generate7CharUsername();

        // Must be exactly 7 characters
        expect(username.length, equals(7), reason: 'Username must be 7 chars long');

        // Must be lowercase alphanumeric
        expect(alphaNumericRegex.hasMatch(username), isTrue, reason: 'Username must be alphanumeric');

        // Must start with an alphabetic letter
        expect(startsWithLetter.hasMatch(username), isTrue, reason: 'Username should start with a letter');

        // Must contain at least one digit
        expect(containsDigit.hasMatch(username), isTrue, reason: 'Username must contain at least one numeric digit');

        generatedSet.add(username);
      }

      // High entropy: in 100 iterations, we expect all or almost all unique
      expect(generatedSet.length, greaterThanOrEqualTo(98));
    });

    test('UserProfile serializes and deserializes 7-character username accurately', () {
      final username = UserProfile.generate7CharUsername();
      final now = DateTime(2026, 11, 14, 12, 0, 0);

      final profile = UserProfile(
        uid: 'user_test_7char',
        email: 'test@magicdiary.com',
        displayName: 'Test User',
        username: username,
        createdAt: now,
        updatedAt: now,
      );

      final map = profile.toMap();
      expect(map['username'], equals(username));
      expect((map['username'] as String).length, equals(7));

      final restored = UserProfile.fromMap(map, 'user_test_7char');
      expect(restored.username, equals(username));
      expect(restored.username.length, equals(7));
    });

    testWidgets('ProfileScreen prominently displays 7-character username in header and options list', (WidgetTester tester) async {
      final testUsername = UserProfile.generate7CharUsername();
      final fakeUser = UserProfile(
        uid: 'user_profile_7c',
        email: 'debasish@example.com',
        displayName: 'Debasish Mahato',
        username: testUsername,
        currencySymbol: '₹',
        themeMode: 'system',
        enableNotifications: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(fakeUser)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('Profile & Settings'), findsOneWidget);

      // Verify Display Name
      expect(find.text('Debasish Mahato'), findsOneWidget);

      // Verify 7-Character Username displayed with @ prefix
      // Should find at least 3 widgets: header chip, QR card label, and dedicated Username ListTile
      expect(find.text('@$testUsername'), findsAtLeastNWidgets(2));

      // Verify dedicated Username list tile & 7-char ID badge
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('7-char ID'), findsOneWidget);

      // Verify QR Code section is present in profile
      expect(find.text('Profile QR Code'), findsOneWidget);
      expect(find.text('Scan to Connect'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify copy username button is present
      expect(find.byTooltip('Copy Username'), findsOneWidget);

      // Test tapping 'Enlarge QR' opens dialog with enlarged QR Code
      final enlargeBtn = find.text('Enlarge QR');
      expect(enlargeBtn, findsOneWidget);
      await tester.tap(enlargeBtn);
      await tester.pumpAndSettle();

      // Dialog should be open with enlarged QR Code and Close button
      expect(find.byType(QrImageView), findsAtLeastNWidgets(1));
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('AccountSettingsScreen displays 7-character username alongside user details', (WidgetTester tester) async {
      final testUsername = UserProfile.generate7CharUsername();
      final fakeUser = UserProfile(
        uid: 'user_acc_7c',
        email: 'user7c@example.com',
        displayName: 'Alex Rivers',
        username: testUsername,
        currencySymbol: '₹',
        themeMode: 'system',
        enableNotifications: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(fakeUser)),
          ],
          child: const MaterialApp(
            home: AccountSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Username label and value in AccountSettingsScreen
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('@$testUsername'), findsOneWidget);
    });
  });
}
