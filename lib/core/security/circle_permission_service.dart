import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../features/magic_circles/models/magic_circle_models.dart';

class CircleInvitation {
  final String id;
  final String circleId;
  final String circleName;
  final String inviterUid;
  final String inviterName;
  final String inviteeEmail;
  final String role; // 'admin', 'editor', 'contributor', 'viewer'
  final String status; // 'pending', 'accepted', 'revoked', 'expired'
  final DateTime createdAt;
  final DateTime expiresAt;

  CircleInvitation({
    required this.id,
    required this.circleId,
    required this.circleName,
    required this.inviterUid,
    required this.inviterName,
    required this.inviteeEmail,
    required this.role,
    this.status = 'pending',
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValidPending => status == 'pending' && !isExpired;

  Map<String, dynamic> toMap() => {
        'id': id,
        'circleId': circleId,
        'circleName': circleName,
        'inviterUid': inviterUid,
        'inviterName': inviterName,
        'inviteeEmail': inviteeEmail.trim().toLowerCase(),
        'role': role,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
      };

  factory CircleInvitation.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final d = DateTime.tryParse(val.toString());
        if (d != null) return d;
      }
      return DateTime.now();
    }

    return CircleInvitation(
      id: id,
      circleId: map['circleId'] as String? ?? '',
      circleName: map['circleName'] as String? ?? '',
      inviterUid: map['inviterUid'] as String? ?? '',
      inviterName: map['inviterName'] as String? ?? '',
      inviteeEmail: map['inviteeEmail'] as String? ?? '',
      role: map['role'] as String? ?? 'viewer',
      status: map['status'] as String? ?? 'pending',
      createdAt: parseDate(map['createdAt']),
      expiresAt: parseDate(map['expiresAt']),
    );
  }
}

/// Centralized Circle Authorization and Invitation Security Service.
/// Prevents privilege escalation and verifies invitation lifecycle.
class CirclePermissionService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  CirclePermissionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Creates a secure, time-limited, revocable invitation.
  Future<CircleInvitation> createInvitation({
    required String circleId,
    required String circleName,
    required String inviterUid,
    required String inviterName,
    required String inviteeEmail,
    required String role,
    Duration validDuration = const Duration(days: 7),
  }) async {
    final invId = _uuid.v4();
    final now = DateTime.now();
    final invitation = CircleInvitation(
      id: invId,
      circleId: circleId,
      circleName: circleName,
      inviterUid: inviterUid,
      inviterName: inviterName,
      inviteeEmail: inviteeEmail.trim().toLowerCase(),
      role: role,
      status: 'pending',
      createdAt: now,
      expiresAt: now.add(validDuration),
    );

    await _firestore
        .collection('circle_invitations')
        .doc(invId)
        .set(invitation.toMap());

    return invitation;
  }

  /// Revokes an invitation before it is accepted.
  Future<void> revokeInvitation(String invitationId, String actorUid) async {
    final ref = _firestore.collection('circle_invitations').doc(invitationId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    if (data['inviterUid'] != actorUid) {
      throw Exception('Permission denied: Only the inviter or circle owner can revoke invitations.');
    }

    await ref.update({
      'status': 'revoked',
      'revokedAt': Timestamp.now(),
      'revokedByUid': actorUid,
    });
  }

  /// Verifies whether an actor has permission to change a target user's role.
  /// Prevents privilege escalation:
  /// - Only Owner can appoint Admins.
  /// - Only Owner or Admin can assign Editor/Contributor/Viewer.
  /// - Nobody can elevate their own privileges.
  static bool canModifyMemberRole({
    required String actorUid,
    required String targetMemberUid,
    required String circleOwnerId,
    required List<MagicCircleMember> members,
    required CircleRole newRole,
  }) {
    // 1. Self-elevation protection: Cannot change one's own role
    if (actorUid == targetMemberUid) {
      return false;
    }

    // 2. Circle Owner has full administrative authority
    if (actorUid == circleOwnerId) {
      return true;
    }

    // 3. Find actor's role
    final actorMember = members.where((m) => m.uid == actorUid).firstOrNull;
    if (actorMember == null) return false;

    // Only Admins can manage non-Admin roles
    if (actorMember.role == CircleRole.admin) {
      // Admin CANNOT promote anyone to Admin or Owner
      if (newRole == CircleRole.admin || newRole == CircleRole.owner) {
        return false;
      }
      // Admin CANNOT modify an existing Admin or the Owner
      final target = members.where((m) => m.uid == targetMemberUid).firstOrNull;
      if (target != null && (target.role == CircleRole.admin || target.role == CircleRole.owner)) {
        return false;
      }
      return true;
    }

    return false;
  }

  /// Verifies whether a circle member can access a given diary.
  /// Circle membership does NOT grant unrestricted access to members' personal diaries.
  /// Access is only granted if the diary ID is explicitly listed in `circle.sharedDiaryIds`.
  static bool isDiarySharedWithCircle(MagicCircle circle, String diaryId) {
    return circle.sharedDiaryIds.contains(diaryId);
  }
}
