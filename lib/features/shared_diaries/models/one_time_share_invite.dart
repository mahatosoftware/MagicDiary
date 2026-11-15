import 'package:cloud_firestore/cloud_firestore.dart';
import 'shared_diary_models.dart';

class OneTimeShareInvite {
  final String id; // Token / doc ID
  final String diaryId;
  final String diaryName;
  final String ownerUid;
  final String ownerName;
  final SharedDiaryPermission permission;
  final SharingMode sharingMode;
  final List<String> grantedRecordIds;
  final bool allowAttachments;
  final bool allowComments;
  final bool allowExport;
  final List<String> restrictedFields;
  final bool isOneTime;
  final bool isClaimed;
  final String? claimedByUid;
  final String? claimedByEmail;
  final String? claimedByName;
  final DateTime? claimedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const OneTimeShareInvite({
    required this.id,
    required this.diaryId,
    required this.diaryName,
    required this.ownerUid,
    required this.ownerName,
    required this.permission,
    this.sharingMode = SharingMode.entire,
    this.grantedRecordIds = const [],
    this.allowAttachments = true,
    this.allowComments = true,
    this.allowExport = false,
    this.restrictedFields = const [],
    this.isOneTime = true,
    this.isClaimed = false,
    this.claimedByUid,
    this.claimedByEmail,
    this.claimedByName,
    this.claimedAt,
    this.expiresAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get canBeClaimed => !isClaimed && !isExpired;

  String get deepLink => 'magicdiary://share/invite/$id';
  String get webLink => 'https://magicdiary.app/share/invite/$id';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diaryId': diaryId,
      'diaryName': diaryName,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'permission': permission.name,
      'sharingMode': sharingMode.name,
      'grantedRecordIds': grantedRecordIds,
      'allowAttachments': allowAttachments,
      'allowComments': allowComments,
      'allowExport': allowExport,
      'restrictedFields': restrictedFields,
      'isOneTime': isOneTime,
      'isClaimed': isClaimed,
      'claimedByUid': claimedByUid,
      'claimedByEmail': claimedByEmail,
      'claimedByName': claimedByName,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory OneTimeShareInvite.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    SharedDiaryPermission parsePermission(dynamic p) {
      if (p == null) return SharedDiaryPermission.viewer;
      final str = p.toString();
      for (final val in SharedDiaryPermission.values) {
        if (val.name == str) return val;
      }
      return SharedDiaryPermission.viewer;
    }

    SharingMode parseMode(dynamic m) {
      if (m == null) return SharingMode.entire;
      final str = m.toString();
      for (final val in SharingMode.values) {
        if (val.name == str) return val;
      }
      return SharingMode.entire;
    }

    return OneTimeShareInvite(
      id: id,
      diaryId: map['diaryId'] as String? ?? '',
      diaryName: map['diaryName'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      permission: parsePermission(map['permission']),
      sharingMode: parseMode(map['sharingMode']),
      grantedRecordIds: (map['grantedRecordIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      allowAttachments: map['allowAttachments'] as bool? ?? true,
      allowComments: map['allowComments'] as bool? ?? true,
      allowExport: map['allowExport'] as bool? ?? false,
      restrictedFields: (map['restrictedFields'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isOneTime: map['isOneTime'] as bool? ?? true,
      isClaimed: map['isClaimed'] as bool? ?? false,
      claimedByUid: map['claimedByUid'] as String?,
      claimedByEmail: map['claimedByEmail'] as String?,
      claimedByName: map['claimedByName'] as String?,
      claimedAt: map['claimedAt'] != null ? parseDate(map['claimedAt']) : null,
      expiresAt: map['expiresAt'] != null ? parseDate(map['expiresAt']) : null,
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  OneTimeShareInvite copyWith({
    String? id,
    String? diaryId,
    String? diaryName,
    String? ownerUid,
    String? ownerName,
    SharedDiaryPermission? permission,
    SharingMode? sharingMode,
    List<String>? grantedRecordIds,
    bool? allowAttachments,
    bool? allowComments,
    bool? allowExport,
    List<String>? restrictedFields,
    bool? isOneTime,
    bool? isClaimed,
    String? claimedByUid,
    String? claimedByEmail,
    String? claimedByName,
    DateTime? claimedAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OneTimeShareInvite(
      id: id ?? this.id,
      diaryId: diaryId ?? this.diaryId,
      diaryName: diaryName ?? this.diaryName,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      permission: permission ?? this.permission,
      sharingMode: sharingMode ?? this.sharingMode,
      grantedRecordIds: grantedRecordIds ?? this.grantedRecordIds,
      allowAttachments: allowAttachments ?? this.allowAttachments,
      allowComments: allowComments ?? this.allowComments,
      allowExport: allowExport ?? this.allowExport,
      restrictedFields: restrictedFields ?? this.restrictedFields,
      isOneTime: isOneTime ?? this.isOneTime,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedByUid: claimedByUid ?? this.claimedByUid,
      claimedByEmail: claimedByEmail ?? this.claimedByEmail,
      claimedByName: claimedByName ?? this.claimedByName,
      claimedAt: claimedAt ?? this.claimedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
