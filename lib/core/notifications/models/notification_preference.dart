import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_enums.dart';
import 'reminder_interval.dart';
import 'time_of_day_dto.dart';

class NotificationPreference {
  final String id;
  final String userId;
  final String level; // 'global', 'module', 'category', 'individual'
  final String? targetId; // moduleId, categoryId, or recordId

  final bool? isEnabled;
  final List<ReminderInterval>? reminderIntervals;
  final TimeOfDayDto? preferredNotificationTime;

  final bool? quietHoursEnabled;
  final TimeOfDayDto? quietHoursStart;
  final TimeOfDayDto? quietHoursEnd;

  final bool? allowWeekendNotifications;
  final bool? soundEnabled;
  final bool? vibrationEnabled;
  final PrivacyMode? privacyMode;

  final bool? overdueAlertsEnabled;
  final List<int>? overdueIntervalsDays;

  final int? defaultSnoozeMinutes;
  final int? maxSnoozeCount;

  final Map<String, dynamic> customOverrides;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreference({
    required this.id,
    required this.userId,
    required this.level,
    this.targetId,
    this.isEnabled,
    this.reminderIntervals,
    this.preferredNotificationTime,
    this.quietHoursEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.allowWeekendNotifications,
    this.soundEnabled,
    this.vibrationEnabled,
    this.privacyMode,
    this.overdueAlertsEnabled,
    this.overdueIntervalsDays,
    this.defaultSnoozeMinutes,
    this.maxSnoozeCount,
    this.customOverrides = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  static NotificationPreference defaultGlobal(String userId) {
    final now = DateTime.now();
    return NotificationPreference(
      id: 'global',
      userId: userId,
      level: 'global',
      isEnabled: true,
      reminderIntervals: const [ReminderInterval.oneDayBefore],
      preferredNotificationTime: TimeOfDayDto.defaultPreferred,
      quietHoursEnabled: true,
      quietHoursStart: TimeOfDayDto.defaultQuietStart,
      quietHoursEnd: TimeOfDayDto.defaultQuietEnd,
      allowWeekendNotifications: true,
      soundEnabled: true,
      vibrationEnabled: true,
      privacyMode: PrivacyMode.detailed,
      overdueAlertsEnabled: true,
      overdueIntervalsDays: const [0, 1, 3, 7],
      defaultSnoozeMinutes: 60,
      maxSnoozeCount: 5,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'level': level,
        if (targetId != null) 'targetId': targetId,
        if (isEnabled != null) 'isEnabled': isEnabled,
        if (reminderIntervals != null)
          'reminderIntervals': reminderIntervals!.map((i) => i.toMap()).toList(),
        if (preferredNotificationTime != null)
          'preferredNotificationTime': preferredNotificationTime!.toMap(),
        if (quietHoursEnabled != null) 'quietHoursEnabled': quietHoursEnabled,
        if (quietHoursStart != null) 'quietHoursStart': quietHoursStart!.toMap(),
        if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd!.toMap(),
        if (allowWeekendNotifications != null)
          'allowWeekendNotifications': allowWeekendNotifications,
        if (soundEnabled != null) 'soundEnabled': soundEnabled,
        if (vibrationEnabled != null) 'vibrationEnabled': vibrationEnabled,
        if (privacyMode != null) 'privacyMode': privacyMode!.name,
        if (overdueAlertsEnabled != null) 'overdueAlertsEnabled': overdueAlertsEnabled,
        if (overdueIntervalsDays != null) 'overdueIntervalsDays': overdueIntervalsDays,
        if (defaultSnoozeMinutes != null) 'defaultSnoozeMinutes': defaultSnoozeMinutes,
        if (maxSnoozeCount != null) 'maxSnoozeCount': maxSnoozeCount,
        'customOverrides': customOverrides,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory NotificationPreference.fromMap(Map<String, dynamic> map, [String? docId]) {
    final now = DateTime.now();
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? now;
      return now;
    }

    List<ReminderInterval>? parseIntervals(dynamic list) {
      if (list is List) {
        return list
            .map((item) => ReminderInterval.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return null;
    }

    List<int>? parseIntList(dynamic list) {
      if (list is List) {
        return list.map((e) => (e as num).toInt()).toList();
      }
      return null;
    }

    return NotificationPreference(
      id: docId ?? map['id'] as String? ?? 'pref_${DateTime.now().millisecondsSinceEpoch}',
      userId: map['userId'] as String? ?? '',
      level: map['level'] as String? ?? 'global',
      targetId: map['targetId'] as String?,
      isEnabled: map['isEnabled'] as bool?,
      reminderIntervals: parseIntervals(map['reminderIntervals']),
      preferredNotificationTime: map['preferredNotificationTime'] != null
          ? TimeOfDayDto.fromMap(map['preferredNotificationTime'] as Map<String, dynamic>)
          : null,
      quietHoursEnabled: map['quietHoursEnabled'] as bool?,
      quietHoursStart: map['quietHoursStart'] != null
          ? TimeOfDayDto.fromMap(map['quietHoursStart'] as Map<String, dynamic>)
          : null,
      quietHoursEnd: map['quietHoursEnd'] != null
          ? TimeOfDayDto.fromMap(map['quietHoursEnd'] as Map<String, dynamic>)
          : null,
      allowWeekendNotifications: map['allowWeekendNotifications'] as bool?,
      soundEnabled: map['soundEnabled'] as bool?,
      vibrationEnabled: map['vibrationEnabled'] as bool?,
      privacyMode: map['privacyMode'] != null
          ? PrivacyMode.fromString(map['privacyMode'] as String?)
          : null,
      overdueAlertsEnabled: map['overdueAlertsEnabled'] as bool?,
      overdueIntervalsDays: parseIntList(map['overdueIntervalsDays']),
      defaultSnoozeMinutes: (map['defaultSnoozeMinutes'] as num?)?.toInt(),
      maxSnoozeCount: (map['maxSnoozeCount'] as num?)?.toInt(),
      customOverrides: map['customOverrides'] is Map
          ? Map<String, dynamic>.from(map['customOverrides'] as Map)
          : const {},
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  NotificationPreference copyWith({
    String? id,
    String? userId,
    String? level,
    String? targetId,
    bool? isEnabled,
    List<ReminderInterval>? reminderIntervals,
    TimeOfDayDto? preferredNotificationTime,
    bool? quietHoursEnabled,
    TimeOfDayDto? quietHoursStart,
    TimeOfDayDto? quietHoursEnd,
    bool? allowWeekendNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
    PrivacyMode? privacyMode,
    bool? overdueAlertsEnabled,
    List<int>? overdueIntervalsDays,
    int? defaultSnoozeMinutes,
    int? maxSnoozeCount,
    Map<String, dynamic>? customOverrides,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreference(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      level: level ?? this.level,
      targetId: targetId ?? this.targetId,
      isEnabled: isEnabled ?? this.isEnabled,
      reminderIntervals: reminderIntervals ?? this.reminderIntervals,
      preferredNotificationTime: preferredNotificationTime ?? this.preferredNotificationTime,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      allowWeekendNotifications: allowWeekendNotifications ?? this.allowWeekendNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      privacyMode: privacyMode ?? this.privacyMode,
      overdueAlertsEnabled: overdueAlertsEnabled ?? this.overdueAlertsEnabled,
      overdueIntervalsDays: overdueIntervalsDays ?? this.overdueIntervalsDays,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      customOverrides: customOverrides ?? this.customOverrides,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EffectiveNotificationPreference {
  final bool isEnabled;
  final List<ReminderInterval> reminderIntervals;
  final TimeOfDayDto preferredNotificationTime;
  final bool quietHoursEnabled;
  final TimeOfDayDto quietHoursStart;
  final TimeOfDayDto quietHoursEnd;
  final bool allowWeekendNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final PrivacyMode privacyMode;
  final bool overdueAlertsEnabled;
  final List<int> overdueIntervalsDays;
  final int defaultSnoozeMinutes;
  final int maxSnoozeCount;

  // Inheritance Metadata
  final InheritanceStatus intervalsSource;
  final InheritanceStatus timeSource;
  final InheritanceStatus quietHoursSource;
  final InheritanceStatus overdueSource;
  final InheritanceStatus privacySource;
  final InheritanceStatus soundSource;

  const EffectiveNotificationPreference({
    required this.isEnabled,
    required this.reminderIntervals,
    required this.preferredNotificationTime,
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.allowWeekendNotifications,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.privacyMode,
    required this.overdueAlertsEnabled,
    required this.overdueIntervalsDays,
    required this.defaultSnoozeMinutes,
    required this.maxSnoozeCount,
    required this.intervalsSource,
    required this.timeSource,
    required this.quietHoursSource,
    required this.overdueSource,
    required this.privacySource,
    required this.soundSource,
  });

  bool get isEntirelyInherited =>
      intervalsSource != InheritanceStatus.customized &&
      timeSource != InheritanceStatus.customized &&
      overdueSource != InheritanceStatus.customized;
}
