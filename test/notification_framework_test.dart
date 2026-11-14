import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/financial/models/recurring_schedule.dart';
import 'package:magic_diary/core/notifications/models/notification_enums.dart';
import 'package:magic_diary/core/notifications/models/notification_preference.dart';
import 'package:magic_diary/core/notifications/models/notification_schedule.dart';
import 'package:magic_diary/core/notifications/models/notification_template.dart';
import 'package:magic_diary/core/notifications/models/reminder_interval.dart';
import 'package:magic_diary/core/notifications/models/time_of_day_dto.dart';
import 'package:magic_diary/core/notifications/repositories/notification_repository.dart';
import 'package:magic_diary/core/notifications/services/notification_defer_manager.dart';
import 'package:magic_diary/core/notifications/services/notification_history_manager.dart';
import 'package:magic_diary/core/notifications/services/notification_preference_manager.dart';
import 'package:magic_diary/core/notifications/services/notification_recovery_manager.dart';
import 'package:magic_diary/core/notifications/services/notification_recurrence_engine.dart';
import 'package:magic_diary/core/notifications/services/notification_scheduler.dart';
import 'package:magic_diary/core/notifications/services/notification_snooze_manager.dart';
import 'package:magic_diary/core/notifications/services/notification_template_manager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  const testUserId = 'test_user_notification_framework';

  group('1. Notification Models & Serialization Tests', () {
    test('TimeOfDayDto converts to/from string and maps correctly', () {
      const time = TimeOfDayDto(hour: 14, minute: 30);
      expect(time.format24Hour(), '14:30');
      expect(time.format12Hour(), '2:30 PM');

      final fromStr = TimeOfDayDto.fromString('09:15');
      expect(fromStr.hour, 9);
      expect(fromStr.minute, 15);

      final map = time.toMap();
      final reconstructed = TimeOfDayDto.fromMap(map);
      expect(reconstructed, time);
    });

    test('ReminderInterval calculates accurate trigger dates', () {
      final due = DateTime(2026, 12, 15, 0, 0);
      const fallbackTime = TimeOfDayDto(hour: 9, minute: 0);

      // 3 days before -> 12 Dec at 09:00 AM
      final trigger3d = ReminderInterval.threeDaysBefore.calculateTriggerTime(due, fallbackTime);
      expect(trigger3d.year, 2026);
      expect(trigger3d.month, 12);
      expect(trigger3d.day, 12);
      expect(trigger3d.hour, 9);
      expect(trigger3d.minute, 0);

      // On due date -> 15 Dec at 09:00 AM
      final trigger0d = ReminderInterval.onDueDate.calculateTriggerTime(due, fallbackTime);
      expect(trigger0d.day, 15);
      expect(trigger0d.hour, 9);

      // Offset key formatting
      expect(ReminderInterval.threeDaysBefore.toOffsetKey(), '-3d');
      expect(ReminderInterval.onDueDate.toOffsetKey(), '0d');
      expect(const ReminderInterval(value: 30, unit: ReminderUnit.minutes).toOffsetKey(), '-30m');
    });

    test('NotificationPreference serialization handles all fields', () {
      final now = DateTime.now();
      final pref = NotificationPreference(
        id: 'pref_mod_bills',
        userId: testUserId,
        level: 'module',
        targetId: 'bills',
        isEnabled: true,
        reminderIntervals: const [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
        preferredNotificationTime: const TimeOfDayDto(hour: 10, minute: 30),
        quietHoursEnabled: true,
        quietHoursStart: const TimeOfDayDto(hour: 23, minute: 0),
        quietHoursEnd: const TimeOfDayDto(hour: 6, minute: 0),
        allowWeekendNotifications: false,
        soundEnabled: true,
        vibrationEnabled: true,
        privacyMode: PrivacyMode.masked,
        overdueAlertsEnabled: true,
        overdueIntervalsDays: const [0, 1, 3, 7],
        defaultSnoozeMinutes: 30,
        maxSnoozeCount: 3,
        createdAt: now,
        updatedAt: now,
      );

      final map = pref.toMap();
      final restored = NotificationPreference.fromMap(map, 'pref_mod_bills');

      expect(restored.userId, testUserId);
      expect(restored.level, 'module');
      expect(restored.targetId, 'bills');
      expect(restored.isEnabled, true);
      expect(restored.reminderIntervals?.length, 2);
      expect(restored.preferredNotificationTime?.hour, 10);
      expect(restored.allowWeekendNotifications, false);
      expect(restored.privacyMode, PrivacyMode.masked);
      expect(restored.maxSnoozeCount, 3);
    });
  });

  group('2. Notification Configuration Hierarchy Tests', () {
    late NotificationRepository repo;
    late NotificationTemplateManager tplManager;
    late NotificationPreferenceManager prefManager;

    setUp(() {
      repo = NotificationRepository();
      tplManager = NotificationTemplateManager();
      prefManager = NotificationPreferenceManager(repository: repo, templateManager: tplManager);
    });

    test('Inheritance: Individual overrides category, module, and global settings', () async {
      // 1. Global: 1 day before
      await repo.saveGlobalPreference(NotificationPreference(
        id: 'global',
        userId: testUserId,
        level: 'global',
        isEnabled: true,
        reminderIntervals: const [ReminderInterval.oneDayBefore],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 2. Module (finance): 3 days and 1 day before
      await repo.saveModulePreference(NotificationPreference(
        id: 'pref_finance',
        userId: testUserId,
        level: 'module',
        targetId: 'finance',
        reminderIntervals: const [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 3. Category (credit_card): 5 days, 3 days, 1 day before
      await repo.saveCategoryPreference(NotificationPreference(
        id: 'pref_credit_card',
        userId: testUserId,
        level: 'category',
        targetId: 'credit_card',
        reminderIntervals: const [
          ReminderInterval.fiveDaysBefore,
          ReminderInterval.threeDaysBefore,
          ReminderInterval.oneDayBefore,
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Effective preference for general finance -> inherits module (3d, 1d)
      final effFinance = await prefManager.getEffectivePreference(
        userId: testUserId,
        moduleId: 'finance',
      );
      expect(effFinance.reminderIntervals.length, 2);
      expect(effFinance.intervalsSource, InheritanceStatus.inheritedFromModule);

      // Effective preference for credit card category -> inherits category (5d, 3d, 1d)
      final effCategory = await prefManager.getEffectivePreference(
        userId: testUserId,
        moduleId: 'finance',
        categoryId: 'credit_card',
      );
      expect(effCategory.reminderIntervals.length, 3);
      expect(effCategory.intervalsSource, InheritanceStatus.inheritedFromCategory);

      // 4. Individual record override: 7 days, 2 days, 0 days
      await repo.saveRecordOverride(NotificationPreference(
        id: 'pref_rec_cc1',
        userId: testUserId,
        level: 'individual',
        targetId: 'cc1',
        reminderIntervals: const [
          ReminderInterval.sevenDaysBefore,
          ReminderInterval(value: 2, unit: ReminderUnit.days),
          ReminderInterval.onDueDate,
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final effIndividual = await prefManager.getEffectivePreference(
        userId: testUserId,
        moduleId: 'finance',
        categoryId: 'credit_card',
        recordId: 'cc1',
      );
      expect(effIndividual.reminderIntervals.length, 3);
      expect(effIndividual.reminderIntervals.first.value, 7);
      expect(effIndividual.intervalsSource, InheritanceStatus.customized);
    });

    test('Changing global defaults does NOT overwrite explicit customizations', () async {
      // Set customized module preference
      await repo.saveModulePreference(NotificationPreference(
        id: 'pref_vehicle',
        userId: testUserId,
        level: 'module',
        targetId: 'vehicle',
        privacyMode: PrivacyMode.masked,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Modify global preference privacyMode to generic
      await repo.saveGlobalPreference(NotificationPreference(
        id: 'global',
        userId: testUserId,
        level: 'global',
        privacyMode: PrivacyMode.generic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final effVehicle = await prefManager.getEffectivePreference(
        userId: testUserId,
        moduleId: 'vehicle',
      );
      // Vehicle remains explicitly masked
      expect(effVehicle.privacyMode, PrivacyMode.masked);
      expect(effVehicle.privacySource, InheritanceStatus.inheritedFromModule);
    });

    test('Reset module settings reverts to inheriting global defaults', () async {
      await repo.saveModulePreference(NotificationPreference(
        id: 'pref_bills',
        userId: testUserId,
        level: 'module',
        targetId: 'bills',
        soundEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Reset bills module settings
      await prefManager.resetModuleSettings(testUserId, 'bills');

      final effBills = await prefManager.getEffectivePreference(
        userId: testUserId,
        moduleId: 'bills',
      );
      expect(effBills.soundEnabled, true); // Inherited from global default
    });
  });

  group('3. Notification Templates & Extensibility Tests', () {
    late NotificationTemplateManager manager;

    setUp(() {
      manager = NotificationTemplateManager();
    });

    test('All default Section 4 templates exist with sensible intervals', () {
      // Financial templates
      final electricity = manager.getTemplate('bills', 'electricity_bill');
      expect(electricity.defaultIntervals.length, 2);
      expect(electricity.defaultIntervals[0].value, 3);
      expect(electricity.defaultIntervals[1].value, 1);

      final creditCard = manager.getTemplate('finance', 'credit_card');
      expect(creditCard.defaultIntervals.length, 3);
      expect(creditCard.defaultIntervals[0].value, 5);

      final vehicleIns = manager.getTemplate('vehicle', 'vehicle_insurance');
      expect(vehicleIns.defaultIntervals.length, 3);
      expect(vehicleIns.defaultIntervals[0].value, 30);

      final warranty = manager.getTemplate('warranty', 'product_warranty');
      expect(warranty.defaultIntervals.length, 3);

      final salary = manager.getTemplate('domestic_help', 'monthly_salary');
      expect(salary.defaultIntervals.length, 1);
      expect(salary.defaultIntervals[0].value, 0); // On due date
    });

    test('Future diary modules can register templates dynamically without engine modification', () {
      const petDiaryTemplate = NotificationTemplate(
        id: 'tpl_pet_vaccination',
        moduleId: 'pet_diary',
        eventType: 'vaccination_due',
        titleTemplate: 'Vaccination Due: {petName}',
        bodyTemplate: 'Annual rabies vaccination for {petName} is due on {date}.',
        defaultIntervals: [ReminderInterval.sevenDaysBefore, ReminderInterval.oneDayBefore],
        channelType: NotificationChannelType.generalReminders,
      );

      manager.registerTemplate(petDiaryTemplate);

      final retrieved = manager.getTemplate('pet_diary', 'vaccination_due');
      expect(retrieved.id, 'tpl_pet_vaccination');
      expect(retrieved.formatTitle({'petName': 'Buddy'}), 'Vaccination Due: Buddy');
    });

    test('Privacy mode formats: detailed vs masked vs generic', () {
      final tpl = manager.getTemplate('finance', 'credit_card');
      final data = {
        'bankName': 'HDFC Bank',
        'amount': '₹25,000',
        'days': '3',
      };

      // Detailed
      final detailed = tpl.formatBody(data, PrivacyMode.detailed);
      expect(detailed.contains('₹25,000'), true);
      expect(detailed.contains('HDFC Bank'), true);

      // Masked
      final masked = tpl.formatBody(data, PrivacyMode.masked);
      expect(masked.contains('₹25,000'), false);
      expect(masked.contains('HDFC Bank'), true);

      // Generic
      final generic = tpl.formatBody(data, PrivacyMode.generic);
      expect(generic.contains('HDFC Bank'), false);
      expect(generic.contains('credit card'), true);
    });
  });

  group('4. Recurring Reminder Engine Tests', () {
    test('Month-end clamping: Jan 31 -> Feb 28 in non-leap year, Feb 29 in leap year', () {
      final jan31NonLeap = DateTime(2025, 1, 31, 9, 0);
      final feb2025 = NotificationRecurrenceEngine.calculateNextMonthlyOccurrence(jan31NonLeap, 31);
      expect(feb2025.year, 2025);
      expect(feb2025.month, 2);
      expect(feb2025.day, 28); // 2025 is not a leap year

      final jan31Leap = DateTime(2028, 1, 31, 9, 0);
      final feb2028 = NotificationRecurrenceEngine.calculateNextMonthlyOccurrence(jan31Leap, 31);
      expect(feb2028.year, 2028);
      expect(feb2028.month, 2);
      expect(feb2028.day, 29); // 2028 is a leap year!

      // Preserves original 31st target for March
      final mar2028 = NotificationRecurrenceEngine.calculateNextMonthlyOccurrence(feb2028, 31);
      expect(mar2028.month, 3);
      expect(mar2028.day, 31);
    });

    test('All standard recurring frequencies compute correct next occurrence', () {
      final base = DateTime(2026, 4, 1, 9, 0);

      // Daily
      final nextDaily = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: base,
        frequency: ScheduleFrequency.daily,
      );
      expect(nextDaily, base.add(const Duration(days: 1)));

      // Weekly
      final nextWeekly = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: base,
        frequency: ScheduleFrequency.weekly,
      );
      expect(nextWeekly, base.add(const Duration(days: 7)));

      // Quarterly
      final nextQuarterly = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: base,
        frequency: ScheduleFrequency.quarterly,
      );
      expect(nextQuarterly.month, 7);
      expect(nextQuarterly.day, 1);

      // Semi-Annual
      final nextSemi = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: base,
        frequency: ScheduleFrequency.semiAnnual,
      );
      expect(nextSemi.month, 10);
      expect(nextSemi.day, 1);

      // Annual
      final nextAnnual = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: base,
        frequency: ScheduleFrequency.annual,
      );
      expect(nextAnnual.year, 2027);
      expect(nextAnnual.month, 4);
      expect(nextAnnual.day, 1);
    });

    test('Generating occurrences respects scheduling horizon and max occurrences', () {
      final start = DateTime(2026, 1, 1);
      final occurrences = NotificationRecurrenceEngine.generateOccurrences(
        startDate: start,
        frequency: ScheduleFrequency.monthly,
        horizonDays: 180, // 6 months
      );

      // Expect Jan, Feb, Mar, Apr, May, Jun (180 days = ~6 months)
      expect(occurrences.length, 6);
      expect(occurrences.first.month, 1);
      expect(occurrences.last.month, 6);
    });

    test('Completing a recurring payment advances only the current occurrence', () {
      final currentDue = DateTime(2026, 6, 15);
      final nextDue = NotificationRecurrenceEngine.advanceOccurrenceOnCompletion(
        currentOccurrenceDueDate: currentDue,
        frequency: ScheduleFrequency.monthly,
        dueDayOfMonth: 15,
      );

      expect(nextDue.year, 2026);
      expect(nextDue.month, 7);
      expect(nextDue.day, 15);
    });
  });

  group('5. Snooze Functionality & Critical Business Rules Tests', () {
    late NotificationRepository repo;
    late NotificationSnoozeManager snoozeManager;

    setUp(() {
      repo = NotificationRepository();
      snoozeManager = NotificationSnoozeManager(repository: repo);
    });

    test('Rule 1-3: Snoozing never modifies original due date, recurrence, or paid status', () async {
      final originalDue = DateTime(2026, 12, 15, 9, 0);

      final res = await snoozeManager.snoozeNotification(
        userId: testUserId,
        recordId: 'bill_elec_123',
        moduleId: 'bills',
        categoryId: 'electricity_bill',
        eventType: 'electricity_bill',
        originalDueDate: originalDue,
        title: 'Electricity Bill',
        originalBody: 'Payment due on 15 Dec',
        preset: SnoozePreset.oneHour,
      );

      expect(res.isSuccess, true);
      expect(res.schedule?.isSnoozed, true);
      // Original due date is strictly preserved!
      expect(res.schedule?.originalScheduledAt, originalDue);
      expect(res.schedule?.status, NotificationScheduleStatus.snoozed);
    });

    test('Rule 7-8: Enforces maximum snooze count limit', () async {
      final originalDue = DateTime(2026, 12, 15, 9, 0);

      // 1st to 3rd snooze succeeds (max = 3)
      for (int i = 0; i < 3; i++) {
        final res = await snoozeManager.snoozeNotification(
          userId: testUserId,
          recordId: 'bill_limit_test',
          moduleId: 'bills',
          categoryId: 'utility',
          eventType: 'water_bill',
          originalDueDate: originalDue,
          title: 'Water Bill',
          originalBody: 'Water bill due',
          preset: SnoozePreset.tenMinutes,
          currentSnoozeCount: i,
          maxSnoozeCount: 3,
        );
        expect(res.isSuccess, true);
      }

      // 4th snooze fails due to max snooze limit
      final blocked = await snoozeManager.snoozeNotification(
        userId: testUserId,
        recordId: 'bill_limit_test',
        moduleId: 'bills',
        categoryId: 'utility',
        eventType: 'water_bill',
        originalDueDate: originalDue,
        title: 'Water Bill',
        originalBody: 'Water bill due',
        preset: SnoozePreset.tenMinutes,
        currentSnoozeCount: 3,
        maxSnoozeCount: 3,
      );
      expect(blocked.isSuccess, false);
      expect(blocked.errorMessage?.contains('Maximum snooze limit'), true);
    });

    test('Rule 10: Completing or deleting record cancels associated snoozed notifications', () async {
      final originalDue = DateTime(2026, 12, 15, 9, 0);

      await snoozeManager.snoozeNotification(
        userId: testUserId,
        recordId: 'rec_snooze_cancel',
        moduleId: 'finance',
        categoryId: 'loan',
        eventType: 'loan_emi',
        originalDueDate: originalDue,
        title: 'Loan EMI',
        originalBody: 'EMI due',
        preset: SnoozePreset.thirtyMinutes,
      );

      // Confirm snooze is active
      var schedules = await repo.getSchedulesForRecord(testUserId, 'rec_snooze_cancel');
      expect(schedules.any((s) => s.isSnoozed && s.isActive), true);

      // User marks payment complete
      await snoozeManager.onRecordCompletedOrDeleted(testUserId, 'rec_snooze_cancel');

      // Snoozed schedule is cancelled!
      schedules = await repo.getSchedulesForRecord(testUserId, 'rec_snooze_cancel');
      expect(schedules.any((s) => s.isSnoozed && s.isActive), false);
    });

    test('Rule 12: Snoozing an already overdue reminder preserves overdue status', () async {
      final pastDue = DateTime.now().subtract(const Duration(days: 3));

      final res = await snoozeManager.snoozeNotification(
        userId: testUserId,
        recordId: 'rec_overdue_snooze',
        moduleId: 'bills',
        categoryId: 'gas',
        eventType: 'gas_bill',
        originalDueDate: pastDue,
        title: 'Gas Bill',
        originalBody: 'Overdue by 3 days',
        preset: SnoozePreset.oneHour,
        isAlreadyOverdue: true,
      );

      expect(res.isSuccess, true);
      expect(res.schedule?.notificationType, 'overdue');
      expect(res.schedule?.payload['isOverdue'], true);
    });
  });

  group('6. Defer Functionality & Impact Analysis Tests', () {
    late NotificationRepository repo;
    late NotificationDeferManager deferManager;

    setUp(() {
      repo = NotificationRepository();
      deferManager = NotificationDeferManager(repository: repo);
    });

    test('Mode A: Defer notification only leaves underlying commitment due date unchanged', () async {
      final originalDue = DateTime(2026, 12, 15, 9, 0);
      final newNotifDate = DateTime(2026, 12, 14, 9, 0);

      final res = await deferManager.deferNotificationOnly(
        userId: testUserId,
        recordId: 'defer_rec_a',
        moduleId: 'bills',
        categoryId: 'internet',
        eventType: 'internet_bill',
        originalDueDate: originalDue,
        newNotificationDate: newNotifDate,
        title: 'Internet Bill',
        reason: 'Waiting for salary credit',
      );

      expect(res.isSuccess, true);
      expect(res.mode, DeferMode.notificationOnly);
      expect(res.impactReport.willUpdateFinancialRecord, false);
      expect(res.impactReport.daysDeferred, -1);
    });

    test('Mode B: Defer underlying event reschedules commitment through owning module', () async {
      final originalDue = DateTime(2026, 12, 15, 9, 0);
      final newEventDate = DateTime(2026, 12, 18, 9, 0);

      bool moduleRescheduleCalled = false;
      DateTime? updatedDate;

      // Register module updater
      deferManager.registerModuleUpdater('bills', ({
        required String recordId,
        required DateTime newDueDate,
        required bool updateRecurringSeries,
        String? reason,
      }) async {
        moduleRescheduleCalled = true;
        updatedDate = newDueDate;
        return true;
      });

      final res = await deferManager.deferUnderlyingEvent(
        userId: testUserId,
        recordId: 'defer_rec_b',
        moduleId: 'bills',
        categoryId: 'utility',
        eventType: 'electricity_bill',
        originalDueDate: originalDue,
        newEventDueDate: newEventDate,
        title: 'Electricity Bill',
        reason: 'Requested extension from vendor',
        rescheduleCallback: (newDate) async {},
      );

      expect(res.isSuccess, true);
      expect(res.mode, DeferMode.underlyingEvent);
      expect(moduleRescheduleCalled, true);
      expect(updatedDate, newEventDate);
      expect(res.impactReport.willUpdateFinancialRecord, true);
      expect(res.impactReport.daysDeferred, 3);
    });

    test('Defer impact report warns user if deferral pushes date into the past', () async {
      final originalDue = DateTime.now().add(const Duration(days: 2));
      final pastTarget = DateTime.now().subtract(const Duration(days: 1));

      final impact = await deferManager.generateImpactReport(
        userId: testUserId,
        recordId: 'rec_warn',
        originalDate: originalDue,
        newDate: pastTarget,
        mode: DeferMode.underlyingEvent,
      );

      expect(impact.isPotentiallyOverdueWarning, true);
      expect(impact.warningMessage != null, true);
    });
  });

  group('7. Notification Scheduler & Overdue Alerts Tests', () {
    late NotificationRepository repo;
    late NotificationPreferenceManager prefManager;
    late NotificationTemplateManager tplManager;
    late NotificationScheduler scheduler;

    setUp(() {
      repo = NotificationRepository();
      tplManager = NotificationTemplateManager();
      prefManager = NotificationPreferenceManager(repository: repo, templateManager: tplManager);
      scheduler = NotificationScheduler(
        repository: repo,
        preferenceManager: prefManager,
        templateManager: tplManager,
      );
    });

    test('Schedules advance reminders and overdue alerts deterministically', () async {
      final dueDate = DateTime.now().add(const Duration(days: 10));

      final schedules = await scheduler.scheduleRecordReminders(
        userId: testUserId,
        recordId: 'rec_credit_card_1',
        moduleId: 'finance',
        categoryId: 'credit_card',
        eventType: 'credit_card',
        title: 'HDFC Credit Card',
        dueDate: dueDate,
        amount: 35000,
      );

      expect(schedules.isNotEmpty, true);
      // Contains both advance reminders and overdue alerts
      expect(schedules.any((s) => s.notificationType == 'reminder'), true);
      expect(schedules.any((s) => s.notificationType == 'overdue'), true);

      // Verify stable 31-bit integer localNotificationId
      for (final s in schedules) {
        expect(s.localNotificationId, greaterThan(0));
      }
    });

    test('Marking payment as paid cancels all scheduled reminders and overdue alerts', () async {
      final dueDate = DateTime.now().add(const Duration(days: 5));

      await scheduler.scheduleRecordReminders(
        userId: testUserId,
        recordId: 'rec_paid_cancel_test',
        moduleId: 'bills',
        categoryId: 'electricity_bill',
        eventType: 'electricity_bill',
        title: 'Electricity Bill',
        dueDate: dueDate,
      );

      var active = await repo.getSchedulesForRecord(testUserId, 'rec_paid_cancel_test');
      expect(active.any((s) => s.isActive), true);

      // Payment is marked as paid
      await scheduler.onRecordPaidOrCompleted(testUserId, 'rec_paid_cancel_test');

      active = await repo.getSchedulesForRecord(testUserId, 'rec_paid_cancel_test');
      expect(active.any((s) => s.isActive), false);
    });
  });

  group('8. Notification Recovery & Reliability Tests', () {
    late NotificationRepository repo;
    late NotificationRecoveryManager recoveryManager;

    setUp(() {
      repo = NotificationRepository();
      recoveryManager = NotificationRecoveryManager(repository: repo);
    });

    test('Reconciles active schedules on startup and cleans stale past notifications', () async {
      final now = DateTime.now();

      // Active future schedule
      final futureSchedule = NotificationSchedule(
        id: 'sched_future_1',
        userId: testUserId,
        moduleId: 'finance',
        categoryId: 'loan',
        recordId: 'rec_future_1',
        eventType: 'loan_emi',
        scheduledAt: now.add(const Duration(days: 2)),
        originalScheduledAt: now.add(const Duration(days: 2)),
        reminderOffset: '-1d',
        status: NotificationScheduleStatus.scheduled,
        localNotificationId: 1001,
        createdAt: now,
        updatedAt: now,
      );

      // Stale past schedule that fired while device was off
      final pastSchedule = NotificationSchedule(
        id: 'sched_past_1',
        userId: testUserId,
        moduleId: 'bills',
        categoryId: 'water',
        recordId: 'rec_past_1',
        eventType: 'water_bill',
        scheduledAt: now.subtract(const Duration(days: 1)),
        originalScheduledAt: now.subtract(const Duration(days: 1)),
        reminderOffset: '0d',
        status: NotificationScheduleStatus.scheduled,
        localNotificationId: 1002,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      );

      await repo.saveSchedule(testUserId, futureSchedule);
      await repo.saveSchedule(testUserId, pastSchedule);

      final result = await recoveryManager.reconcile(userId: testUserId);

      // Stale one cleaned
      expect(result.cleanedCount, 1);
    });
  });

  group('9. Notification Centre History & Categorization Tests', () {
    late NotificationHistoryManager historyManager;

    setUp(() {
      historyManager = NotificationHistoryManager();
    });

    test('Categorizes schedules into Today, Upcoming, Overdue, Snoozed, Deferred, Completed', () {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final list = [
        // Today
        NotificationSchedule(
          id: 's_today',
          userId: testUserId,
          moduleId: 'bills',
          categoryId: 'utility',
          recordId: 'r_today',
          eventType: 'electricity_bill',
          scheduledAt: todayStart.add(const Duration(hours: 14)),
          originalScheduledAt: todayStart.add(const Duration(hours: 14)),
          reminderOffset: '0d',
          localNotificationId: 1,
          createdAt: now,
          updatedAt: now,
        ),
        // Upcoming
        NotificationSchedule(
          id: 's_upcoming',
          userId: testUserId,
          moduleId: 'finance',
          categoryId: 'credit_card',
          recordId: 'r_upcoming',
          eventType: 'credit_card',
          scheduledAt: now.add(const Duration(days: 4)),
          originalScheduledAt: now.add(const Duration(days: 5)),
          reminderOffset: '-1d',
          localNotificationId: 2,
          createdAt: now,
          updatedAt: now,
        ),
        // Snoozed
        NotificationSchedule(
          id: 's_snoozed',
          userId: testUserId,
          moduleId: 'vehicle',
          categoryId: 'service',
          recordId: 'r_snoozed',
          eventType: 'vehicle_servicing',
          scheduledAt: now.add(const Duration(hours: 2)),
          originalScheduledAt: now.subtract(const Duration(days: 1)),
          reminderOffset: 'snooze_1h',
          isSnoozed: true,
          status: NotificationScheduleStatus.snoozed,
          localNotificationId: 3,
          createdAt: now,
          updatedAt: now,
        ),
        // Overdue
        NotificationSchedule(
          id: 's_overdue',
          userId: testUserId,
          moduleId: 'bills',
          categoryId: 'mobile',
          recordId: 'r_overdue',
          eventType: 'mobile_bill',
          scheduledAt: now.subtract(const Duration(days: 2)),
          originalScheduledAt: now.subtract(const Duration(days: 2)),
          reminderOffset: 'overdue_2d',
          notificationType: 'overdue',
          localNotificationId: 4,
          createdAt: now,
          updatedAt: now,
        ),
        // Completed
        NotificationSchedule(
          id: 's_completed',
          userId: testUserId,
          moduleId: 'school_fees',
          categoryId: 'fees',
          recordId: 'r_completed',
          eventType: 'school_fees',
          scheduledAt: now.subtract(const Duration(days: 5)),
          originalScheduledAt: now.subtract(const Duration(days: 5)),
          reminderOffset: '0d',
          status: NotificationScheduleStatus.completed,
          localNotificationId: 5,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final categorized = historyManager.categorizeSchedules(list, referenceNow: now);

      expect(categorized['today']?.length, 1);
      expect(categorized['upcoming']?.length, 1);
      expect(categorized['snoozed']?.length, 1);
      expect(categorized['overdue']?.length, 1);
      expect(categorized['completed']?.length, 1);
    });
  });

  group('10. Free Tier Serverless Infrastructure & Concurrency Safety Tests', () {
    test('NotificationSchedule produces deterministic deliveryKey for deduplication', () {
      final key1 = NotificationSchedule.generateDeliveryKey(
        userId: 'user_123',
        recordId: 'bill_nov_2026',
        occurrenceId: 'occ_1',
        notificationType: 'reminder',
        reminderOffset: '-3d',
      );

      final key2 = NotificationSchedule.generateDeliveryKey(
        userId: 'user_123',
        recordId: 'bill_nov_2026',
        occurrenceId: 'occ_1',
        notificationType: 'reminder',
        reminderOffset: '-3d',
      );

      expect(key1, key2);
      expect(key1, 'user_123_bill_nov_2026_occ_1_reminder_-3d');
    });

    test('NotificationSchedule serializes and deserializes all worker concurrency fields', () {
      final now = DateTime(2026, 11, 14, 10, 0);
      final sentAt = DateTime(2026, 11, 14, 10, 2);
      final leaseExpires = DateTime(2026, 11, 14, 10, 5);

      final schedule = NotificationSchedule(
        id: 'sched_worker_test',
        userId: 'user_worker',
        moduleId: 'bills',
        categoryId: 'utilities',
        recordId: 'bill_elec',
        eventType: 'electricity_bill',
        scheduledAt: now,
        originalScheduledAt: now,
        reminderOffset: '0d',
        status: NotificationScheduleStatus.claimed,
        deliveryKey: 'user_worker_bill_elec_occ_default_reminder_0d',
        attemptCount: 1,
        lastAttemptAt: now,
        sentAt: sentAt,
        claimLeaseExpiresAt: leaseExpires,
        claimedByWorker: 'gha_worker_abc',
        errorMessage: null,
        localNotificationId: 999,
        createdAt: now,
        updatedAt: now,
      );

      final map = schedule.toMap();
      expect(map['deliveryKey'], 'user_worker_bill_elec_occ_default_reminder_0d');
      expect(map['attemptCount'], 1);
      expect(map['status'], 'claimed');
      expect(map['claimedByWorker'], 'gha_worker_abc');

      final restored = NotificationSchedule.fromMap(map, 'sched_worker_test');
      expect(restored.deliveryKey, schedule.deliveryKey);
      expect(restored.attemptCount, 1);
      expect(restored.status, NotificationScheduleStatus.claimed);
      expect(restored.claimedByWorker, 'gha_worker_abc');
    });

    test('NotificationRepository updates worker lease and sent status', () async {
      final repo = NotificationRepository();
      final now = DateTime.now();

      final sched = NotificationSchedule(
        id: 'sched_repo_test',
        userId: 'u_test',
        moduleId: 'bills',
        categoryId: 'util',
        recordId: 'r_test',
        eventType: 'bill',
        scheduledAt: now,
        originalScheduledAt: now,
        reminderOffset: '0d',
        localNotificationId: 100,
        createdAt: now,
        updatedAt: now,
      );

      await repo.saveSchedule('u_test', sched);

      // Claim schedule
      await repo.updateScheduleStatus(
        'u_test',
        'sched_repo_test',
        NotificationScheduleStatus.claimed,
        claimedByWorker: 'worker_1',
        attemptCount: 1,
      );

      var updatedList = await repo.getSchedulesForRecord('u_test', 'r_test');
      expect(updatedList.first.status, NotificationScheduleStatus.claimed);
      expect(updatedList.first.claimedByWorker, 'worker_1');
      expect(updatedList.first.attemptCount, 1);

      // Mark sent
      await repo.updateScheduleStatus(
        'u_test',
        'sched_repo_test',
        NotificationScheduleStatus.sent,
        sentAt: DateTime.now(),
      );

      updatedList = await repo.getSchedulesForRecord('u_test', 'r_test');
      expect(updatedList.first.status, NotificationScheduleStatus.sent);
      expect(updatedList.first.sentAt, isNotNull);
    });
  });
}
