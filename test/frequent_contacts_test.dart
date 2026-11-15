import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_diary/core/diary_registry/diary_registry.dart';
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/shared_diaries/models/frequent_contact.dart';
import 'package:magic_diary/features/shared_diaries/repositories/frequent_contacts_repository.dart';
import 'package:magic_diary/features/shared_diaries/widgets/frequent_contact_suggestions.dart';
import 'package:magic_diary/features/shared_diaries/widgets/sharing_wizard_sheet.dart';

class FakeFrequentContactsRepository extends FrequentContactsRepository {
  final Map<String, FrequentContact> storage = {};

  FakeFrequentContactsRepository([List<FrequentContact>? initial]) {
    if (initial != null) {
      for (final c in initial) {
        storage[c.id] = c;
      }
    }
  }

  @override
  Stream<List<FrequentContact>> watchFrequentContacts(String userId, {int limit = 25}) {
    return Stream.value(getContactsSync(userId, limit: limit));
  }

  @override
  Future<List<FrequentContact>> getFrequentContacts(String userId, {int limit = 25}) async {
    return getContactsSync(userId, limit: limit);
  }

  List<FrequentContact> getContactsSync(String userId, {int limit = 25}) {
    final list = storage.values.where((c) => c.userId == userId).toList();
    list.sort((a, b) {
      final comp = b.useCount.compareTo(a.useCount);
      if (comp != 0) return comp;
      return b.lastUsedAt.compareTo(a.lastUsedAt);
    });
    return list.take(limit).toList();
  }

