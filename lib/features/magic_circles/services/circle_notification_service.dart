import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/models/notification_enums.dart';
import '../../../core/notifications/models/notification_history_entry.dart';
import '../../../core/notifications/services/local_notification_service.dart';
import '../../../core/notifications/services/notification_channel_manager.dart';
import '../../../core/notifications/services/notification_manager.dart';
import '../../../core/providers/app_providers.dart';
import '../models/magic_circle_models.dart';
import '../repositories/magic_circle_repository.dart';

final magicCircleRepositoryProvider = Provider<MagicCircleRepository>((ref) => MagicCircleRepository());

/// Provider returning the total count of pending member join requests
/// across all circles where the current user is an owner or administrator.
final pendingCircleJoinRequestsCountProvider = Provider<int>((ref) {
  final user = ref.watch(userProfileProvider);
  if (user == null) return 0;

  final circlesAsync = ref.watch(userCirclesStreamProvider);
  return circlesAsync.maybeWhen(
    data: (circles) {
      int count = 0;
      for (final c in circles) {
        final isAdmin = c.ownerId == user.uid ||
            c.adminIds.contains(user.uid) ||
            c.members.any((m) => m.uid == user.uid && (m.role == CircleRole.owner || m.role == CircleRole.admin));
        if (isAdmin) {
          count += c.pendingMemberIds.length;
        }
      }
      return count;
    },
    orElse: () => 0,
  );
});

/// Circle stream provider for reactive real-time UI updates
final userCirclesStreamProvider = StreamProvider<List<MagicCircle>>((ref) {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.read(magicCircleRepositoryProvider);
  return repo.watchUserCircles(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
  );
});

/// Service that monitors circle join requests in real time and triggers
/// system notifications and inbox entries for the circle owner/admins.
class CircleNotificationService {
  static final CircleNotificationService _instance = CircleNotificationService._internal();
  factory CircleNotificationService() => _instance;
  CircleNotificationService._internal();

  final Set<String> _notifiedRequestKeys = {};

  /// Checks for new pending join requests and triggers notifications.
  Future<void> handleCircleUpdates({
    required String currentUserId,
    required List<MagicCircle> circles,
  }) async {
    if (currentUserId.isEmpty) return;

    for (final circle in circles) {
      final isAdmin = circle.ownerId == currentUserId ||
          circle.adminIds.contains(currentUserId) ||
          circle.members.any((m) => m.uid == currentUserId && (m.role == CircleRole.owner || m.role == CircleRole.admin));

      if (!isAdmin || circle.pendingMemberIds.isEmpty) continue;

      for (final applicantUid in circle.pendingMemberIds) {
        final key = '${circle.id}_$applicantUid';
        if (_notifiedRequestKeys.contains(key)) continue;

        _notifiedRequestKeys.add(key);
        await _notifyAdminOfJoinRequest(
          adminUid: currentUserId,
          circle: circle,
          applicantUid: applicantUid,
        );
      }
    }
  }

  Future<void> _notifyAdminOfJoinRequest({
    required String adminUid,
    required MagicCircle circle,
    required String applicantUid,
  }) async {
    String applicantName = 'A user';

    // 1. Resolve applicant display name
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(applicantUid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final name = userDoc.data()!['displayName'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          applicantName = name.trim();
        }
      }
    } catch (e) {
      debugPrint('Note resolving applicant name: $e');
    }

    // 2. Trigger System Local Notification (Banner / Heads-up)
    try {
      final notificationId = LocalNotificationService.generateStableId('join_${circle.id}_$applicantUid');
      await LocalNotificationService().showInstantNotification(
        id: notificationId,
        title: '🔔 Circle Join Request: ${circle.name}',
        body: '$applicantName requested to join "${circle.name}". Tap to review and approve.',
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationChannelManager.channelCircleAlerts,
            'Circle Collaborations & Approvals',
            channelDescription: 'Alerts for member join requests, circle approvals, and shared activities',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: '/circles/${circle.id}',
      );
    } catch (e) {
      debugPrint('Local notification trigger note: $e');
    }

    // 3. Save entry in Notification History / Notification Centre
    try {
      await NotificationManager().repository.addHistoryEntry(
        adminUid,
        NotificationHistoryEntry(
          id: 'circle_req_${circle.id}_$applicantUid',
          notificationId: 'circle_join_request',
          recordId: circle.id,
          moduleId: 'magic_circles',
          eventType: 'join_request',
          title: '🔔 Join Request: ${circle.name}',
          body: '$applicantName requested to join "${circle.name}". Tap to review and approve.',
          status: NotificationScheduleStatus.completed,
          scheduledAt: DateTime.now(),
          deliveredAt: DateTime.now(),
          displayedAt: DateTime.now(),
          metadata: {
            'circleId': circle.id,
            'circleName': circle.name,
            'applicantUid': applicantUid,
            'route': '/circles/${circle.id}',
          },
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Add notification history entry note: $e');
    }
  }
}
