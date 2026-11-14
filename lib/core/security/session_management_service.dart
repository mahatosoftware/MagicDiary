import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'secure_storage_service.dart';

class UserDeviceSession {
  final String id;
  final String userId;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String? ipAddress;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isRevoked;
  final bool isCurrent;

  UserDeviceSession({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.ipAddress,
    required this.createdAt,
    required this.lastActiveAt,
    this.isRevoked = false,
    this.isCurrent = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'ipAddress': ipAddress,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastActiveAt': Timestamp.fromDate(lastActiveAt),
        'isRevoked': isRevoked,
      };

  factory UserDeviceSession.fromMap(Map<String, dynamic> map, String id, {bool isCurrent = false}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final d = DateTime.tryParse(val.toString());
        if (d != null) return d;
      }
      return DateTime.now();
    }

    return UserDeviceSession(
      id: id,
      userId: map['userId'] as String? ?? '',
      deviceId: map['deviceId'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? 'Device',
      platform: map['platform'] as String? ?? 'unknown',
      ipAddress: map['ipAddress'] as String?,
      createdAt: parseDate(map['createdAt']),
      lastActiveAt: parseDate(map['lastActiveAt']),
      isRevoked: map['isRevoked'] as bool? ?? false,
      isCurrent: isCurrent,
    );
  }
}

/// Centralized Session Management Service.
/// Manages device registries, remote revocation, and inactivity timeouts.
class SessionManagementService {
  final FirebaseFirestore _firestore;
  final SecureStorageService _secureStorage;
  final Uuid _uuid = const Uuid();

  SessionManagementService({
    FirebaseFirestore? firestore,
    SecureStorageService? secureStorage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _secureStorage = secureStorage ?? SecureStorageService();

  /// Gets or creates a local session ID.
  Future<String> getOrCreateSessionId() async {
    var sid = await _secureStorage.read(SecureStorageService.keyActiveSessionId);
    if (sid == null || sid.isEmpty) {
      sid = _uuid.v4();
      await _secureStorage.write(SecureStorageService.keyActiveSessionId, sid);
    }
    return sid;
  }

  /// Registers or updates the active device session in Firestore.
  Future<UserDeviceSession> registerOrUpdateSession(String userId, {String? customDeviceName}) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');
    final sessionId = await getOrCreateSessionId();
    final now = DateTime.now();

    String detectedPlatform = 'web';
    if (!kIsWeb) {
      if (Platform.isAndroid) detectedPlatform = 'android';
      if (Platform.isIOS) detectedPlatform = 'ios';
      if (Platform.isMacOS) detectedPlatform = 'macos';
      if (Platform.isWindows) detectedPlatform = 'windows';
      if (Platform.isLinux) detectedPlatform = 'linux';
    }

    final docRef = _firestore.collection('users').doc(userId).collection('sessions').doc(sessionId);
    final docSnap = await docRef.get();

    DateTime createdAt = now;
    String deviceName = customDeviceName ?? '$detectedPlatform client';

    if (docSnap.exists && docSnap.data() != null) {
      final existing = docSnap.data()!;
      if (existing['createdAt'] is Timestamp) {
        createdAt = (existing['createdAt'] as Timestamp).toDate();
      }
      deviceName = existing['deviceName'] as String? ?? deviceName;
    }

    final session = UserDeviceSession(
      id: sessionId,
      userId: userId,
      deviceId: sessionId,
      deviceName: deviceName,
      platform: detectedPlatform,
      createdAt: createdAt,
      lastActiveAt: now,
      isRevoked: false,
      isCurrent: true,
    );

    await docRef.set(session.toMap(), SetOptions(merge: true));
    await _secureStorage.write(SecureStorageService.keyLastActiveTimestamp, now.millisecondsSinceEpoch.toString());

    return session;
  }

  /// Fetches all sessions for a user.
  Future<List<UserDeviceSession>> getSessions(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final currentSid = await getOrCreateSessionId();
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .orderBy('lastActiveAt', descending: true)
          .get();

      return snap.docs
          .map((doc) => UserDeviceSession.fromMap(
                doc.data(),
                doc.id,
                isCurrent: doc.id == currentSid,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Stream of user sessions.
  Stream<List<UserDeviceSession>> watchSessions(String userId) async* {
    if (userId.isEmpty) {
      yield const [];
      return;
    }
    final currentSid = await getOrCreateSessionId();
    yield* _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .orderBy('lastActiveAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserDeviceSession.fromMap(
                  doc.data(),
                  doc.id,
                  isCurrent: doc.id == currentSid,
                ))
            .toList());
  }

  /// Revokes an individual session.
  Future<void> revokeSession(String userId, String sessionId) async {
    if (userId.isEmpty || sessionId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .doc(sessionId)
        .update({
      'isRevoked': true,
      'revokedAt': Timestamp.now(),
    });
  }

  /// Revokes all other sessions except the current device.
  Future<int> revokeAllOtherSessions(String userId) async {
    if (userId.isEmpty) return 0;
    final currentSid = await getOrCreateSessionId();
    final sessions = await getSessions(userId);
    int revoked = 0;

    for (final s in sessions) {
      if (s.id != currentSid && !s.isRevoked) {
        await revokeSession(userId, s.id);
        revoked++;
      }
    }
    return revoked;
  }

  /// Checks if the device has exceeded the inactivity lock timeout.
  Future<bool> isSessionTimedOut() async {
    final timeoutMins = await _secureStorage.getLockTimeoutMinutes();
    if (timeoutMins <= 0) return false; // 0 = never

    final lastActiveStr = await _secureStorage.read(SecureStorageService.keyLastActiveTimestamp);
    if (lastActiveStr == null) return false;

    final lastActiveMs = int.tryParse(lastActiveStr);
    if (lastActiveMs == null) return false;

    final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMs);
    final elapsed = DateTime.now().difference(lastActive);
    return elapsed.inMinutes >= timeoutMins;
  }

  /// Updates current active timestamp to prevent auto-lock during active use.
  Future<void> recordUserActivity() async {
    await _secureStorage.write(
      SecureStorageService.keyLastActiveTimestamp,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
}
