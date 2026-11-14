import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class SecurityAuditLog {
  final String id;
  final String userId;
  final String action;
  final String status; // 'success', 'denied', 'failed'
  final DateTime timestamp;
  final String? ipAddress;
  final String? devicePlatform;
  final String? metadata;

  SecurityAuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.status,
    required this.timestamp,
    this.ipAddress,
    this.devicePlatform,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'action': action,
        'status': status,
        'timestamp': Timestamp.fromDate(timestamp),
        'ipAddress': ipAddress,
        'devicePlatform': devicePlatform,
        'metadata': metadata,
      };

  factory SecurityAuditLog.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final d = DateTime.tryParse(val.toString());
        if (d != null) return d;
      }
      return DateTime.now();
    }

    return SecurityAuditLog(
      id: id,
      userId: map['userId'] as String? ?? '',
      action: map['action'] as String? ?? 'general_event',
      status: map['status'] as String? ?? 'success',
      timestamp: parseDate(map['timestamp']),
      ipAddress: map['ipAddress'] as String?,
      devicePlatform: map['devicePlatform'] as String?,
      metadata: map['metadata'] as String?,
    );
  }
}

/// Centralized Security Audit Service.
/// Records append-only security logs for compliance and intrusion detection.
class SecurityAuditService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  SecurityAuditService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Records an immutable audit log entry.
  Future<void> logSecurityEvent({
    required String userId,
    required String action,
    required String status,
    String? metadata,
    String? devicePlatform,
  }) async {
    if (userId.isEmpty) return;
    try {
      final logId = _uuid.v4();
      final log = SecurityAuditLog(
        id: logId,
        userId: userId,
        action: action,
        status: status,
        timestamp: DateTime.now(),
        metadata: metadata,
        devicePlatform: devicePlatform,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_logs')
          .doc(logId)
          .set(log.toMap());
    } catch (_) {
      // Fire-and-forget; never disrupt UI on audit failure
    }
  }

  /// Fetches recent audit logs for the security activity viewer.
  Future<List<SecurityAuditLog>> getRecentLogs(String userId, {int limit = 50}) async {
    if (userId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((d) => SecurityAuditLog.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Stream of recent security logs.
  Stream<List<SecurityAuditLog>> watchRecentLogs(String userId, {int limit = 30}) {
    if (userId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('security_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SecurityAuditLog.fromMap(d.data(), d.id)).toList());
  }
}
