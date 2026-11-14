import 'notification_enums.dart';
import 'reminder_interval.dart';

class NotificationTemplate {
  final String id;
  final String moduleId;
  final String eventType;
  final String titleTemplate;
  final String bodyTemplate;
  final String? maskedBodyTemplate;
  final String? genericBodyTemplate;
  final List<ReminderInterval> defaultIntervals;
  final NotificationChannelType channelType;
  final NotificationPriority priority;
  final List<NotificationActionType> suggestedActions;
  final Map<String, dynamic> metadata;

  const NotificationTemplate({
    required this.id,
    required this.moduleId,
    required this.eventType,
    required this.titleTemplate,
    required this.bodyTemplate,
    this.maskedBodyTemplate,
    this.genericBodyTemplate,
    required this.defaultIntervals,
    this.channelType = NotificationChannelType.generalReminders,
    this.priority = NotificationPriority.medium,
    this.suggestedActions = const [
      NotificationActionType.markPaid,
      NotificationActionType.snooze,
      NotificationActionType.defer,
      NotificationActionType.open,
    ],
    this.metadata = const {},
  });

  String formatTitle(Map<String, dynamic> data) {
    return _replaceTokens(titleTemplate, data);
  }

  String formatBody(Map<String, dynamic> data, [PrivacyMode privacyMode = PrivacyMode.detailed]) {
    switch (privacyMode) {
      case PrivacyMode.generic:
        if (genericBodyTemplate != null && genericBodyTemplate!.isNotEmpty) {
          return _replaceTokens(genericBodyTemplate!, data);
        }
        return 'You have an upcoming scheduled commitment.';
      case PrivacyMode.masked:
        if (maskedBodyTemplate != null && maskedBodyTemplate!.isNotEmpty) {
          return _replaceTokens(maskedBodyTemplate!, data);
        }
        // If no explicit masked template, replace amount with masked value
        final maskedData = Map<String, dynamic>.from(data);
        if (maskedData.containsKey('amount')) {
          final currency = maskedData['currency'] ?? '₹';
          maskedData['amount'] = '$currency••••';
        }
        return _replaceTokens(bodyTemplate, maskedData);
      case PrivacyMode.detailed:
        return _replaceTokens(bodyTemplate, data);
    }
  }

  static String _replaceTokens(String template, Map<String, dynamic> data) {
    var result = template;
    for (final entry in data.entries) {
      final token = '{${entry.key}}';
      result = result.replaceAll(token, entry.value?.toString() ?? '');
    }
    // Clean up any remaining unpopulated {token} tags
    result = result.replaceAll(RegExp(r'\{[a-zA-Z0-9_]+\}'), '').trim();
    return result;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'moduleId': moduleId,
        'eventType': eventType,
        'titleTemplate': titleTemplate,
        'bodyTemplate': bodyTemplate,
        if (maskedBodyTemplate != null) 'maskedBodyTemplate': maskedBodyTemplate,
        if (genericBodyTemplate != null) 'genericBodyTemplate': genericBodyTemplate,
        'defaultIntervals': defaultIntervals.map((i) => i.toMap()).toList(),
        'channelType': channelType.name,
        'priority': priority.name,
        'suggestedActions': suggestedActions.map((a) => a.actionId).toList(),
        'metadata': metadata,
      };

  factory NotificationTemplate.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawIntervals = map['defaultIntervals'];
    List<ReminderInterval> intervals = const [ReminderInterval.oneDayBefore];
    if (rawIntervals is List) {
      intervals = rawIntervals
          .map((i) => ReminderInterval.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList();
    }

    final rawActions = map['suggestedActions'];
    List<NotificationActionType> actions = const [
      NotificationActionType.markPaid,
      NotificationActionType.snooze,
      NotificationActionType.defer,
      NotificationActionType.open,
    ];
    if (rawActions is List) {
      actions = rawActions.map((a) => NotificationActionType.fromString(a.toString())).toList();
    }

    return NotificationTemplate(
      id: docId ?? map['id'] as String? ?? 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      moduleId: map['moduleId'] as String? ?? 'general',
      eventType: map['eventType'] as String? ?? 'general',
      titleTemplate: map['titleTemplate'] as String? ?? 'Reminder',
      bodyTemplate: map['bodyTemplate'] as String? ?? 'You have an upcoming event.',
      maskedBodyTemplate: map['maskedBodyTemplate'] as String?,
      genericBodyTemplate: map['genericBodyTemplate'] as String?,
      defaultIntervals: intervals,
      channelType: NotificationChannelType.values.firstWhere(
        (c) => c.name == map['channelType'],
        orElse: () => NotificationChannelType.generalReminders,
      ),
      priority: NotificationPriority.fromString(map['priority'] as String?),
      suggestedActions: actions,
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const {},
    );
  }
}
