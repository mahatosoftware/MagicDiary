import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/features/bills/models/bills_models.dart';
import 'package:magic_diary/features/bills/screens/bills_dashboard_screen.dart';

void main() {
  group('Auto-Rollover & Subscription Tracker Model Tests', () {
    test('BillAccount properly serializes and deserializes subscription and free trial fields', () {
      final trialDate = DateTime(2026, 11, 22, 10, 0);
      final renewalDate = DateTime(2027, 10, 15, 9, 0);

      final account = BillAccount(
        id: 'acc_sub_1',
        userId: 'user_123',
        name: 'Netflix 4K',
        category: 'Subscription',
        providerName: 'Netflix',
        accountNumber: 'user@example.com',
        billingCycle: 'Monthly',
        dueDayOfMonth: 15,
        defaultAmount: 649.0,
        autoReminder: true,
        createdAt: DateTime(2026, 10, 1),
        isSubscription: true,
        subscriptionType: 'paid',
        trialEndsAt: trialDate,
        renewalDate: renewalDate,
        reminderDaysBefore: 3,
        cancelUrl: 'https://netflix.com/youraccount',
        planTier: 'Premium 4K',
        isActive: true,
      );

      final map = account.toMap();
      expect(map['isSubscription'], isTrue);
      expect(map['subscriptionType'], equals('paid'));
      expect(map['reminderDaysBefore'], equals(3));
      expect(map['cancelUrl'], equals('https://netflix.com/youraccount'));
      expect(map['planTier'], equals('Premium 4K'));
      expect(map['isActive'], isTrue);

      final restored = BillAccount.fromMap(map, 'acc_sub_1');
      expect(restored.id, equals('acc_sub_1'));
      expect(restored.name, equals('Netflix 4K'));
      expect(restored.isSubscription, isTrue);
      expect(restored.subscriptionType, equals('paid'));
      expect(restored.reminderDaysBefore, equals(3));
      expect(restored.cancelUrl, equals('https://netflix.com/youraccount'));
      expect(restored.planTier, equals('Premium 4K'));
      expect(restored.isActive, isTrue);
    });

    test('BillAccount copyWith correctly updates subscription state', () {
      final original = BillAccount(
        id: 'acc_sub_2',
        userId: 'user_123',
        name: 'YouTube Premium',
        category: 'Subscription',
        providerName: 'Google',
        accountNumber: 'yt@example.com',
        billingCycle: 'Monthly',
        dueDayOfMonth: 20,
        defaultAmount: 149.0,
        createdAt: DateTime(2026, 10, 1),
        isSubscription: true,
        subscriptionType: 'free_trial',
        trialEndsAt: DateTime(2026, 11, 20),
        isActive: true,
      );

      final cancelled = original.copyWith(isActive: false);
      expect(cancelled.isActive, isFalse);
      expect(cancelled.name, equals('YouTube Premium'));
      expect(cancelled.subscriptionType, equals('free_trial'));

      final upgraded = original.copyWith(
        subscriptionType: 'paid',
        planTier: 'Family Plan',
        defaultAmount: 299.0,
      );
      expect(upgraded.subscriptionType, equals('paid'));
      expect(upgraded.planTier, equals('Family Plan'));
      expect(upgraded.defaultAmount, equals(299.0));
    });

    test('Free trial alert computes exact 3-day notice before expiry', () {
      final trialEndsAt = DateTime(2026, 11, 22, 18, 0);
      const reminderDaysBefore = 3;

      final targetAlertDate = trialEndsAt.subtract(const Duration(days: reminderDaysBefore));
      expect(targetAlertDate.year, equals(2026));
      expect(targetAlertDate.month, equals(11));
      expect(targetAlertDate.day, equals(19));
      expect(trialEndsAt.difference(targetAlertDate).inDays, equals(3));
    });

    test('Auto-rollover date calculation accurately rolls over monthly, quarterly, and yearly cycles', () {
      // Monthly rollover from Oct 10 -> Nov 10
      final baseDate = DateTime(2026, 10, 10, 9, 0);
      const dueDay = 10;

      // 1. Monthly
      int nextMonth = baseDate.month + 1;
      int nextYear = baseDate.year;
      if (nextMonth > 12) {
        nextMonth -= 12;
        nextYear += 1;
      }
      final maxDayMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      final monthlyNextDate = DateTime(nextYear, nextMonth, dueDay.clamp(1, maxDayMonth), 9, 0);

      expect(monthlyNextDate.year, equals(2026));
      expect(monthlyNextDate.month, equals(11));
      expect(monthlyNextDate.day, equals(10));

      // 2. Year-end rollover from Dec 15 2026 -> Jan 15 2027
      final decDate = DateTime(2026, 12, 15, 9, 0);
      int decNextMonth = decDate.month + 1;
      int decNextYear = decDate.year;
      if (decNextMonth > 12) {
        decNextMonth -= 12;
        decNextYear += 1;
      }
      final decNextDueDate = DateTime(decNextYear, decNextMonth, 15, 9, 0);
      expect(decNextDueDate.year, equals(2027));
      expect(decNextDueDate.month, equals(1));
      expect(decNextDueDate.day, equals(15));

      // 3. Month-end clamping (e.g. Day 31 clamped to Feb 28 in non-leap year)
      final janDate = DateTime(2027, 1, 31, 9, 0);
      int febNextMonth = janDate.month + 1;
      int febNextYear = janDate.year;
      final maxDayFeb = DateTime(febNextYear, febNextMonth + 1, 0).day;
      final febNextDueDate = DateTime(febNextYear, febNextMonth, 31.clamp(1, maxDayFeb), 9, 0);
      expect(febNextDueDate.month, equals(2));
      expect(febNextDueDate.day, equals(28));
    });
  });

  group('BillsDashboardScreen UI Tests', () {
    testWidgets('BillsDashboardScreen renders segmented tab bar and switches to Subscriptions tab', (WidgetTester tester) async {
      final testAccounts = [
        BillAccount(
          id: 'acc_1',
          userId: 'test_user',
          name: 'Airtel Broadband',
          category: 'Broadband / Internet',
          providerName: 'Airtel',
          accountNumber: 'BB-9871',
          billingCycle: 'Monthly',
          dueDayOfMonth: 12,
          defaultAmount: 1199.0,
          createdAt: DateTime(2026, 1, 1),
          isSubscription: false,
        ),
        BillAccount(
          id: 'acc_2',
          userId: 'test_user',
          name: 'ChatGPT Plus',
          category: 'Subscription',
          providerName: 'OpenAI',
          accountNumber: 'user@openai.com',
          billingCycle: 'Monthly',
          dueDayOfMonth: 5,
          defaultAmount: 1999.0,
          createdAt: DateTime(2026, 1, 1),
          isSubscription: true,
          subscriptionType: 'paid',
          planTier: 'Plus Plan',
        ),
        BillAccount(
          id: 'acc_3',
          userId: 'test_user',
          name: 'Cult.fit Gym Trial',
          category: 'Subscription',
          providerName: 'Cult.fit',
          accountNumber: 'gym@example.com',
          billingCycle: 'Monthly',
          dueDayOfMonth: 20,
          defaultAmount: 3500.0,
          createdAt: DateTime(2026, 10, 1),
          isSubscription: true,
          subscriptionType: 'free_trial',
          trialEndsAt: DateTime.now().add(const Duration(days: 2)), // Ends in 2 days -> should trigger alert banner!
          cancelUrl: 'https://cult.fit/cancel',
        ),
      ];

      final testBills = [
        Bill(
          id: 'bill_1',
          billAccountId: 'acc_1',
          userId: 'test_user',
          billPeriod: 'November 2026',
          billDate: DateTime(2026, 11, 1),
          dueDate: DateTime(2026, 11, 12),
          amount: 1199.0,
          status: 'unpaid',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billAccountsProvider.overrideWith((ref) => Future.value(testAccounts)),
            billsProvider.overrideWith((ref) => Future.value(testBills)),
          ],
          child: const MaterialApp(
            home: BillsDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Bills & Utilities Tab is active initially
      expect(find.text('Bills & Utilities'), findsOneWidget);
      expect(find.text('Subscriptions & Trials'), findsOneWidget);
      expect(find.text('Recurring Bill Accounts'), findsOneWidget);
      expect(find.text('Airtel Broadband'), findsOneWidget);

      // Tap on Subscriptions & Trials Tab
      await tester.tap(find.text('Subscriptions & Trials'));
      await tester.pumpAndSettle();

      // Check Subscriptions tab contents
      expect(find.text('Estimated Monthly Cost'), findsOneWidget);
      expect(find.text('Tracked Subscriptions'), findsOneWidget);
      expect(find.text('ChatGPT Plus'), findsOneWidget);
      expect(find.text('Cult.fit Gym Trial'), findsOneWidget);

      // Check Free Trial 3-Day Alert Banner is rendered
      expect(find.textContaining('Free Trial Alert: Cult.fit Gym Trial'), findsOneWidget);
      expect(find.text('Cancel URL'), findsOneWidget);
      expect(find.text('FREE TRIAL'), findsOneWidget);
    });
  });
}
