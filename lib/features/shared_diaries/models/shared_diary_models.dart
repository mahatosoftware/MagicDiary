import 'package:cloud_firestore/cloud_firestore.dart';

enum SharedDiaryPermission {
  viewer,
  contributor,
  editor,
  admin,
}

extension SharedDiaryPermissionX on SharedDiaryPermission {
  String get label {
    switch (this) {
      case SharedDiaryPermission.viewer:
        return 'Viewer (Read-only)';
      case SharedDiaryPermission.contributor:
        return 'Contributor (Add Records)';
      case SharedDiaryPermission.editor:
        return 'Editor (Add & Edit)';
      case SharedDiaryPermission.admin:
        return 'Admin (Full Access)';
    }
  }

  bool get canEdit => this == SharedDiaryPermission.editor || this == SharedDiaryPermission.admin;
  bool get canAdd => this != SharedDiaryPermission.viewer;
  bool get canManageAccess => this == SharedDiaryPermission.admin;
}

class SharedDiaryAccess {
  final String id;
  final String diaryId;
  final String diaryName;
  final String ownerUid;
  final String ownerName;
  final String? circleId;
  final String? circleName;
  final String sharedWithUid;
  final String sharedWithEmail;
  final String sharedWithName;
  final SharedDiaryPermission permission;
  final bool shareEntireDiary;
  final List<String> grantedRecordIds;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  SharedDiaryAccess({
    required this.id,
    required this.diaryId,
    required this.diaryName,
    required this.ownerUid,
    required this.ownerName,
    this.circleId,
    this.circleName,
    required this.sharedWithUid,
    required this.sharedWithEmail,
    required this.sharedWithName,
    this.permission = SharedDiaryPermission.viewer,
    this.shareEntireDiary = true,
    this.grantedRecordIds = const [],
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toMap() => {
        'id': id,
        'diaryId': diaryId,
        'diaryName': diaryName,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'circleId': circleId,
        'circleName': circleName,
        'sharedWithUid': sharedWithUid,
        'sharedWithEmail': sharedWithEmail,
        'sharedWithName': sharedWithName,
        'permission': permission.name,
        'shareEntireDiary': shareEntireDiary,
        'grantedRecordIds': grantedRecordIds,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'schemaVersion': schemaVersion,
      };

  factory SharedDiaryAccess.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return SharedDiaryAccess(
      id: id,
      diaryId: map['diaryId'] as String? ?? '',
      diaryName: map['diaryName'] as String? ?? 'Shared Diary',
      ownerUid: map['ownerUid'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? 'Owner',
      circleId: map['circleId'] as String?,
      circleName: map['circleName'] as String?,
      sharedWithUid: map['sharedWithUid'] as String? ?? '',
      sharedWithEmail: map['sharedWithEmail'] as String? ?? '',
      sharedWithName: map['sharedWithName'] as String? ?? 'Member',
      permission: SharedDiaryPermission.values.firstWhere(
        (p) => p.name == map['permission'],
        orElse: () => SharedDiaryPermission.viewer,
      ),
      shareEntireDiary: map['shareEntireDiary'] as bool? ?? true,
      grantedRecordIds: (map['grantedRecordIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      expiresAt: map['expiresAt'] != null ? parseDate(map['expiresAt']) : null,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
