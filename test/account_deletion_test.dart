import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/profile/screens/account_settings_screen.dart';

class FakeAuthRepository extends AuthRepository {
  final UserProfile? mockProfile;
  FakeAuthRepository(this.mockProfile);

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(mockProfile);

  @override
  fb.User? get currentFirebaseUser => null;
}

void main() {
  testWidgets('AccountSettingsScreen renders security and danger zone sections', (WidgetTester tester) async {
    final fakeUser = UserProfile(
      uid: 'user_xyz123',
      email: 'user@example.com',
      displayName: 'Alex Doe',
      username: 'alexdoe',
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

    // Verify Title and Sections
    expect(find.text('Account Settings'), findsOneWidget);
    expect(find.text('Security & Credentials'), findsOneWidget);
    expect(find.text('Data & Storage Isolation'), findsOneWidget);
    expect(find.text('Danger Zone'), findsOneWidget);

    // Verify Delete Account trigger is present
    expect(find.text('Delete Account'), findsWidgets);
    expect(
      find.text('Permanently delete your account, Cloud Firestore entries, uploaded documents, and associated cloud backups. This action cannot be reversed.'),
      findsOneWidget,
    );
  });
}
