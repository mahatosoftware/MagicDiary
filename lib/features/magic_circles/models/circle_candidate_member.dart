import 'package:flutter/foundation.dart';
import '../models/magic_circle_models.dart';

/// Represents a candidate member selected via any channel (Username, QR, Email, Contacts, Existing Users).
@immutable
class CircleCandidateMember {
  final String? uid;
  final String email;
  final String displayName;
  final String? username;
  final CircleRole role;
  final String status; // 'active' (if resolved user UID exists) or 'invited' (if pending)
  final String channel; // 'username', 'qr', 'email', 'contacts', 'existing_users'
  final String? photoUrl;

  const CircleCandidateMember({
    this.uid,
    required this.email,
    required this.displayName,
    this.username,
    this.role = CircleRole.contributor,
    this.status = 'invited',
    required this.channel,
    this.photoUrl,
  });

  /// True if this candidate is an existing registered user with a valid Firebase UID.
  bool get isRegisteredUser =>
      uid != null && uid!.isNotEmpty && !uid!.startsWith('pending_');

  MagicCircleMember toMagicCircleMember({DateTime? joinedAt}) {
    final now = joinedAt ?? DateTime.now();
    final realUid = isRegisteredUser ? uid! : 'pending_$email';
    return MagicCircleMember(
      uid: realUid,
      email: email.trim().toLowerCase(),
      displayName: displayName.isNotEmpty ? displayName : (username != null ? '@$username' : email),
      role: role,
      joinedAt: now,
      status: isRegisteredUser ? 'active' : 'invited',
    );
  }

  CircleCandidateMember copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? username,
    CircleRole? role,
    String? status,
    String? channel,
    String? photoUrl,
  }) {
    return CircleCandidateMember(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      role: role ?? this.role,
      status: status ?? this.status,
      channel: channel ?? this.channel,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleCandidateMember &&
          runtimeType == other.runtimeType &&
          ((uid != null && uid == other.uid) ||
              email.trim().toLowerCase() == other.email.trim().toLowerCase() ||
              (username != null &&
                  other.username != null &&
                  username!.toUpperCase() == other.username!.toUpperCase()));

  @override
  int get hashCode => (uid ?? email.trim().toLowerCase()).hashCode;
}
