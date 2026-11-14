import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:magic_diary/core/diary_engine/models/diary_record.dart';

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

enum SharingMode {
  entire,
  selected,
}

extension SharingModeX on SharingMode {
  String get label {
    switch (this) {
      case SharingMode.entire:
        return 'Share Entire Diary';
      case SharingMode.selected:
        return 'Share Selected Records';
    }
  }

  String get shortLabel {
    switch (this) {
      case SharingMode.entire:
        return 'Entire Diary';
      case SharingMode.selected:
        return 'Selected Records';
    }
  }

  String get description {
    switch (this) {
      case SharingMode.entire:
        return 'All current records and authorized future records will be shared with the recipient.';
      case SharingMode.selected:
        return 'Only explicitly selected records will be shared. All other existing and future records remain private.';
    }
  }
}

enum RecipientType {
  user,
  circle,
}

extension RecipientTypeX on RecipientType {
  String get label {
    switch (this) {
      case RecipientType.user:
        return 'Individual User';
      case RecipientType.circle:
        return 'Magic Circle';
    }
  }
}

enum FutureRecordPolicy {
  allFuture,
  existingOnly,
  askConfirm,
}

extension FutureRecordPolicyX on FutureRecordPolicy {
  String get label {
    switch (this) {
      case FutureRecordPolicy.allFuture:
        return 'Automatically Share Future Records';
      case FutureRecordPolicy.existingOnly:
        return 'Existing Records Only (New Stay Private)';
      case FutureRecordPolicy.askConfirm:
        return 'Ask Confirmation for New Records';
    }
  }

  String get description {
    switch (this) {
      case FutureRecordPolicy.allFuture:
        return 'Any new record created in this diary will automatically become accessible to the recipient.';
      case FutureRecordPolicy.existingOnly:
        return 'Only records created up to now are shared. Any newly created records remain strictly private.';
      case FutureRecordPolicy.askConfirm:
        return 'When creating a new record, you can decide whether to share it with this recipient.';
    }
  }
}

enum ShareStatus {
  active,
  revoked,
  expired,
}

extension ShareStatusX on ShareStatus {
  String get label => name.toUpperCase();
}

