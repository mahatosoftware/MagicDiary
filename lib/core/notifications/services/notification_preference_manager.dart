import '../models/notification_enums.dart';
import '../models/notification_preference.dart';
import '../models/reminder_interval.dart';
import '../models/time_of_day_dto.dart';
import '../repositories/notification_repository.dart';
import 'notification_template_manager.dart';

class NotificationPreferenceManager {
  final NotificationRepository _repository;
  final NotificationTemplateManager _templateManager;

  NotificationPreferenceManager({
    NotificationRepository? repository,
    NotificationTemplateManager? templateManager,
  })  : _repository = repository ?? NotificationRepository(),
        _templateManager = templateManager ?? NotificationTemplateManager();

  // Resolves effective preference through the 4-level hierarchy:
  // Individual -> Category -> Module -> Global -> Template/System Default
  Future<EffectiveNotificationPreference> getEffectivePreference({
    required String userId,
    String? moduleId,
    String? categoryId,
    String? recordId,
    String? eventType,
  }) async {
    // 1. Fetch preferences up the hierarchy
    final recordOverride = (recordId != null && recordId.isNotEmpty)
        ? await _repository.getRecordOverride(userId, recordId)
        : null;

    final categoryPref = (categoryId != null && categoryId.isNotEmpty)
        ? await _repository.getCategoryPreference(userId, categoryId)
        : null;

    final modulePref = (moduleId != null && moduleId.isNotEmpty)
        ? await _repository.getModulePreference(userId, moduleId)
        : null;

    final globalPref = await _repository.getGlobalPreference(userId) ??
        NotificationPreference.defaultGlobal(userId);

    // Fallback template defaults if applicable
    final template = (moduleId != null && eventType != null)
        ? _templateManager.getTemplate(moduleId, eventType)
        : null;

    final systemDefaultIntervals = template?.defaultIntervals ??
        globalPref.reminderIntervals ??
        const [ReminderInterval.oneDayBefore];

    // --- Resolve Master Enabled ---
    bool isEnabled = true;
    if (recordOverride?.isEnabled != null) {
      isEnabled = recordOverride!.isEnabled!;
    } else if (categoryPref?.isEnabled != null) {
      isEnabled = categoryPref!.isEnabled!;
    } else if (modulePref?.isEnabled != null) {
      isEnabled = modulePref!.isEnabled!;
    } else if (globalPref.isEnabled != null) {
      isEnabled = globalPref.isEnabled!;
    }

    // --- Resolve Reminder Intervals & Inheritance Status ---
    List<ReminderInterval> intervals;
    InheritanceStatus intervalsSource;

    if (recordOverride?.reminderIntervals != null && recordOverride!.reminderIntervals!.isNotEmpty) {
      intervals = recordOverride.reminderIntervals!;
      intervalsSource = InheritanceStatus.customized;
    } else if (categoryPref?.reminderIntervals != null && categoryPref!.reminderIntervals!.isNotEmpty) {
      intervals = categoryPref.reminderIntervals!;
      intervalsSource = InheritanceStatus.inheritedFromCategory;
    } else if (modulePref?.reminderIntervals != null && modulePref!.reminderIntervals!.isNotEmpty) {
      intervals = modulePref.reminderIntervals!;
      intervalsSource = InheritanceStatus.inheritedFromModule;
    } else if (template != null && template.defaultIntervals.isNotEmpty) {
      intervals = template.defaultIntervals;
      intervalsSource = InheritanceStatus.inheritedFromModule;
    } else if (globalPref.reminderIntervals != null && globalPref.reminderIntervals!.isNotEmpty) {
      intervals = globalPref.reminderIntervals!;
      intervalsSource = InheritanceStatus.inheritedFromGlobal;
    } else {
      intervals = systemDefaultIntervals;
      intervalsSource = InheritanceStatus.inheritedFromGlobal;
    }

    // --- Resolve Preferred Notification Time ---
    TimeOfDayDto prefTime;
    InheritanceStatus timeSource;

    if (recordOverride?.preferredNotificationTime != null) {
      prefTime = recordOverride!.preferredNotificationTime!;
      timeSource = InheritanceStatus.customized;
    } else if (categoryPref?.preferredNotificationTime != null) {
      prefTime = categoryPref!.preferredNotificationTime!;
      timeSource = InheritanceStatus.inheritedFromCategory;
    } else if (modulePref?.preferredNotificationTime != null) {
      prefTime = modulePref!.preferredNotificationTime!;
      timeSource = InheritanceStatus.inheritedFromModule;
    } else {
      prefTime = globalPref.preferredNotificationTime ?? TimeOfDayDto.defaultPreferred;
      timeSource = InheritanceStatus.inheritedFromGlobal;
    }

    // --- Resolve Quiet Hours ---
    bool quietHoursEnabled;
    TimeOfDayDto quietHoursStart;
    TimeOfDayDto quietHoursEnd;
    InheritanceStatus quietHoursSource;

    if (modulePref?.quietHoursEnabled != null) {
      quietHoursEnabled = modulePref!.quietHoursEnabled!;
      quietHoursStart = modulePref.quietHoursStart ?? TimeOfDayDto.defaultQuietStart;
      quietHoursEnd = modulePref.quietHoursEnd ?? TimeOfDayDto.defaultQuietEnd;
      quietHoursSource = InheritanceStatus.inheritedFromModule;
    } else {
      quietHoursEnabled = globalPref.quietHoursEnabled ?? true;
      quietHoursStart = globalPref.quietHoursStart ?? TimeOfDayDto.defaultQuietStart;
      quietHoursEnd = globalPref.quietHoursEnd ?? TimeOfDayDto.defaultQuietEnd;
      quietHoursSource = InheritanceStatus.inheritedFromGlobal;
    }

    // --- Resolve Overdue Alerts ---
    bool overdueAlertsEnabled;
    List<int> overdueIntervalsDays;
    InheritanceStatus overdueSource;

    if (modulePref?.overdueAlertsEnabled != null) {
      overdueAlertsEnabled = modulePref!.overdueAlertsEnabled!;
      overdueIntervalsDays = modulePref.overdueIntervalsDays ??
          globalPref.overdueIntervalsDays ??
          const [0, 1, 3, 7];
      overdueSource = InheritanceStatus.inheritedFromModule;
    } else {
      overdueAlertsEnabled = globalPref.overdueAlertsEnabled ?? true;
      overdueIntervalsDays = globalPref.overdueIntervalsDays ?? const [0, 1, 3, 7];
      overdueSource = InheritanceStatus.inheritedFromGlobal;
    }

    // --- Resolve Privacy Mode ---
    PrivacyMode privacyMode;
    InheritanceStatus privacySource;

    if (recordOverride?.privacyMode != null) {
      privacyMode = recordOverride!.privacyMode!;
      privacySource = InheritanceStatus.customized;
    } else if (modulePref?.privacyMode != null) {
      privacyMode = modulePref!.privacyMode!;
      privacySource = InheritanceStatus.inheritedFromModule;
    } else {
      privacyMode = globalPref.privacyMode ?? PrivacyMode.detailed;
      privacySource = InheritanceStatus.inheritedFromGlobal;
    }

    // --- Sound & Vibration ---
    bool soundEnabled = recordOverride?.soundEnabled ??
        modulePref?.soundEnabled ??
        globalPref.soundEnabled ??
        true;
    bool vibrationEnabled = recordOverride?.vibrationEnabled ??
        modulePref?.vibrationEnabled ??
        globalPref.vibrationEnabled ??
        true;

    InheritanceStatus soundSource = (recordOverride?.soundEnabled != null)
        ? InheritanceStatus.customized
        : (modulePref?.soundEnabled != null)
            ? InheritanceStatus.inheritedFromModule
            : InheritanceStatus.inheritedFromGlobal;

    // --- Weekends & Snooze Settings ---
    bool allowWeekend = modulePref?.allowWeekendNotifications ??
        globalPref.allowWeekendNotifications ??
        true;
    int defaultSnooze = recordOverride?.defaultSnoozeMinutes ??
        modulePref?.defaultSnoozeMinutes ??
        globalPref.defaultSnoozeMinutes ??
        60;
    int maxSnooze = recordOverride?.maxSnoozeCount ??
        modulePref?.maxSnoozeCount ??
        globalPref.maxSnoozeCount ??
        5;

    return EffectiveNotificationPreference(
      isEnabled: isEnabled,
      reminderIntervals: intervals,
      preferredNotificationTime: prefTime,
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
      allowWeekendNotifications: allowWeekend,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
      privacyMode: privacyMode,
      overdueAlertsEnabled: overdueAlertsEnabled,
      overdueIntervalsDays: overdueIntervalsDays,
      defaultSnoozeMinutes: defaultSnooze,
      maxSnoozeCount: maxSnooze,
      intervalsSource: intervalsSource,
      timeSource: timeSource,
      quietHoursSource: quietHoursSource,
      overdueSource: overdueSource,
      privacySource: privacySource,
      soundSource: soundSource,
    );
  }

