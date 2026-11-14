import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../models/notification_preference.dart';
import '../models/notification_schedule.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_manager.dart';
import '../services/notification_preference_manager.dart';
import '../services/notification_template_manager.dart';

final notificationManagerProvider = Provider<NotificationManager>((ref) {
  return NotificationManager();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return ref.watch(notificationManagerProvider).repository;
});

final notificationTemplateManagerProvider = Provider<NotificationTemplateManager>((ref) {
  return ref.watch(notificationManagerProvider).templateManager;
});

final notificationPreferenceManagerProvider = Provider<NotificationPreferenceManager>((ref) {
  return ref.watch(notificationManagerProvider).preferenceManager;
});

/// Fetches all active notification schedules for the current authenticated user.
final activeSchedulesProvider = FutureProvider<List<NotificationSchedule>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null || user.uid.isEmpty) return const [];
  final manager = ref.watch(notificationManagerProvider);
  return await manager.getActiveSchedules(user.uid);
});

/// Categorizes active schedules for the Notification Centre (Today, Upcoming, Overdue, Snoozed, Deferred, Completed).
final categorizedNotificationsProvider =
    FutureProvider<Map<String, List<NotificationSchedule>>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null || user.uid.isEmpty) {
    return {
      'today': [],
      'upcoming': [],
      'overdue': [],
      'snoozed': [],
      'deferred': [],
      'completed': [],
    };
  }
  final manager = ref.watch(notificationManagerProvider);
  return await manager.getCategorizedSchedules(user.uid);
});

/// Unread / Actionable badge count (Today + Overdue).
final notificationBadgeCountProvider = Provider<int>((ref) {
  final asyncData = ref.watch(categorizedNotificationsProvider);
  return asyncData.maybeWhen(
    data: (map) {
      final todayCount = map['today']?.length ?? 0;
      final overdueCount = map['overdue']?.length ?? 0;
      return todayCount + overdueCount;
    },
    orElse: () => 0,
  );
});

/// Global notification preferences for current user.
final globalPreferenceProvider = FutureProvider<NotificationPreference>((ref) async {
  final user = ref.watch(userProfileProvider);
  final uid = user?.uid ?? '';
  final manager = ref.watch(notificationManagerProvider);
  final pref = await manager.repository.getGlobalPreference(uid);
  return pref ?? NotificationPreference.defaultGlobal(uid);
});
