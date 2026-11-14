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

/// Centralized Diary Access Control Service.
/// Implements least-privilege authorization, sensitive diary classification, and record-level filtering.
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
    if (shareAccess.isExpired) return DiaryAccessRole.none;

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

  /// Filters records according to granular share configuration.
  /// If `shareEntireDiary` is false, only explicitly granted record IDs are returned.
  static List<DiaryRecord> filterRecordsForUser({
    required List<DiaryRecord> allRecords,
    required String currentUserId,
    required String diaryOwnerId,
    SharedDiaryAccess? shareAccess,
  }) {
    if (currentUserId == diaryOwnerId) {
      return allRecords;
    }
    if (shareAccess == null || shareAccess.isExpired) {
      return const [];
    }
    if (shareAccess.shareEntireDiary) {
      return allRecords;
    }
    // Granular record-level sharing
    final grantedSet = shareAccess.grantedRecordIds.toSet();
    return allRecords.where((r) => grantedSet.contains(r.id)).toList();
  }
}
