import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_enums.dart';

class NotificationChannelManager {
  static final NotificationChannelManager _instance = NotificationChannelManager._internal();
  factory NotificationChannelManager() => _instance;
  NotificationChannelManager._internal();

  static const String channelFinancialUrgent = 'financial_urgent';
  static const String channelFinancialReminders = 'financial_reminders';
  static const String channelMaintenance = 'maintenance_service';
  static const String channelSnoozeDefer = 'snooze_defer';
  static const String channelOverdue = 'overdue_alerts';
  static const String channelGeneral = 'general_reminders';

  final List<AndroidNotificationChannel> androidChannels = [
    const AndroidNotificationChannel(
      channelFinancialUrgent,
      'High Priority Financial Alerts',
      description: 'Urgent alerts for payments due today or overdue',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
    const AndroidNotificationChannel(
      channelFinancialReminders,
      'Financial Reminders',
      description: 'Advance reminders for upcoming bills, EMIs, and investments',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    ),
    const AndroidNotificationChannel(
      channelMaintenance,
      'Maintenance & Service Alerts',
      description: 'Vehicle servicing, warranty expiration, and appliance maintenance',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    ),
    const AndroidNotificationChannel(
      channelSnoozeDefer,
      'Rescheduled & Snoozed Reminders',
      description: 'Alerts postponed by user via snooze or defer',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ),
    const AndroidNotificationChannel(
      channelOverdue,
      'Overdue Commitment Alerts',
      description: 'Persistent reminders for pending overdue commitments',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
    const AndroidNotificationChannel(
      channelGeneral,
      'General Diary Reminders',
      description: 'Personal, household, and domestic diary reminders',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    ),
  ];

  Future<void> initializeChannels(FlutterLocalNotificationsPlugin plugin) async {
    final androidImpl =
        plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      for (final channel in androidChannels) {
        await androidImpl.createNotificationChannel(channel);
      }
    }
  }

  NotificationDetails buildNotificationDetails({
    required NotificationChannelType channelType,
    required bool soundEnabled,
    required bool vibrationEnabled,
    required PrivacyMode privacyMode,
    List<NotificationActionType> actions = const [],
  }) {
    final channelId = channelType.channelId;
    final channelName = channelType.channelName;
    final channelDesc = channelType.description;

    Importance importance;
    Priority priority;

    switch (channelType) {
      case NotificationChannelType.financialUrgent:
      case NotificationChannelType.overdueAlerts:
        importance = Importance.max;
        priority = Priority.max;
        break;
      case NotificationChannelType.snoozeDefer:
        importance = Importance.high;
        priority = Priority.high;
        break;
      case NotificationChannelType.financialReminders:
      case NotificationChannelType.maintenanceService:
      case NotificationChannelType.generalReminders:
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        break;
    }

    // Lock screen privacy visibility
    NotificationVisibility visibility = NotificationVisibility.public;
    if (privacyMode == PrivacyMode.masked) {
      visibility = NotificationVisibility.private;
    } else if (privacyMode == PrivacyMode.generic) {
      visibility = NotificationVisibility.secret;
    }

    // Build interactive action buttons for Android
    final androidActions = <AndroidNotificationAction>[];
    for (final action in actions) {
      switch (action) {
        case NotificationActionType.markPaid:
          androidActions.add(const AndroidNotificationAction(
            'PAID',
            'Mark Paid',
            showsUserInterface: true,
          ));
          break;
        case NotificationActionType.snooze:
          androidActions.add(const AndroidNotificationAction(
            'SNOOZE_1H',
            'Snooze 1h',
            showsUserInterface: false,
          ));
          androidActions.add(const AndroidNotificationAction(
            'SNOOZE_MORE',
            'More...',
            showsUserInterface: true,
          ));
          break;
        case NotificationActionType.defer:
          androidActions.add(const AndroidNotificationAction(
            'DEFER',
            'Defer',
            showsUserInterface: true,
          ));
          break;
        case NotificationActionType.markComplete:
          androidActions.add(const AndroidNotificationAction(
            'COMPLETE',
            'Complete',
            showsUserInterface: false,
          ));
          break;
        case NotificationActionType.open:
          androidActions.add(const AndroidNotificationAction(
            'OPEN',
            'Open',
            showsUserInterface: true,
          ));
          break;
        case NotificationActionType.dismiss:
          break;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
      visibility: visibility,
      actions: androidActions.isNotEmpty ? androidActions : null,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }
}