  @override
  Future<List<FrequentContact>> lookupSuggestions(
    String userId,
    String query, {
    int limit = 6,
  }) async {
    final contacts = getContactsSync(userId, limit: 50);
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return contacts.take(limit).toList();
    }
    return contacts.where((c) => c.matchesQuery(clean)).take(limit).toList();
  }

  @override
  Future<FrequentContact> recordContactUsage({
    required String userId,
    required String email,
    String? name,
    String? username,
    String? photoUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final docId = FrequentContact.generateId(userId, cleanEmail);
    final now = DateTime.now();

    if (storage.containsKey(docId)) {
      final existing = storage[docId]!;
      final updated = existing.copyWith(
        name: (name != null && name.trim().isNotEmpty) ? name.trim() : existing.name,
        username: (username != null && username.trim().isNotEmpty) ? username.trim() : existing.username,
        photoUrl: photoUrl ?? existing.photoUrl,
        useCount: existing.useCount + 1,
        lastUsedAt: now,
        updatedAt: now,
      );
      storage[docId] = updated;
      return updated;
    } else {
      final newContact = FrequentContact(
        id: docId,
        userId: userId,
        email: cleanEmail,
        name: name?.trim() ?? '',
        username: username?.trim(),
        photoUrl: photoUrl,
        useCount: 1,
        lastUsedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      storage[docId] = newContact;
      return newContact;
    }
  }

  @override
  Future<void> deleteContact(String userId, String contactId) async {
    storage.remove(contactId);
  }
}

class FakeAuthRepo extends AuthRepository {
  final UserProfile user;
  FakeAuthRepo(this.user);

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(user);
}

class FakeUserNotifier extends UserNotifier {
  FakeUserNotifier(super.ref, UserProfile initialUser) {
    state = initialUser;
  }
}

void main() {
  group('FrequentContact Model & Search Tests', () {
    test('FrequentContact generates deterministic IDs and accurate initials', () {
      final id = FrequentContact.generateId('user_123', 'John.Doe@Example.com');
      expect(id, equals('user_123_contact_john_doe_example_com'));

      final c1 = FrequentContact(
        id: 'c1',
        userId: 'user_123',
        email: 'alex@example.com',
        name: 'Alex Rivers',
        useCount: 5,
        lastUsedAt: DateTime(2026, 11, 14),
        createdAt: DateTime(2026, 11, 1),
      );
      expect(c1.initials, equals('AR'));
      expect(c1.displayName, equals('Alex Rivers'));

      final c2 = FrequentContact(
        id: 'c2',
        userId: 'user_123',
        email: 'sarah@example.com',
        username: 'sarah7',
        useCount: 2,
        lastUsedAt: DateTime(2026, 11, 14),
        createdAt: DateTime(2026, 11, 1),
      );
      expect(c2.initials, equals('S'));
      expect(c2.displayName, equals('@sarah7'));
    });

    test('FrequentContact matchesQuery matches email, name, username, and @prefix', () {
      final contact = FrequentContact(
        id: 'c1',
        userId: 'u1',
        email: 'debasish.mahato@gmail.com',
        name: 'Debasish Mahato',
        username: 'deb99x1',
        useCount: 8,
        lastUsedAt: DateTime(2026, 11, 15),
        createdAt: DateTime(2026, 1, 1),
      );

      // Email match
      expect(contact.matchesQuery('debasish'), isTrue);
      expect(contact.matchesQuery('gmail.com'), isTrue);

      // Name match
      expect(contact.matchesQuery('Mahato'), isTrue);
      expect(contact.matchesQuery('deb'), isTrue);

      // Username match (with and without @)
      expect(contact.matchesQuery('deb99'), isTrue);
      expect(contact.matchesQuery('@deb99'), isTrue);

      // Unrelated query
      expect(contact.matchesQuery('charlie'), isFalse);
    });

    test('FrequentContact serializes and deserializes accurately with toMap and fromMap', () {
      final now = DateTime(2026, 11, 15, 10, 0, 0);
      final contact = FrequentContact(
        id: 'u1_contact_alex_example_com',
        userId: 'u1',
        email: 'alex@example.com',
        name: 'Alex Rivers',
        username: 'alex_r',
        useCount: 7,
        lastUsedAt: now,
        createdAt: now,
      );

      final map = contact.toMap();
      expect(map['email'], equals('alex@example.com'));
      expect(map['useCount'], equals(7));

      final restored = FrequentContact.fromMap(map, 'u1_contact_alex_example_com');
      expect(restored.id, equals(contact.id));
      expect(restored.email, equals(contact.email));
      expect(restored.name, equals(contact.name));
      expect(restored.username, equals(contact.username));
      expect(restored.useCount, equals(7));
    });
  });

  group('FrequentContactsRepository Usage Tracking & Suggestion Tests', () {
    test('recordContactUsage increments useCount and updates lastUsedAt on subsequent shares', () async {
      final repo = FakeFrequentContactsRepository();
      const userId = 'user_active_100';

      // 1st share with recipient
      final first = await repo.recordContactUsage(
        userId: userId,
        email: 'priya@example.com',
        name: 'Priya Sharma',
        username: 'priya7',
      );
      expect(first.useCount, equals(1));
      expect(first.name, equals('Priya Sharma'));

      // 2nd share with same recipient
      final second = await repo.recordContactUsage(
        userId: userId,
        email: 'priya@example.com',
      );
      expect(second.useCount, equals(2));
      expect(second.name, equals('Priya Sharma')); // Retains previous name

      // 3rd share with updated name
      final third = await repo.recordContactUsage(
        userId: userId,
        email: 'priya@example.com',
        name: 'Dr. Priya Sharma',
      );
      expect(third.useCount, equals(3));
      expect(third.name, equals('Dr. Priya Sharma'));
    });

    test('lookupSuggestions returns matching contacts ordered by usage frequency', () async {
      final now = DateTime.now();
      final contacts = [
        FrequentContact(
          id: 'c1',
          userId: 'u1',
          email: 'alex.rivers@gmail.com',
          name: 'Alex Rivers',
          useCount: 15, // Most frequent
          lastUsedAt: now,
          createdAt: now,
        ),
        FrequentContact(
          id: 'c2',
          userId: 'u1',
          email: 'alex.tan@yahoo.com',
          name: 'Alex Tan',
          useCount: 4,
          lastUsedAt: now,
          createdAt: now,
        ),
        FrequentContact(
          id: 'c3',
          userId: 'u1',
          email: 'bob@example.com',
          name: 'Bob Alex',
          useCount: 1,
          lastUsedAt: now,
          createdAt: now,
        ),
        FrequentContact(
          id: 'c4',
          userId: 'u1',
          email: 'charlie@example.com',
          name: 'Charlie Day',
          useCount: 10,
          lastUsedAt: now,
          createdAt: now,
        ),
      ];

      final repo = FakeFrequentContactsRepository(contacts);

      // Search for "alex" -> should match c1, c2, c3 in order of useCount (15, 4, 1)
      final suggestions = await repo.lookupSuggestions('u1', 'alex');
      expect(suggestions.length, equals(3));
      expect(suggestions[0].name, equals('Alex Rivers'));
      expect(suggestions[0].useCount, equals(15));
      expect(suggestions[1].name, equals('Alex Tan'));
      expect(suggestions[1].useCount, equals(4));
      expect(suggestions[2].name, equals('Bob Alex'));
      expect(suggestions[2].useCount, equals(1));
    });
  });

  group('Frequent Contact UI Components & Suggestion Selection Tests', () {
    testWidgets('FrequentContactChipsRow renders top contacts and handles selection', (tester) async {
      final now = DateTime.now();
      final contacts = [
        FrequentContact(
          id: '1',
          userId: 'u1',
          email: 'spouse@example.com',
          name: 'Sarah',
          useCount: 8,
          lastUsedAt: now,
          createdAt: now,
        ),
        FrequentContact(
          id: '2',
          userId: 'u1',
          email: 'tax@accountant.com',
          name: 'Rajesh CPA',
          useCount: 3,
          lastUsedAt: now,
          createdAt: now,
        ),
      ];

      FrequentContact? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrequentContactChipsRow(
              contacts: contacts,
              onContactSelected: (c) => selected = c,
            ),
          ),
        ),
      );

      expect(find.text('Frequently Shared Contacts'), findsOneWidget);
      expect(find.text('Sarah'), findsOneWidget);
      expect(find.text('Rajesh CPA'), findsOneWidget);
      expect(find.text('8x'), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);

      // Tap on Sarah
      await tester.tap(find.text('Sarah'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.email, equals('spouse@example.com'));
    });

    testWidgets('FrequentContactSuggestionsCard renders matching contacts with badges and handles tap', (tester) async {
      final now = DateTime.now();
      final suggestions = [
        FrequentContact(
          id: '1',
          userId: 'u1',
          email: 'alex@example.com',
          name: 'Alex Rivers',
          username: 'k4m9x27',
          useCount: 5,
          lastUsedAt: now,
          createdAt: now,
        ),
      ];

      FrequentContact? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FrequentContactSuggestionsCard(
              suggestions: suggestions,
              onContactSelected: (c) => selected = c,
            ),
          ),
        ),
      );

      expect(find.text('Alex Rivers'), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.text('@k4m9x27'), findsOneWidget);
      expect(find.text('5 shares'), findsOneWidget);

      await tester.tap(find.text('Alex Rivers'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.email, equals('alex@example.com'));
      expect(selected!.username, equals('k4m9x27'));
    });

    testWidgets('SharingWizardSheet displays frequent contacts and auto-fills on suggestion tap', (tester) async {
      final now = DateTime.now();
      final testUser = UserProfile(
        uid: 'user_wizard_test',
        email: 'tester@magicdiary.com',
        displayName: 'Test Owner',
        username: 'tester1',
        createdAt: now,
        updatedAt: now,
      );

      final fakeContactsRepo = FakeFrequentContactsRepository([
        FrequentContact(
          id: 'c1',
          userId: 'user_wizard_test',
          email: 'partner@example.com',
          name: 'Elena Rostova',
          username: 'elena_r',
          useCount: 6,
          lastUsedAt: now,
          createdAt: now,
        ),
      ]);

      final testDiary = DiaryRegistry.getDiaryById('bill_payment') ?? DiaryRegistry.predefinedDiaries.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepo(testUser)),
            userProfileProvider.overrideWith((ref) => FakeUserNotifier(ref, testUser)),
            frequentContactsRepositoryProvider.overrideWithValue(fakeContactsRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SharingWizardSheet(initialDiary: testDiary),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Step 1 is visible
      expect(find.text('Step 1: Choose Sharing Destination'), findsOneWidget);
      expect(find.text('Frequently Shared Contacts'), findsOneWidget);
      expect(find.text('Elena Rostova'), findsOneWidget);

      // Tap on Elena Rostova suggestion chip
      await tester.tap(find.text('Elena Rostova'));
      await tester.pumpAndSettle();

      // Email and Name fields should be auto-filled
      final emailField = find.widgetWithText(TextField, 'Recipient Email or @Username *');
      final nameField = find.widgetWithText(TextField, 'Recipient Name (Optional)');

      expect(tester.widget<TextField>(emailField).controller!.text, equals('partner@example.com'));
      expect(tester.widget<TextField>(nameField).controller!.text, equals('Elena Rostova'));

      // Selection confirmation badge should appear
      expect(find.textContaining('Selected from frequent contacts • Shared 6 times'), findsOneWidget);
    });
  });
}
