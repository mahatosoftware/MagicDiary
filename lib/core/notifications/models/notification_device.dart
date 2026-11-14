import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationDevice {
  final String id;
  final String userId;
  final String fcmToken;
  final String platform; // 'android', 'ios', 'web', 'macos'
  final String deviceName;
  final String appVersion;
  final DateTime lastActiveAt;
  final DateTime createdAt;

  const NotificationDevice({
    required this.id,
    required this.userId,
    required this.fcmToken,
    required this.platform,
    required this.deviceName,
    this.appVersion = '1.0.0',
    required this.lastActiveAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'fcmToken': fcmToken,
        'platform': platform,
        'deviceName': deviceName,
        'appVersion': appVersion,
        'lastActiveAt': Timestamp.fromDate(lastActiveAt),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory NotificationDevice.fromMap(Map<String, dynamic> map, [String? docId]) {
    final now = DateTime.now();
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? now;
      return now;
    }

    return NotificationDevice(
      id: docId ?? map['id'] as String? ?? 'dev_${now.millisecondsSinceEpoch}',
      userId: map['userId'] as String? ?? '',
      fcmToken: map['fcmToken'] as String? ?? '',
      platform: map['platform'] as String? ?? 'android',
      deviceName: map['deviceName'] as String? ?? 'Unknown Device',
      appVersion: map['appVersion'] as String? ?? '1.0.0',
      lastActiveAt: parseDate(map['lastActiveAt']),
      createdAt: parseDate(map['createdAt']),
    );
  }
}
