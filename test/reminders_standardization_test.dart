import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_diary/config/routes.dart';
import 'package:magic_diary/core/providers/app_providers.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/auth/repositories/auth_repository.dart';
import 'package:magic_diary/features/finance/models/finance_models.dart';
import 'package:magic_diary/features/finance/repositories/finance_repository.dart';
import 'package:magic_diary/features/my_day/widgets/reminder_action_tile.dart';
import 'package:magic_diary/features/reminders/models/reminder.dart';
import 'package:magic_diary/features/reminders/repositories/reminder_repository.dart';
import 'package:magic_diary/features/reminders/services/reminder_action_resolver.dart';
import 'package:magic_diary/features/reminders/widgets/completion_details_dialog.dart';
import 'package:magic_diary/features/shared_diaries/models/shared_diary_models.dart';

class FakeUserNotifier extends UserNotifier {
  FakeUserNotifier(super.ref, UserProfile initialUser) {
    state = initialUser;
  }
}

class FakeAuthRepo extends AuthRepository {
  final UserProfile user;
  FakeAuthRepo(this.user);

  @override
  Stream<UserProfile?> get authStateChanges => Stream.value(user);
}

class MockReminderRepository extends ReminderRepository {
  final List<String> completedIds = [];
  final List<String> paidIds = [];

  @override
  Future<void> completeReminder(String userId, String reminderId, {DateTime? completedAt}) async {
    completedIds.add(reminderId);
  }

  @override
  Future<void> markAsComplete({
    required String userId,
    required String reminderId,
    ReminderCompletionDetails? completionDetails,
    String? completedBy,
    SharedDiaryAccess? shareAccess,
    String? diaryOwnerId,
    ReminderActionType actionType = ReminderActionType.markComplete,
  }) async {
    completedIds.add(reminderId);
  }

  @override
  Future<void> markAsPaid({
    required String userId,
    required String reminderId,
    required ReminderPaymentDetails paymentDetails,
    String? completedBy,
    SharedDiaryAccess? shareAccess,
    String? diaryOwnerId,
  }) async {
    completedIds.add(reminderId);
    paidIds.add(reminderId);
  }
}

class MockFinanceRepository extends FinanceRepository {
  final List<String> paidTransactionIds = [];

  @override
  Future<void> markTransactionAsPaid(
    String userId,
    String transactionId, {
    DateTime? paidAt,
    String? paymentMethod,
  }) async {
    paidTransactionIds.add(transactionId);
  }
}

