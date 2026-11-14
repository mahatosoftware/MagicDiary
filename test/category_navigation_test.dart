import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_diary/core/diary_registry/diary_registry.dart';
import 'package:magic_diary/core/diary_registry/diary_category.dart';
import 'package:magic_diary/core/diary_registry/diary_preferences_service.dart';
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/my_diaries/screens/my_diaries_screen.dart';
import 'package:magic_diary/features/my_diaries/screens/diary_category_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class FakeAuthRepository extends AuthRepository {
  final UserProfile? mockProfile;
  FakeAuthRepository(this.mockProfile);

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(mockProfile);

  @override
  fb.User? get currentFirebaseUser => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Category-First Navigation Architecture Tests', () {
    test('8 Standard Categories have exact names, icons, orders and diary counts', () {
      expect(DiaryCategory.allCategories.length, equals(8));

      final names = DiaryCategory.allCategories.map((c) => c.name).toList();
      expect(names, equals([
        'Money & Finance',
        'Home & Property',
        'Vehicles & Travel',
        'Family & Education',
        'Assets & Protection',
        'Health & Wellness',
        'Lifestyle & Personal',
        'Special Purpose',
      ]));

      // Verify category diary counts
      final cat1 = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.financial);
      final cat2 = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.homeAndProperty);
      final cat3 = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.vehicleAndTravel);
      final cat4 = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.familyAndEducation);
      final cat5 = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.assetsAndProtection);
      final cat6 = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.healthAndWellbeing);
      final cat7 = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.lifestyleAndOrganization);
      final cat8 = DiaryRegistry.getDiariesByCategory(DiaryCategoryType.specialPurpose);

      expect(cat1.length, equals(6));
      expect(cat2.length, equals(4));
      expect(cat3.length, equals(3));
      expect(cat4.length, equals(4));
      expect(cat5.length, equals(3));
      expect(cat6.length, equals(6));
      expect(cat7.length, equals(9));
      expect(cat8.length, equals(10));
      expect(cat1.length + cat2.length + cat3.length + cat4.length + cat5.length + cat6.length + cat7.length + cat8.length, equals(45));
    });

    test('Category lookups support both modern and legacy string IDs', () {
      expect(DiaryCategory.fromId('money_finance').name, equals('Money & Finance'));
      expect(DiaryCategory.fromId('financial').name, equals('Money & Finance'));
      expect(DiaryCategory.fromId('health_wellness').name, equals('Health & Wellness'));
      expect(DiaryCategory.fromId('health_wellbeing').name, equals('Health & Wellness'));
      expect(DiaryCategory.fromId('lifestyle_personal').name, equals('Lifestyle & Personal'));
      expect(DiaryCategory.fromId('lifestyle_organization').name, equals('Lifestyle & Personal'));
      expect(DiaryCategory.fromId('home_property').name, equals('Home & Property'));
      expect(DiaryCategory.fromId('vehicle_travel').name, equals('Vehicles & Travel'));
    });

    test('Keyword Search: Searching "electricity" returns Bill Payment Diary in Money & Finance', () {
      final results = DiaryRegistry.searchDiaries('electricity');
      expect(results.any((d) => d.id == 'bill_payment'), isTrue);
      final billDiary = results.firstWhere((d) => d.id == 'bill_payment');
      expect(billDiary.name, equals('Bill Payment Diary'));
      expect(DiaryCategory.fromType(billDiary.categoryType).name, equals('Money & Finance'));
    });

    test('Keyword Search: Searching "car" returns Vehicle and Fuel & Mileage Diaries in Vehicles & Travel', () {
      final results = DiaryRegistry.searchDiaries('car');
      final ids = results.map((d) => d.id).toList();
      expect(ids.contains('vehicle'), isTrue);
      expect(ids.contains('fuel_mileage'), isTrue);
      final vehicleDiary = results.firstWhere((d) => d.id == 'vehicle');
      expect(DiaryCategory.fromType(vehicleDiary.categoryType).name, equals('Vehicles & Travel'));
    });

    test('Keyword Search: Searching "school" returns School & Education Diary in Family & Education', () {
      final results = DiaryRegistry.searchDiaries('school');
      expect(results.any((d) => d.id == 'school_education'), isTrue);
      final schoolDiary = results.firstWhere((d) => d.id == 'school_education');
      expect(DiaryCategory.fromType(schoolDiary.categoryType).name, equals('Family & Education'));
    });

    test('Keyword Search: Searching "warranty" returns Warranty & AMC Diary in Assets & Protection', () {
      final results = DiaryRegistry.searchDiaries('warranty');
      expect(results.any((d) => d.id == 'warranty_amc'), isTrue);
      final warrantyDiary = results.firstWhere((d) => d.id == 'warranty_amc');
      expect(DiaryCategory.fromType(warrantyDiary.categoryType).name, equals('Assets & Protection'));
    });

    test('Category-Scoped Search restricts results only to that category', () {
      final financeResults = DiaryRegistry.searchDiaries('car', categoryType: DiaryCategoryType.financial);
      for (final diary in financeResults) {
        expect(diary.categoryType, equals(DiaryCategoryType.financial));
      }

      final vehicleResults = DiaryRegistry.searchDiaries('car', categoryType: DiaryCategoryType.vehicleAndTravel);
      expect(vehicleResults.isNotEmpty, isTrue);
      for (final diary in vehicleResults) {
        expect(diary.categoryType, equals(DiaryCategoryType.vehicleAndTravel));
      }
    });

    test('DiaryPreferencesNotifier manages active, favorite, recents and expanded categories', () async {
      final notifier = DiaryPreferencesNotifier();
      await notifier.loadPreferences();

      // Check default active
      expect(notifier.state.isDiaryActive('personal_finance'), isTrue);
      expect(notifier.state.isDiaryFavorite('personal_finance'), isTrue);

      // Toggle active status
      expect(notifier.state.isDiaryActive('tax'), isFalse);
      await notifier.toggleActiveDiary('tax');
      expect(notifier.state.isDiaryActive('tax'), isTrue);
      await notifier.toggleActiveDiary('tax');
      expect(notifier.state.isDiaryActive('tax'), isFalse);

      // Toggle favorite status
      expect(notifier.state.isDiaryFavorite('tax'), isFalse);
      await notifier.toggleFavoriteDiary('tax');
      expect(notifier.state.isDiaryFavorite('tax'), isTrue);
      await notifier.toggleFavoriteDiary('tax');
      expect(notifier.state.isDiaryFavorite('tax'), isFalse);

      // Record recently accessed
      await notifier.recordDiaryAccessed('tax');
      expect(notifier.state.recentDiaryIds.first, equals('tax'));

      // Category expand / collapse
      await notifier.collapseAllCategories();
      expect(notifier.state.expandedCategoryIds.isEmpty, isTrue);
      await notifier.expandAllCategories();
      expect(notifier.state.expandedCategoryIds.length, equals(8));
      await notifier.toggleCategoryExpanded('financial');
      expect(notifier.state.isCategoryExpanded('financial'), isFalse);
    });
  });

  group('Category-First UI Widget Tests', () {
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

    testWidgets('MyDiariesScreen renders Explore Diaries category grid and segmented buttons', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(fakeUser)),
            remindersProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: MyDiariesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('Explore Diaries 📔'), findsOneWidget);
      expect(find.text('45 Predefined Diaries Across 8 Major Categories'), findsOneWidget);

      // Verify Search Field
      expect(find.byType(TextField), findsOneWidget);

      // Verify Segmented View Switcher
      expect(find.text('Explore Categories'), findsOneWidget);
      expect(find.textContaining('My Active'), findsOneWidget);

      // Verify 8 Category Cards rendered in Explore Grid
      expect(find.text('Money & Finance'), findsWidgets);
      expect(find.text('Home & Property'), findsWidgets);
      expect(find.text('Vehicles & Travel'), findsWidgets);
      expect(find.text('Family & Education'), findsWidgets);
      expect(find.text('Assets & Protection'), findsWidgets);
      expect(find.text('Health & Wellness'), findsWidgets);
      expect(find.text('Lifestyle & Personal'), findsWidgets);
      expect(find.text('Special Purpose'), findsWidgets);

      // Verify switching to My Active view
      await tester.tap(find.textContaining('My Active'));
      await tester.pumpAndSettle();
      expect(find.text('Expand All'), findsOneWidget);
      expect(find.text('Collapse All'), findsOneWidget);
    });

    testWidgets('DiaryCategoryDetailScreen renders only diaries belonging to selected category', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiaryCategoryDetailScreen(categoryId: 'financial'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Money & Finance'), findsWidgets);
      expect(find.text('6 Diaries Available'), findsOneWidget);

      // Verify Diaries inside Money & Finance
      expect(find.text('Personal Finance Diary'), findsOneWidget);
      expect(find.text('Bill Payment Diary'), findsOneWidget);
      expect(find.text('Loan & EMI Diary'), findsOneWidget);
      expect(find.text('Investment Diary'), findsOneWidget);
      expect(find.text('Savings & Goals Diary'), findsOneWidget);
      expect(find.text('Tax Diary'), findsOneWidget);

      // Verify unrelated diaries from other categories DO NOT appear
      expect(find.text('Vehicle Diary'), findsNothing);
      expect(find.text('Property Diary'), findsNothing);
      expect(find.text('Health Diary'), findsNothing);
    });
  });
}
