import 'secure_storage_service.dart';

class SanitizedNotificationPayload {
  final String title;
  final String body;
  final String? actionRoute;
  final bool wasMasked;

  SanitizedNotificationPayload({
    required this.title,
    required this.body,
    this.actionRoute,
    this.wasMasked = false,
  });
}

/// Centralized Notification Privacy Service.
/// Masks sensitive health, financial, and personal details on lock screens.
class NotificationPrivacyService {
  final SecureStorageService _secureStorage;

  NotificationPrivacyService({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  /// Sanitizes notification content based on user's privacy preference.
  Future<SanitizedNotificationPayload> sanitizeNotification({
    required String rawTitle,
    required String rawBody,
    required String module,
    String? actionRoute,
  }) async {
    final hideSensitive = await _secureStorage.isHideSensitiveNotifications();
    if (!hideSensitive) {
      return SanitizedNotificationPayload(
        title: rawTitle,
        body: rawBody,
        actionRoute: actionRoute,
        wasMasked: false,
      );
    }

    final sanitized = maskSensitiveContent(
      rawTitle: rawTitle,
      rawBody: rawBody,
      module: module,
    );

    return SanitizedNotificationPayload(
      title: sanitized['title']!,
      body: sanitized['body']!,
      actionRoute: actionRoute,
      wasMasked: true,
    );
  }

  /// Pure synchronous transformation for masking sensitive content.
  static Map<String, String> maskSensitiveContent({
    required String rawTitle,
    required String rawBody,
    required String module,
  }) {
    final cleanMod = module.toLowerCase().trim();

    if (cleanMod.contains('finance') || cleanMod.contains('bill') || cleanMod.contains('property')) {
      return {
        'title': 'Financial Reminder',
        'body': 'You have an upcoming financial commitment in Magic Diary.',
      };
    }

    if (cleanMod.contains('health') || cleanMod.contains('medicine') || cleanMod.contains('medical')) {
      return {
        'title': 'Health & Wellness Reminder',
        'body': 'You have a scheduled health activity in Magic Diary.',
      };
    }

    if (cleanMod.contains('school') || cleanMod.contains('education')) {
      return {
        'title': 'Education Reminder',
        'body': 'You have a school or education update in Magic Diary.',
      };
    }

    if (cleanMod.contains('vehicle')) {
      return {
        'title': 'Vehicle Reminder',
        'body': 'You have a vehicle maintenance or renewal update.',
      };
    }

    if (cleanMod.contains('household') || cleanMod.contains('staff') || cleanMod.contains('worker')) {
      return {
        'title': 'Household Reminder',
        'body': 'You have a household task or commitment in Magic Diary.',
      };
    }

    return {
      'title': 'Magic Diary Reminder',
      'body': 'You have a new update in Magic Diary.',
    };
  }
}