void main() {
  group('Standardized Reminders Across Diaries Tests', () {
    final now = DateTime(2026, 10, 24, 12, 0, 0);

    test('Reminder model serializes and deserializes with all standardized fields', () {
      final dueDate = DateTime(2026, 10, 25, 10, 0, 0);
      final reminder = Reminder(
        id: 'reminder_school_inst_1',
        userId: 'user_test',
        title: 'School Fee: Aarav - Term 2 Tuition',
        description: 'Fee installment #2 of ₹25000 due for Aarav.',
        module: 'SchoolFees',
        status: 'pending',
        dueDate: dueDate,
        relatedId: 'inst_1',
        amount: 25000.0,
        currencyCode: 'INR',
        actionRoute: '/school-fees',
        createdAt: now,
      );

      final map = reminder.toMap();
      expect(map['title'], contains('Aarav'));
      expect(map['amount'], equals(25000.0));
      expect(map['module'], equals('SchoolFees'));
      expect(map['actionRoute'], equals('/school-fees'));

      final fromMap = Reminder.fromMap(map, 'reminder_school_inst_1');
      expect(fromMap.id, equals('reminder_school_inst_1'));
      expect(fromMap.title, equals(reminder.title));
      expect(fromMap.amount, equals(25000.0));
      expect(fromMap.currencyCode, equals('INR'));
      expect(fromMap.actionRoute, equals('/school-fees'));
    });

    test('Reminder date categorization (Today, Overdue, Upcoming) evaluates accurately', () {
      final todayReminder = Reminder(
        id: 'rem_today',
        userId: 'u1',
        title: 'Electricity Bill Due',
        description: 'Pay today',
        module: 'Bills',
        status: 'pending',
        dueDate: DateTime(2026, 10, 24, 18, 30),
        createdAt: now,
      );

      final overdueReminder = Reminder(
        id: 'rem_overdue',
        userId: 'u1',
        title: 'Car Insurance Expired',
        description: 'Expired 2 days ago',
        module: 'Vehicle',
        status: 'pending',
        dueDate: DateTime(2026, 10, 22),
        createdAt: now,
      );

      final upcomingReminder = Reminder(
        id: 'rem_upcoming',
        userId: 'u1',
        title: 'Property Tax',
        description: 'Due next week',
        module: 'Property',
        status: 'pending',
        dueDate: DateTime(2026, 10, 30),
        createdAt: now,
      );

      final completedReminder = Reminder(
        id: 'rem_completed',
        userId: 'u1',
        title: 'Broadband Bill',
        description: 'Paid yesterday',
        module: 'Bills',
        status: 'completed',
        dueDate: DateTime(2026, 10, 24, 9, 0),
        completedAt: DateTime(2026, 10, 23),
        createdAt: now,
      );

      // Verify today
      expect(todayReminder.isToday(now), isTrue);
      expect(todayReminder.isOverdue(now), isFalse);
      expect(todayReminder.isUpcoming(now), isFalse);
      expect(todayReminder.daysUntil(now), equals(0));

      // Verify overdue
      expect(overdueReminder.isOverdue(now), isTrue);
      expect(overdueReminder.isToday(now), isFalse);
      expect(overdueReminder.isUpcoming(now), isFalse);
      expect(overdueReminder.daysUntil(now), equals(-2));

      // Verify upcoming
      expect(upcomingReminder.isUpcoming(now), isTrue);
      expect(upcomingReminder.isToday(now), isFalse);
      expect(upcomingReminder.isOverdue(now), isFalse);
      expect(upcomingReminder.daysUntil(now), equals(6));

      // Verify completed is not marked overdue or today
      expect(completedReminder.isCompleted, isTrue);
      expect(completedReminder.isOverdue(now), isFalse);
      expect(completedReminder.isToday(now), isFalse);
    });

    test('Reminder copyWith properly updates payment and completion metadata', () {
      final initial = Reminder(
        id: 'rem_hh_1',
        userId: 'u1',
        title: 'Piped Gas Bill',
        description: 'Mahanagar Gas bill',
        module: 'Household',
        status: 'pending',
        dueDate: DateTime(2026, 10, 28),
        amount: 850.0,
        createdAt: now,
      );

      final completed = initial.copyWith(
        status: 'completed',
        completedAt: now,
      );

      expect(completed.id, equals('rem_hh_1'));
      expect(completed.status, equals('completed'));
      expect(completed.completedAt, equals(now));
      expect(completed.amount, equals(850.0));
      expect(completed.module, equals('Household'));
    });

    test('Updating diary entries synchronizes reminder details and preserves immutable fields', () {
      final initialDueDate = DateTime(2026, 11, 15);
      final initialTaxReminder = Reminder(
        id: 'reminder_prop_p1_tax',
        userId: 'user_123',
        title: 'Property Tax: Sunrise Apartment',
        description: 'Annual property tax of ₹12000 for Flat 402, Sunrise.',
        module: 'Property',
        status: 'pending',
        dueDate: initialDueDate,
        relatedId: 'p1',
        amount: 12000.0,
        actionRoute: '/property',
        actionType: 'Pay',
        priority: 'medium',
        createdAt: now,
      );

      // User updates Property: changes title, address, tax amount, and tax due date
      final updatedDueDate = DateTime(2026, 12, 1);
      final updatedTaxReminder = initialTaxReminder.copyWith(
        title: 'Property Tax: Sunrise Villa 402',
        description: 'Annual property tax of ₹15000 for Villa 402, Sunrise.',
        amount: 15000.0,
        dueDate: updatedDueDate,
      );

      expect(updatedTaxReminder.id, equals('reminder_prop_p1_tax'));
      expect(updatedTaxReminder.userId, equals('user_123'));
      expect(updatedTaxReminder.createdAt, equals(now)); // Immutable createdAt preserved
      expect(updatedTaxReminder.title, equals('Property Tax: Sunrise Villa 402'));
      expect(updatedTaxReminder.amount, equals(15000.0));
      expect(updatedTaxReminder.dueDate, equals(updatedDueDate));
      expect(updatedTaxReminder.description, contains('₹15000'));
    });

    test('Updating vehicle service or insurance updates reminder metadata', () {
      final oldExpiry = DateTime(2026, 11, 20);
      final initialInsurance = Reminder(
        id: 'reminder_veh_v1_insurance',
        userId: 'u1',
        title: 'Vehicle Insurance: Honda City',
        description: 'Insurance policy for Honda City (KA01AB1234) expires on 20 Nov 2026.',
        module: 'Vehicle',
        status: 'pending',
        dueDate: oldExpiry,
        relatedId: 'v1',
        actionRoute: '/vehicle',
        actionType: 'Renew',
        priority: 'high',
        createdAt: now,
      );

      // Vehicle renewed for next year
      final newExpiry = DateTime(2027, 11, 20);
      final updatedInsurance = initialInsurance.copyWith(
        title: 'Vehicle Insurance: Honda City ZX',
        description: 'Insurance policy for Honda City ZX (KA01AB1234) expires on 20 Nov 2027.',
        dueDate: newExpiry,
        status: 'pending',
      );

      expect(updatedInsurance.id, equals('reminder_veh_v1_insurance'));
      expect(updatedInsurance.dueDate, equals(newExpiry));
      expect(updatedInsurance.title, contains('ZX'));
      expect(updatedInsurance.createdAt, equals(now));
    });

    test('Updating product warranty details synchronizes reminder properly', () {
      final initialWarranty = Reminder(
        id: 'reminder_prod_prod1_warranty',
        userId: 'u1',
        title: 'Warranty Ending: Microwave Oven',
        description: 'Manufacturer warranty for Samsung Microwave Oven expires soon.',
        module: 'Warranty',
        status: 'pending',
        dueDate: DateTime(2026, 12, 10),
        relatedId: 'prod1',
        actionRoute: '/warranty',
        actionType: 'Renew',
        createdAt: now,
      );

      // Extended warranty purchased: updated end date and title
      final extendedDate = DateTime(2028, 12, 10);
      final updatedWarranty = initialWarranty.copyWith(
        title: 'Warranty Ending: Samsung Convection Microwave',
        dueDate: extendedDate,
      );

      expect(updatedWarranty.dueDate, equals(extendedDate));
      expect(updatedWarranty.title, contains('Samsung Convection'));
      expect(updatedWarranty.createdAt, equals(now));
    });
  });

  group('ReminderActionTile Mark as Done & Route Safety Tests', () {
    testWidgets('Tapping Mark as Complete completes reminder instead of failing with Page Not Found', (tester) async {
      final mockRepo = MockReminderRepository();
      final mockUser = UserProfile(
        uid: 'user_123',
        email: 'user@magicdiary.app',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final testReminder = Reminder(
        id: 'rem_task_999',
        userId: 'user_123',
        title: 'Complete annual property audit',
        description: 'Verify tax papers',
        module: 'Property',
        status: 'pending',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        actionType: 'complete',
        actionRoute: null, // previously fell back to '/my-day' causing 404
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => FakeAuthRepo(mockUser)),
            userProfileProvider.overrideWith((ref) => FakeUserNotifier(ref, mockUser)),
            reminderRepositoryProvider.overrideWith((ref) => mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReminderActionTile(reminder: testReminder),
            ),
          ),
        ),
      );

      // Verify the button says "Mark as Complete"
      final markCompleteFinder = find.widgetWithText(FilledButton, 'Mark as Complete');
      expect(markCompleteFinder, findsOneWidget);

      // Tap "Mark as Complete" to open completion details dialog
      await tester.tap(markCompleteFinder);
      await tester.pumpAndSettle();

      // Confirm in dialog
      final dialogConfirmFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      expect(dialogConfirmFinder, findsOneWidget);
      await tester.tap(dialogConfirmFinder);
      await tester.pumpAndSettle();

      // Verify the reminder was completed via the repository!
      expect(mockRepo.completedIds, contains('rem_task_999'));
    });

    test('Route /my-day exists in app router configuration without 404', () {
      final shellRoute = router.configuration.routes.whereType<ShellRoute>().first;
      final match = shellRoute.routes.any((r) => r is GoRoute && r.path == '/my-day');
      expect(match, isTrue);
    });

    test('FinancialTransaction model supports isPaid, hasReminder, and payment state transitions', () {
      final now = DateTime.now();
      final pendingTx = FinancialTransaction(
        id: 'tx_emi_101',
        type: 'Expense',
        category: 'EMI & Loan Payment',
        amount: 32000.0,
        date: now.add(const Duration(days: 5)),
        description: 'Home Loan EMI - HDFC Bank',
        paymentMethod: 'Auto-Debit',
        isPaid: false,
        hasReminder: true,
      );

      expect(pendingTx.isPaid, isFalse);
      expect(pendingTx.hasReminder, isTrue);
      expect(pendingTx.paidAt, isNull);

      final json = pendingTx.toJson();
      expect(json['isPaid'], isFalse);
      expect(json['hasReminder'], isTrue);

      final deserialized = FinancialTransaction.fromJson(json);
      expect(deserialized.id, equals('tx_emi_101'));
      expect(deserialized.isPaid, isFalse);
      expect(deserialized.hasReminder, isTrue);

      // Transition to paid
      final paidTx = deserialized.copyWith(
        isPaid: true,
        paidAt: now,
      );
      expect(paidTx.isPaid, isTrue);
      expect(paidTx.paidAt, equals(now));
    });

    testWidgets('Completing financial reminder on My Day marks transaction as paid and removes reminder', (tester) async {
      final mockRemRepo = MockReminderRepository();
      final mockFinRepo = MockFinanceRepository();
      final mockUser = UserProfile(
        uid: 'user_123',
        email: 'user@magicdiary.app',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final financeReminder = Reminder(
        id: 'reminder_tx_loan_555',
        userId: 'user_123',
        title: 'Payment Due: Home Loan EMI - SBI',
        description: 'EMI & Loan Payment of ₹45,000 due on 10 Nov 2026.',
        module: 'Finance',
        status: 'pending',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        relatedId: 'loan_555',
        amount: 45000.0,
        actionType: 'complete',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => FakeAuthRepo(mockUser)),
            userProfileProvider.overrideWith((ref) => FakeUserNotifier(ref, mockUser)),
            reminderRepositoryProvider.overrideWith((ref) => mockRemRepo),
            financeRepositoryProvider.overrideWith((ref) => mockFinRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReminderActionTile(reminder: financeReminder),
            ),
          ),
        ),
      );

      // Verify the tile is displayed and shows "Mark as Paid" for EMI payment reminder
      expect(find.text('Payment Due: Home Loan EMI - SBI'), findsOneWidget);
      final markPaidFinder = find.widgetWithText(FilledButton, 'Mark as Paid');
      expect(markPaidFinder, findsOneWidget);

      // Tap Mark as Paid to open PaymentConfirmationDialog
      await tester.tap(markPaidFinder);
      await tester.pumpAndSettle();

      // Confirm in PaymentConfirmationDialog
      final dialogConfirmFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      expect(dialogConfirmFinder, findsOneWidget);
      await tester.tap(dialogConfirmFinder);
      await tester.pumpAndSettle();

      // Verify the reminder was completed
      expect(mockRemRepo.completedIds, contains('reminder_tx_loan_555'));
      // Verify the financial transaction was marked as paid!
      expect(mockFinRepo.paidTransactionIds, contains('loan_555'));
    });

    testWidgets('Loan EMI reminder with actionType pay displays Mark as Paid button and Pay Online link', (tester) async {
      final mockRemRepo = MockReminderRepository();
      final mockFinRepo = MockFinanceRepository();
      final mockUser = UserProfile(
        uid: 'user_123',
        email: 'user@magicdiary.app',
        displayName: 'Test User',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final emiReminder = Reminder(
        id: 'reminder_loan_emi_home_10',
        userId: 'user_123',
        title: 'Home Loan EMI: HDFC Bank',
        description: 'Monthly Home Loan installment of ₹35,000 due to HDFC Bank.',
        module: 'Finance',
        status: 'pending',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        amount: 35000.0,
        actionType: 'pay',
        actionRoute: '/finance',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => FakeAuthRepo(mockUser)),
            userProfileProvider.overrideWith((ref) => FakeUserNotifier(ref, mockUser)),
            reminderRepositoryProvider.overrideWith((ref) => mockRemRepo),
            financeRepositoryProvider.overrideWith((ref) => mockFinRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReminderActionTile(reminder: emiReminder),
            ),
          ),
        ),
      );

      // Verify "Mark as Paid" is prominently present on the tile
      final markPaidFinder = find.widgetWithText(FilledButton, 'Mark as Paid');
      expect(markPaidFinder, findsOneWidget);

      // Verify "Pay ₹35000" secondary action is also present
      expect(find.text('Pay ₹35000'), findsOneWidget);

      // Tap "Mark as Paid" to open PaymentConfirmationDialog
      await tester.tap(markPaidFinder);
      await tester.pumpAndSettle();

      // Confirm in PaymentConfirmationDialog
      final dialogConfirmFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      );
      expect(dialogConfirmFinder, findsOneWidget);
      await tester.tap(dialogConfirmFinder);
      await tester.pumpAndSettle();

      // Verify reminder is completed
      expect(mockRemRepo.completedIds, contains('reminder_loan_emi_home_10'));
    });

    test('Reminder deduplication merges duplicate event reminders by relatedId or signature', () {
      final testNow = DateTime(2026, 11, 19, 10, 0);
      final dueDate = DateTime(2026, 11, 20, 10, 0);

      // Simulating duplicates from generic form save, reminder sync service, and proactive synthesis
      final rem1 = Reminder(
        id: 'reminder_record_evt_123',
        userId: 'u1',
        title: 'Event: Wedding Anniversary',
        description: 'Wedding Anniversary celebration',
        module: 'Personal',
        status: 'pending',
        dueDate: dueDate,
        relatedId: 'evt_123',
        actionRoute: '/diaries/event',
        createdAt: testNow,
      );

      final rem2 = Reminder(
        id: 'reminder_diary_evt_evt_123',
        userId: 'u1',
        title: 'Wedding Anniversary',
        description: 'Event Diary reminder',
        module: 'Personal',
        status: 'completed',
        dueDate: dueDate,
        relatedId: 'evt_123',
        createdAt: testNow,
      );

      final rem3 = Reminder(
        id: 'reminder_evt_evt_123',
        userId: 'u1',
        title: 'Special Event: Wedding Anniversary',
        description: 'Synthesized reminder',
        module: 'Personal',
        status: 'pending',
        dueDate: dueDate,
        relatedId: 'evt_123',
        createdAt: testNow,
      );

      final rawList = [rem1, rem2, rem3];

      // Simulate deduplication logic
      final Map<String, Reminder> uniqueMap = {};
      for (final r in rawList) {
        final cleanTitle = r.title.toLowerCase().replaceAll(RegExp(r'^(event|special event|reminder|payment due|bill|birthday|anniversary):\s*'), '').trim();
        final dateKey = '${r.dueDate.year}-${r.dueDate.month.toString().padLeft(2, '0')}-${r.dueDate.day.toString().padLeft(2, '0')}';
        final key = (r.relatedId != null && r.relatedId!.isNotEmpty)
            ? 'rel_${r.relatedId}_$dateKey'
            : 'sig_${r.module.toLowerCase()}_${cleanTitle}_$dateKey';

        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = r;
        } else {
          final existing = uniqueMap[key]!;
          if (existing.isCompleted && !r.isCompleted) {
            uniqueMap[key] = r;
          } else if ((existing.amount == null && r.amount != null) ||
                     ((existing.actionRoute == null || existing.actionRoute!.isEmpty) && (r.actionRoute != null && r.actionRoute!.isNotEmpty))) {
            uniqueMap[key] = r;
          }
        }
      }

      final deduplicated = uniqueMap.values.toList();
      expect(deduplicated.length, equals(1));
      expect(deduplicated.first.relatedId, equals('evt_123'));
      // Prefer pending over completed and has actionRoute
      expect(deduplicated.first.isCompleted, isFalse);
      expect(deduplicated.first.actionRoute, equals('/diaries/event'));
    });
  });
}
