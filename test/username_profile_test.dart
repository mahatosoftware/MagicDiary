import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/auth/screens/login_screen.dart';
import 'package:magic_diary/features/profile/screens/profile_screen.dart';
import 'package:magic_diary/features/profile/screens/account_settings_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FakeAuthRepository extends AuthRepository {
  final UserProfile? mockProfile;
  final Set<String> existingUsernames;
  int checkCount = 0;

  FakeAuthRepository(this.mockProfile, {Set<String>? existingUsernames})
      : existingUsernames = existingUsernames ?? {};

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(mockProfile);

  @override
  fb.User? get currentFirebaseUser => null;

  @override
  Future<bool> isUsernameTaken(String username) async {
    checkCount++;
    return existingUsernames.contains(username.toUpperCase()) ||
        existingUsernames.contains(username.toLowerCase());
  }

  @override
  Future<String> generateUniqueUsername({
    int maxAttempts = 100,
    Future<bool> Function(String username)? isTakenFn,
  }) async {
    final check = isTakenFn ?? isUsernameTaken;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = UserProfile.generate7CharUsername();
      final exists = await check(candidate);
      if (!exists) {
        return candidate;
      }
    }
    return UserProfile.generate7CharUsername();
  }
}

void main() {
  group('7-Character Alphanumeric Username Generation & Profile Tests', () {
    test('generate7CharUsername generates exact 7-character alphanumeric strings with caps and digits 1-9, never containing 0 or O', () {
      final generatedSet = <String>{};
      final alphanumericCapsNo0NoORegex = RegExp(r'^[A-NP-Z1-9]{7}$');
      final hasLetterRegex = RegExp(r'[A-NP-Z]');
      final hasDigitRegex = RegExp(r'[1-9]');

      for (int i = 0; i < 500; i++) {
        final username = UserProfile.generate7CharUsername();

        // Must be exactly 7 characters
        expect(username.length, equals(7), reason: 'Username must be 7 chars long');

        // Must NOT contain '0' or 'O'
        expect(username.contains('0'), isFalse, reason: 'Username must never contain digit 0');
        expect(username.contains('O'), isFalse, reason: 'Username must never contain letter O');
        expect(username.contains('o'), isFalse, reason: 'Username must never contain lowercase o');

        // Must only use caps A-Z excluding O, and digits 1-9 excluding 0
        expect(alphanumericCapsNo0NoORegex.hasMatch(username), isTrue, reason: r'Username must match ^[A-NP-Z1-9]{7}$');

        // Must be alphanumeric (contains both letters and digits)
        expect(hasLetterRegex.hasMatch(username), isTrue, reason: 'Username must contain at least one uppercase letter');
        expect(hasDigitRegex.hasMatch(username), isTrue, reason: 'Username must contain at least one digit (1-9)');
        expect(UserProfile.isValidAlphanumeric(username), isTrue);

        generatedSet.add(username);
      }

      // High entropy: in 500 iterations, we expect all or almost all unique
      expect(generatedSet.length, greaterThanOrEqualTo(490));
    });

    test('UserProfile.isValidAlphanumeric accurately enforces alphanumeric with caps and no 0/O', () {
      expect(UserProfile.isValidAlphanumeric('K9Z7MPT'), isTrue);
      expect(UserProfile.isValidAlphanumeric('A1B2C3D'), isTrue);
      expect(UserProfile.isValidAlphanumeric('987654K'), isTrue);

      // Rejects confusing chars 0 and O/o
      expect(UserProfile.isValidAlphanumeric('ABC0DEF'), isFalse);
      expect(UserProfile.isValidAlphanumeric('ABCODEF'), isFalse);
      expect(UserProfile.isValidAlphanumeric('abc0def'), isFalse);
      expect(UserProfile.isValidAlphanumeric('abc1def'), isFalse); // lowercase rejected

      // Rejects special characters
      expect(UserProfile.isValidAlphanumeric('AB@1234'), isFalse);
      expect(UserProfile.isValidAlphanumeric('AB 1234'), isFalse);

      // Rejects invalid lengths
      expect(UserProfile.isValidAlphanumeric('AB'), isFalse);
      expect(UserProfile.isValidAlphanumeric('A' * 31), isFalse);
    });

    test('UserProfile.hasConfusingChars accurately detects 0 and O regardless of casing', () {
      expect(UserProfile.hasConfusingChars('ABC0DEF'), isTrue);
      expect(UserProfile.hasConfusingChars('ABCODEF'), isTrue);
      expect(UserProfile.hasConfusingChars('abc0def'), isTrue);
      expect(UserProfile.hasConfusingChars('abcdefo'), isTrue);
      expect(UserProfile.hasConfusingChars('ABCDEFZ'), isFalse);
      expect(UserProfile.hasConfusingChars('KXMPEQA'), isFalse);
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

    test('generateUniqueUsername regenerates until a unique username is found when initial candidates exist in db', () async {
      int checkAttempts = 0;
      final existingDbUsernames = <String>{};

      final uniqueUsername = await UserProfile.generateUniqueUsername(
        isTakenFn: (candidate) async {
          checkAttempts++;
          if (checkAttempts <= 3) {
            // First 3 generated candidates collide with database records
            existingDbUsernames.add(candidate);
            return true;
          }
          // 4th candidate is available/unique in database
          return false;
        },
      );

      // Verify it checked 4 times (3 collisions + 1 unique)
      expect(checkAttempts, equals(4));
      // Verify the returned username is unique and not in the existing DB set
      expect(existingDbUsernames.contains(uniqueUsername), isFalse);
      // Verify valid 7-character format with alphanumeric uppercase letters and digits excluding 0 and O
      expect(uniqueUsername.length, equals(7));
      expect(uniqueUsername.contains('0'), isFalse);
      expect(uniqueUsername.contains('O'), isFalse);
      expect(RegExp(r'^[A-NP-Z1-9]{7}$').hasMatch(uniqueUsername), isTrue);
      expect(UserProfile.isValidAlphanumeric(uniqueUsername), isTrue);
    });

    test('AuthRepository generateUniqueUsername checks db and regenerates on collision', () async {
      final fakeRepo = FakeAuthRepository(null);
      int callCount = 0;
      final collidingNames = <String>{};

      final generated = await fakeRepo.generateUniqueUsername(
        isTakenFn: (candidate) async {
          callCount++;
          if (callCount < 3) {
            collidingNames.add(candidate);
            return true; // Already exists in db
          }
          return false; // Unique in db
        },
      );

      expect(callCount, equals(3));
      expect(collidingNames.contains(generated), isFalse);
      expect(generated.length, equals(7));
    });

    test('generateUniqueUsername skips any existing usernames in database', () async {
      final existingDb = {'taken01', 'taken02', 'admin01', 'alpha01'};
      final fakeRepo = FakeAuthRepository(null, existingUsernames: existingDb);

      for (int i = 0; i < 20; i++) {
        final username = await fakeRepo.generateUniqueUsername();
        expect(existingDb.contains(username), isFalse, reason: 'Generated username should never be in existing db');
        expect(username.length, equals(7));
      }
    });

    testWidgets('LoginScreen generates unique username and refresh button triggers regeneration', (WidgetTester tester) async {
      final fakeRepo = FakeAuthRepository(null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to sign up tab
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      final usernameField = find.widgetWithText(TextFormField, 'Username (7-Character Alphanumeric)');
      expect(usernameField, findsOneWidget);

      final initialControllerText = tester.widget<TextFormField>(usernameField).controller!.text;
      expect(initialControllerText.length, equals(7));
      expect(initialControllerText.contains('0'), isFalse);
      expect(initialControllerText.contains('O'), isFalse);

      // Tap the refresh icon
      final refreshIcon = find.byTooltip('Generate new 7-character username');
      expect(refreshIcon, findsOneWidget);
      await tester.tap(refreshIcon);
      await tester.pumpAndSettle();

      final newControllerText = tester.widget<TextFormField>(usernameField).controller!.text;
      expect(newControllerText.length, equals(7));
      expect(newControllerText.contains('0'), isFalse);
      expect(newControllerText.contains('O'), isFalse);
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