/// Core Canonical Model for Diary Sharing & Granular Record Access.
class SharedDiaryAccess {
  final String id;
  final String diaryId;
  final String diaryName;
  final String ownerUid;
  final String ownerName;
  final String? circleId;
  final String? circleName;
  final RecipientType recipientType;
  final SharingMode sharingMode;
  final FutureRecordPolicy futureRecordPolicy;
  final DateTime? snapshotCutoffTime;
  final String sharedWithUid;
  final String sharedWithEmail;
  final String sharedWithName;
  final SharedDiaryPermission permission;
  final bool shareEntireDiary;
  final List<String> grantedRecordIds;
  final bool allowAttachments;
  final bool allowComments;
  final bool allowExport;
  final List<String> restrictedFields;
  final ShareStatus status;
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
    RecipientType? recipientType,
    SharingMode? sharingMode,
    this.futureRecordPolicy = FutureRecordPolicy.allFuture,
    this.snapshotCutoffTime,
    required this.sharedWithUid,
    required this.sharedWithEmail,
    required this.sharedWithName,
    this.permission = SharedDiaryPermission.viewer,
    this.shareEntireDiary = true,
    this.grantedRecordIds = const [],
    this.allowAttachments = true,
    this.allowComments = true,
    this.allowExport = false,
    this.restrictedFields = const [],
    this.status = ShareStatus.active,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 2,
  })  : recipientType = recipientType ?? (circleId != null && circleId.isNotEmpty ? RecipientType.circle : RecipientType.user),
        sharingMode = sharingMode ?? (shareEntireDiary ? SharingMode.entire : SharingMode.selected);

  bool get isTemporary => expiresAt != null;

  FutureRecordPolicy get futurePolicySafe => futureRecordPolicy;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isPending => sharedWithUid.isEmpty || sharedWithUid.startsWith('pending_');

  bool get isActive => status == ShareStatus.active && !isExpired;

  bool get isSelectedMode => sharingMode == SharingMode.selected || !shareEntireDiary;

  /// Evaluates whether a specific record is accessible under this sharing relationship.
  bool hasRecordAccess(String recordId, DateTime recordCreatedAt) {
    if (!isActive) return false;

    if (isSelectedMode) {
      return grantedRecordIds.contains(recordId);
    }

    // Entire diary sharing
    if (futureRecordPolicy == FutureRecordPolicy.existingOnly) {
      final cutoff = snapshotCutoffTime ?? createdAt;
      return recordCreatedAt.isBefore(cutoff) || recordCreatedAt.isAtSameMomentAs(cutoff);
    }

    return true;
  }

  /// Calculates the count of accessible records given all records in the diary.
  int countAccessibleRecords(List<DiaryRecord> records) {
    if (!isActive) return 0;
    if (isSelectedMode) {
      final set = grantedRecordIds.toSet();
      return records.where((r) => set.contains(r.id)).length;
    }
    if (futureRecordPolicy == FutureRecordPolicy.existingOnly) {
      final cutoff = snapshotCutoffTime ?? createdAt;
      return records.where((r) => r.createdAt.isBefore(cutoff) || r.createdAt.isAtSameMomentAs(cutoff)).length;
    }
    return records.length;
  }

  SharedDiaryAccess copyWith({
    String? id,
    String? diaryId,
    String? diaryName,
    String? ownerUid,
    String? ownerName,
    String? circleId,
    String? circleName,
    RecipientType? recipientType,
    SharingMode? sharingMode,
    FutureRecordPolicy? futureRecordPolicy,
    DateTime? snapshotCutoffTime,
    String? sharedWithUid,
    String? sharedWithEmail,
    String? sharedWithName,
    SharedDiaryPermission? permission,
    bool? shareEntireDiary,
    List<String>? grantedRecordIds,
    bool? allowAttachments,
    bool? allowComments,
    bool? allowExport,
    List<String>? restrictedFields,
    ShareStatus? status,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    final effectiveShareEntire = shareEntireDiary ?? (sharingMode != null ? sharingMode == SharingMode.entire : this.shareEntireDiary);
    final effectiveSharingMode = sharingMode ?? (shareEntireDiary != null ? (shareEntireDiary ? SharingMode.entire : SharingMode.selected) : this.sharingMode);

    return SharedDiaryAccess(
      id: id ?? this.id,
      diaryId: diaryId ?? this.diaryId,
      diaryName: diaryName ?? this.diaryName,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      circleId: circleId ?? this.circleId,
      circleName: circleName ?? this.circleName,
      recipientType: recipientType ?? this.recipientType,
      sharingMode: effectiveSharingMode,
      futureRecordPolicy: futureRecordPolicy ?? this.futureRecordPolicy,
      snapshotCutoffTime: snapshotCutoffTime ?? this.snapshotCutoffTime,
      sharedWithUid: sharedWithUid ?? this.sharedWithUid,
      sharedWithEmail: sharedWithEmail ?? this.sharedWithEmail,
      sharedWithName: sharedWithName ?? this.sharedWithName,
      permission: permission ?? this.permission,
      shareEntireDiary: effectiveShareEntire,
      grantedRecordIds: grantedRecordIds ?? this.grantedRecordIds,
      allowAttachments: allowAttachments ?? this.allowAttachments,
      allowComments: allowComments ?? this.allowComments,
      allowExport: allowExport ?? this.allowExport,
      restrictedFields: restrictedFields ?? this.restrictedFields,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'diaryId': diaryId,
        'diaryName': diaryName,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'circleId': circleId,
        'circleName': circleName,
        'recipientType': recipientType.name,
        'sharingMode': sharingMode.name,
        'futureRecordPolicy': futureRecordPolicy.name,
        'snapshotCutoffTime': snapshotCutoffTime != null ? Timestamp.fromDate(snapshotCutoffTime!) : null,
        'sharedWithUid': sharedWithUid,
        'sharedWithEmail': sharedWithEmail,
        'sharedWithName': sharedWithName,
        'permission': permission.name,
        'shareEntireDiary': shareEntireDiary,
        'grantedRecordIds': grantedRecordIds,
        'allowAttachments': allowAttachments,
        'allowComments': allowComments,
        'allowExport': allowExport,
        'restrictedFields': restrictedFields,
        'status': status.name,
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

    final shareEntire = map['shareEntireDiary'] as bool? ?? (map['sharingMode'] == 'selected' ? false : true);

    return SharedDiaryAccess(
      id: id,
      diaryId: map['diaryId'] as String? ?? '',
      diaryName: map['diaryName'] as String? ?? 'Shared Diary',
      ownerUid: map['ownerUid'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? 'Owner',
      circleId: map['circleId'] as String?,
      circleName: map['circleName'] as String?,
      recipientType: RecipientType.values.firstWhere(
        (t) => t.name == map['recipientType'],
        orElse: () => map['circleId'] != null ? RecipientType.circle : RecipientType.user,
      ),
      sharingMode: SharingMode.values.firstWhere(
        (m) => m.name == map['sharingMode'],
        orElse: () => shareEntire ? SharingMode.entire : SharingMode.selected,
      ),
      futureRecordPolicy: FutureRecordPolicy.values.firstWhere(
        (p) => p.name == map['futureRecordPolicy'],
        orElse: () => FutureRecordPolicy.allFuture,
      ),
      snapshotCutoffTime: map['snapshotCutoffTime'] != null ? parseDate(map['snapshotCutoffTime']) : null,
      sharedWithUid: map['sharedWithUid'] as String? ?? '',
      sharedWithEmail: map['sharedWithEmail'] as String? ?? '',
      sharedWithName: map['sharedWithName'] as String? ?? 'Member',
      permission: SharedDiaryPermission.values.firstWhere(
        (p) => p.name == map['permission'],
        orElse: () => SharedDiaryPermission.viewer,
      ),
      shareEntireDiary: shareEntire,
      grantedRecordIds: (map['grantedRecordIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      allowAttachments: map['allowAttachments'] as bool? ?? true,
      allowComments: map['allowComments'] as bool? ?? true,
      allowExport: map['allowExport'] as bool? ?? false,
      restrictedFields: (map['restrictedFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: ShareStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ShareStatus.active,
      ),
      expiresAt: map['expiresAt'] != null ? parseDate(map['expiresAt']) : null,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 2,
    );
  }
}

/// Accurate record sharing calculation summary helper.
class SharedRecordAccessSummary {
  final int totalRecords;
  final int selectedRecords;
  final int alreadySharedRecords;
  final int remainingPrivateRecords;

  const SharedRecordAccessSummary({
    required this.totalRecords,
    required this.selectedRecords,
    required this.alreadySharedRecords,
    required this.remainingPrivateRecords,
  });

  /// Computes summary without double-counting records shared across multiple recipients.
  factory SharedRecordAccessSummary.compute({
    required List<DiaryRecord> allRecords,
    required Set<String> currentlySelectedRecordIds,
    required Set<String> allOtherSharedRecordIds,
  }) {
    final total = allRecords.length;
    final selected = currentlySelectedRecordIds.length;
    // Already shared by other shares, excluding what's selected in this action
    final alreadyShared = allOtherSharedRecordIds.difference(currentlySelectedRecordIds).length;
    // Remaining private: records neither selected nor previously shared
    final sharedUnion = currentlySelectedRecordIds.union(allOtherSharedRecordIds);
    final remainingPrivate = (total - sharedUnion.length).clamp(0, total);

    return SharedRecordAccessSummary(
      totalRecords: total,
      selectedRecords: selected,
      alreadySharedRecords: alreadyShared,
      remainingPrivateRecords: remainingPrivate,
    );
  }
}
