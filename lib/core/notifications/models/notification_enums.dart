enum NotificationChannelType {
  financialUrgent('financial_urgent', 'High Priority Financial Alerts', 'Urgent alerts for payments due today or overdue'),
  financialReminders('financial_reminders', 'Financial Reminders', 'Scheduled advance notices for upcoming bills and commitments'),
  maintenanceService('maintenance_service', 'Maintenance & Service Alerts', 'Vehicle servicing, warranty expiration, and appliance maintenance'),
  snoozeDefer('snooze_defer', 'Rescheduled & Snoozed Reminders', 'Alerts postponed by user via snooze or defer'),
  overdueAlerts('overdue_alerts', 'Overdue Commitment Alerts', 'Persistent reminders for pending overdue commitments'),
  generalReminders('general_reminders', 'General Diary Reminders', 'Personal, family, and domestic diary reminders');

  final String channelId;
  final String channelName;
  final String description;

  const NotificationChannelType(this.channelId, this.channelName, this.description);
}

enum NotificationPriority {
  low,
  medium,
  high,
  urgent;

  static NotificationPriority fromString(String? val) {
    if (val == null) return NotificationPriority.medium;
    switch (val.toLowerCase().trim()) {
      case 'low':
        return NotificationPriority.low;
      case 'high':
        return NotificationPriority.high;
      case 'urgent':
      case 'critical':
        return NotificationPriority.urgent;
      case 'medium':
      default:
        return NotificationPriority.medium;
    }
  }
}

enum NotificationActionType {
  open('OPEN', 'Open Record'),
  snooze('SNOOZE', 'Snooze'),
  defer('DEFER', 'Defer'),
  markPaid('PAID', 'Mark Paid'),
  markComplete('COMPLETE', 'Mark Complete'),
  dismiss('DISMISS', 'Dismiss');

  final String actionId;
  final String label;

  const NotificationActionType(this.actionId, this.label);

  static NotificationActionType fromString(String? val) {
    if (val == null) return NotificationActionType.open;
    final clean = val.toUpperCase().trim();
    for (final a in NotificationActionType.values) {
      if (a.actionId == clean || a.name.toUpperCase() == clean) return a;
    }
    return NotificationActionType.open;
  }
}

enum NotificationScheduleStatus {
  scheduled,
  claimed,
  sent,
  displayed,
  opened,
  snoozed,
  deferred,
  completed,
  cancelled,
  failed;

  static NotificationScheduleStatus fromString(String? val) {
    if (val == null) return NotificationScheduleStatus.scheduled;
    switch (val.toLowerCase().trim()) {
      case 'claimed':
        return NotificationScheduleStatus.claimed;
      case 'sent':
        return NotificationScheduleStatus.sent;
      case 'displayed':
        return NotificationScheduleStatus.displayed;
      case 'opened':
        return NotificationScheduleStatus.opened;
      case 'snoozed':
        return NotificationScheduleStatus.snoozed;
      case 'deferred':
        return NotificationScheduleStatus.deferred;
      case 'completed':
      case 'paid':
        return NotificationScheduleStatus.completed;
      case 'cancelled':
        return NotificationScheduleStatus.cancelled;
      case 'failed':
        return NotificationScheduleStatus.failed;
      case 'scheduled':
      case 'pending':
      default:
        return NotificationScheduleStatus.scheduled;
    }
  }
}

enum ScheduleSource {
  defaultTemplate,
  moduleDefault,
  categoryOverride,
  individualOverride,
  snooze,
  deferModeA,
  deferModeB,
  overdueAlert;

  static ScheduleSource fromString(String? val) {
    if (val == null) return ScheduleSource.defaultTemplate;
    switch (val.toLowerCase().trim()) {
      case 'moduledefault':
      case 'module_default':
        return ScheduleSource.moduleDefault;
      case 'categoryoverride':
      case 'category_override':
        return ScheduleSource.categoryOverride;
      case 'individualoverride':
      case 'individual_override':
        return ScheduleSource.individualOverride;
      case 'snooze':
        return ScheduleSource.snooze;
      case 'defermodea':
      case 'defer_mode_a':
        return ScheduleSource.deferModeA;
      case 'defermodeb':
      case 'defer_mode_b':
        return ScheduleSource.deferModeB;
      case 'overduealert':
      case 'overdue_alert':
        return ScheduleSource.overdueAlert;
      case 'defaulttemplate':
      case 'default_template':
      default:
        return ScheduleSource.defaultTemplate;
    }
  }
}

enum InheritanceStatus {
  inheritedFromGlobal,
  inheritedFromModule,
  inheritedFromCategory,
  customized;

  String get label {
    switch (this) {
      case InheritanceStatus.inheritedFromGlobal:
        return 'Inherited from Global Settings';
      case InheritanceStatus.inheritedFromModule:
        return 'Inherited from Module Defaults';
      case InheritanceStatus.inheritedFromCategory:
        return 'Inherited from Category Settings';
      case InheritanceStatus.customized:
        return 'Customized for this item';
    }
  }
}

enum PrivacyMode {
  detailed, // Full details (amount, account, sensitive details)
  masked,   // Partially masked: "Payment of ₹•••• due in 3 days"
  generic;  // Privacy friendly: "A commitment is due soon"

  static PrivacyMode fromString(String? val) {
    if (val == null) return PrivacyMode.detailed;
    switch (val.toLowerCase().trim()) {
      case 'masked':
        return PrivacyMode.masked;
      case 'generic':
      case 'privacy_friendly':
        return PrivacyMode.generic;
      case 'detailed':
      default:
        return PrivacyMode.detailed;
    }
  }
}

enum SnoozePreset {
  tenMinutes(10, '10 minutes'),
  thirtyMinutes(30, '30 minutes'),
  oneHour(60, '1 hour'),
  threeHours(180, '3 hours'),
  tomorrowMorning(null, 'Tomorrow at preferred time'),
  nextWorkingDay(null, 'Next working day'),
  custom(null, 'Custom date & time');

  final int? minutes;
  final String label;

  const SnoozePreset(this.minutes, this.label);
}

enum DeferMode {
  notificationOnly, // Mode A: Postpone notification without changing due date
  underlyingEvent;  // Mode B: Reschedule actual event or commitment date

  static DeferMode fromString(String? val) {
    if (val == null) return DeferMode.notificationOnly;
    return val.toLowerCase().contains('event')
        ? DeferMode.underlyingEvent
        : DeferMode.notificationOnly;
  }
}

enum DeferPreset {
  laterToday('Later today'),
  tomorrow('Tomorrow'),
  nextWorkingDay('Next working day'),
  in2Days('In 2 days'),
  in3Days('In 3 days'),
  nextWeek('Next week'),
  nextMonth('Next month'),
  custom('Select custom date and time');

  final String label;

  const DeferPreset(this.label);
}

enum ReminderUnit {
  minutes,
  hours,
  days,
  weeks,
  onDate;

  static ReminderUnit fromString(String? val) {
    if (val == null) return ReminderUnit.days;
    switch (val.toLowerCase().trim()) {
      case 'minutes':
      case 'minute':
      case 'min':
      case 'm':
        return ReminderUnit.minutes;
      case 'hours':
      case 'hour':
      case 'hr':
      case 'h':
        return ReminderUnit.hours;
      case 'weeks':
      case 'week':
      case 'w':
        return ReminderUnit.weeks;
      case 'ondate':
      case 'on_date':
      case 'sameday':
        return ReminderUnit.onDate;
      case 'days':
      case 'day':
      case 'd':
      default:
        return ReminderUnit.days;
    }
  }
}