  // --- Reset & Restore Operations ---

  Future<void> restoreDefaults(String userId) async {
    final defaultGlobal = NotificationPreference.defaultGlobal(userId);
    await _repository.saveGlobalPreference(defaultGlobal);
  }

  Future<void> resetModuleSettings(String userId, String moduleId) async {
    await _repository.deleteModulePreference(userId, moduleId);
  }

  Future<void> resetCategorySettings(String userId, String categoryId) async {
    await _repository.deleteCategoryPreference(userId, categoryId);
  }

  Future<void> resetRecordOverride(String userId, String recordId) async {
    await _repository.deleteRecordOverride(userId, recordId);
  }

  // --- Preview Schedule Calculation ---

  Future<List<DateTime>> previewSchedule({
    required String userId,
    required DateTime eventDate,
    String? moduleId,
    String? categoryId,
    String? recordId,
    String? eventType,
  }) async {
    final effective = await getEffectivePreference(
      userId: userId,
      moduleId: moduleId,
      categoryId: categoryId,
      recordId: recordId,
      eventType: eventType,
    );

    if (!effective.isEnabled) return const [];

    final dates = <DateTime>[];
    for (final interval in effective.reminderIntervals) {
      final trigger = interval.calculateTriggerTime(eventDate, effective.preferredNotificationTime);
      dates.add(trigger);
    }
    dates.sort();
    return dates;
  }
}
