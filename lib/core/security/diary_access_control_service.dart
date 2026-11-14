import '../../features/shared_diaries/models/shared_diary_models.dart';
import '../diary_engine/models/diary_record.dart';

enum DiaryAccessRole {
  owner,
  admin,
  editor,
  contributor,
  viewer,
  custom,
  none,
}

/// Centralized Diary Access Control & Sharing Policy Evaluation Service.
/// Implements backend-aligned least-privilege authorization, sensitive diary classification,
/// entire-diary future record policy checks, and selected-record granular filtering.
class DiaryAccessControlService {
  /// Sensitive diary IDs requiring elevated privacy safeguards.
  static const Set<String> sensitiveDiaryIds = {
    'personal_finance',
    'investment',
    'tax',
    'loan_emi',
    'health',
    'medicine',
    'medical_expenses',
    'legal',
  };

  /// Determines if a diary is high-sensitivity.
  static bool isSensitiveDiary(String diaryId) {
    final cleanId = diaryId.toLowerCase().trim();
    return sensitiveDiaryIds.contains(cleanId);
  }

  /// Evaluates the user's role on a diary.
  static DiaryAccessRole evaluateRole({
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    if (currentUserId.isEmpty) return DiaryAccessRole.none;
    if (currentUserId == diaryOwnerId) return DiaryAccessRole.owner;
    if (shareAccess == null) return DiaryAccessRole.none;
    if (!shareAccess.isActive) return DiaryAccessRole.none;

    switch (shareAccess.permission) {
      case SharedDiaryPermission.admin:
        return DiaryAccessRole.admin;
      case SharedDiaryPermission.editor:
        return DiaryAccessRole.editor;
      case SharedDiaryPermission.contributor:
        return DiaryAccessRole.contributor;
      case SharedDiaryPermission.viewer:
        return DiaryAccessRole.viewer;
    }
  }

  /// Can the user read records in this diary?
  static bool canRead({
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    final role = evaluateRole(
      currentUserId: currentUserId,
      diaryOwnerId: diaryOwnerId,
      shareAccess: shareAccess,
    );
    return role != DiaryAccessRole.none;
  }

  /// Evaluates whether a specific record is accessible under the user's sharing policy.
  static bool canAccessRecord({
    required DiaryRecord record,
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    if (currentUserId == diaryOwnerId) return true;
    if (shareAccess == null || !shareAccess.isActive) return false;

    // Mode 2: Selected Records Sharing
    if (shareAccess.isSelectedMode) {
      return shareAccess.grantedRecordIds.contains(record.id);
    }

    // Mode 1: Entire Diary Sharing with Future Record Policy
    if (shareAccess.futureRecordPolicy == FutureRecordPolicy.existingOnly) {
      final cutoff = shareAccess.snapshotCutoffTime ?? shareAccess.createdAt;
      return record.createdAt.isBefore(cutoff) || record.createdAt.isAtSameMomentAs(cutoff);
    }

    return true;
  }

  /// Can the user add records to this diary?
  static bool canAdd({
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    final role = evaluateRole(
      currentUserId: currentUserId,
      diaryOwnerId: diaryOwnerId,
      shareAccess: shareAccess,
    );
    return role == DiaryAccessRole.owner ||
        role == DiaryAccessRole.admin ||
        role == DiaryAccessRole.editor ||
        role == DiaryAccessRole.contributor;
  }

  /// Can the user edit an existing record?
  static bool canEdit({
    required String currentUserId,
    required String diaryOwnerId,
    required String recordCreatorId,
    SharedDiaryAccess? shareAccess,
  }) {
    final role = evaluateRole(
      currentUserId: currentUserId,
      diaryOwnerId: diaryOwnerId,
      shareAccess: shareAccess,
    );
    if (role == DiaryAccessRole.owner || role == DiaryAccessRole.admin || role == DiaryAccessRole.editor) {
      return true;
    }
    // Contributors can only edit their own newly contributed records
    if (role == DiaryAccessRole.contributor && currentUserId == recordCreatorId) {
      return true;
    }
    return false;
  }

  /// Can the user delete records?
  static bool canDelete({
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    final role = evaluateRole(
      currentUserId: currentUserId,
      diaryOwnerId: diaryOwnerId,
      shareAccess: shareAccess,
    );
    return role == DiaryAccessRole.owner || role == DiaryAccessRole.admin;
  }

  /// Can the user manage sharing access (grant/revoke permissions)?
  static bool canManageAccess({
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    final role = evaluateRole(
      currentUserId: currentUserId,
      diaryOwnerId: diaryOwnerId,
      shareAccess: shareAccess,
    );
    return role == DiaryAccessRole.owner || role == DiaryAccessRole.admin;
  }

  /// Can the user download or access attachments?
  static bool canAccessAttachment({
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    if (currentUserId == diaryOwnerId) return true;
    if (shareAccess == null || !shareAccess.isActive) return false;
    return shareAccess.allowAttachments;
  }

  /// Can the user export or download diary reports?
  static bool canExport({
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    if (currentUserId == diaryOwnerId) return true;
    if (shareAccess == null || !shareAccess.isActive) return false;
    return shareAccess.allowExport;
  }

  /// Filters records according to granular share configuration and future-record policies.
  static List<DiaryRecord> filterRecordsForUser({
    required List<DiaryRecord> allRecords,
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    if (currentUserId == diaryOwnerId) {
      return allRecords;
    }
    if (shareAccess == null || !shareAccess.isActive) {
      return const [];
    }

    return allRecords.where((record) {
      return canAccessRecord(
        record: record,
        currentUserId: currentUserId,
        diaryOwnerId: diaryOwnerId,
        shareAccess: shareAccess,
      );
    }).map((record) {
      return filterRecordFieldsForUser(record: record, shareAccess: shareAccess);
    }).toList();
  }

  /// Redacts sensitive fields if the share specifies restricted fields.
  static DiaryRecord filterRecordFieldsForUser({
    required DiaryRecord record,
    SharedDiaryAccess? shareAccess,
  }) {
    if (shareAccess == null || shareAccess.restrictedFields.isEmpty) {
      return record;
    }

    final restrictedSet = shareAccess.restrictedFields.toSet();
    final sanitizedFields = Map<String, dynamic>.from(record.fields)
      ..removeWhere((key, _) => restrictedSet.contains(key));

    return record.copyWith(
      fields: sanitizedFields,
      attachmentIds: shareAccess.allowAttachments ? record.attachmentIds : const [],
    );
  }
}
