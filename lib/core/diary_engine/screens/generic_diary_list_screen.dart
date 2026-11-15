import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../diary_registry/diary_registry.dart';
import '../../diary_registry/diary_definition.dart';
import '../models/diary_record.dart';
import '../repositories/diary_record_repository.dart';
import '../../providers/app_providers.dart';
import '../../security/diary_access_control_service.dart';
import '../../../features/shared_diaries/models/shared_diary_models.dart';
import '../../../features/shared_diaries/widgets/sharing_wizard_sheet.dart';

final diaryRecordRepositoryProvider =
    Provider<DiaryRecordRepository>((ref) => DiaryRecordRepository());

typedef DiaryRecordQuery = ({String diaryId, String userId});
typedef SharedRecordSelectionQuery = ({
  String diaryId,
  String ownerId,
  List<String> recordIds,
});

final diaryUserRecordsStreamProvider =
    StreamProvider.family<List<DiaryRecord>, DiaryRecordQuery>((ref, query) {
  if (query.userId.isEmpty) return const Stream.empty();
  final repo = ref.read(diaryRecordRepositoryProvider);
  return repo.watchRecords(userId: query.userId, diaryId: query.diaryId);
});

final diaryRecordsStreamProvider =
    StreamProvider.family<List<DiaryRecord>, String>((ref, diaryId) {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.read(diaryRecordRepositoryProvider);
  return repo.watchRecords(userId: user.uid, diaryId: diaryId);
});

final selectedSharedRecordsProvider =
    FutureProvider.family<List<DiaryRecord>, SharedRecordSelectionQuery>(
        (ref, query) {
  return ref.read(diaryRecordRepositoryProvider).getRecordsByIds(
        userId: query.ownerId,
        diaryId: query.diaryId,
        recordIds: query.recordIds,
      );
});

class GenericDiaryListScreen extends ConsumerWidget {
  final String diaryId;
  final String? ownerId;
  final String? ownerName;
  final SharedDiaryAccess? shareAccess;

  const GenericDiaryListScreen({
    super.key,
    required this.diaryId,
    this.ownerId,
    this.ownerName,
    this.shareAccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = DiaryRegistry.getDiaryById(diaryId);
    final currentUser = ref.watch(userProfileProvider);
    final effectiveUserId = (ownerId != null && ownerId!.isNotEmpty)
        ? ownerId!
        : (currentUser?.uid ?? '');
    final isShared =
        ownerId != null && ownerId!.isNotEmpty && ownerId != currentUser?.uid;

    final isSelectedRecordShare =
        isShared && (shareAccess?.isSelectedMode ?? false);
    final recordsAsync = isSelectedRecordShare
        ? ref.watch(
            selectedSharedRecordsProvider((
              diaryId: diaryId,
              ownerId: effectiveUserId,
              recordIds: shareAccess!.grantedRecordIds,
            )),
          )
        : ref.watch(
            diaryUserRecordsStreamProvider(
              (diaryId: diaryId, userId: effectiveUserId),
            ),
          );

    final title = isShared && ownerName != null && ownerName!.isNotEmpty
        ? '${diary?.name ?? "Diary"} ($ownerName)'
        : (diary?.name ?? 'Diary Records');
    final color = diary?.color ?? Colors.blue;
    final icon = diary?.icon ?? Icons.auto_stories_rounded;

    final canAdd = !isShared || (shareAccess?.permission.canAdd ?? true);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(isShared ? '/shared-diaries' : '/diaries');
            }
          },
        ),
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'View in Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          if (!isShared && diary != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Diary Sharing',
              onSelected: (value) {
                if (value == 'share') {
                  SharingWizardSheet.show(context, diary);
                } else if (value == 'manage') {
                  context.push(
                      '/manage-shares/$diaryId?title=${Uri.encodeComponent(diary.name)}');
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          size: 20, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('Share Diary'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'manage',
                  child: Row(
                    children: [
                      Icon(Icons.settings_suggest_rounded,
                          size: 20, color: Colors.indigo),
                      SizedBox(width: 12),
                      Text('Manage Existing Shares'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () {
                final queryParams = isShared
                    ? '?ownerId=$effectiveUserId&ownerName=${Uri.encodeComponent(ownerName ?? "")}'
                    : '';
                context.push('/diary-records/$diaryId/add$queryParams',
                    extra: shareAccess);
              },
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Entry',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          if (isShared)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const Icon(Icons.share_rounded, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shared by ${ownerName ?? "Owner"} • ${shareAccess?.sharingMode.shortLabel ?? "Shared"} • ${shareAccess?.permission.label ?? "Shared Access"}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                  ),
                  if (shareAccess?.isTemporary == true &&
                      shareAccess?.expiresAt != null)
                    Text(
                      'Expires ${DateFormat('d MMM').format(shareAccess!.expiresAt!)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          // Diary Header Card
          Container(
            padding: const EdgeInsets.all(16.0),
            color: color.withValues(alpha: 0.08),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        diary?.description ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      if (diary != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: diary.defaultSharingClassification.badgeColor
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(diary.defaultSharingClassification.icon,
                                  size: 14,
                                  color: diary
                                      .defaultSharingClassification.badgeColor),
                              const SizedBox(width: 4),
                              Text(
                                diary.defaultSharingClassification.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: diary
                                      .defaultSharingClassification.badgeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Records List
          Expanded(
            child: recordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Error loading records: $err')),
              data: (records) {
                final visibleRecords = isShared && shareAccess != null
                    ? DiaryAccessControlService.filterRecordsForUser(
                        allRecords: records,
                        currentUserId: currentUser?.uid ?? '',
                        diaryOwnerId: effectiveUserId,
                        shareAccess: shareAccess,
                      )
                    : records;

                if (visibleRecords.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            isShared
                                ? 'No Accessible Shared Records'
                                : 'No records yet in $title',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isShared
                                ? 'The owner has not granted access to records in this diary, or your share has expired.'
                                : 'Tap "Add Entry" below to create your first record.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: visibleRecords.length,
                  itemBuilder: (context, index) {
                    final record = visibleRecords[index];
                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final queryParams = isShared
                              ? '?ownerId=$effectiveUserId&ownerName=${Uri.encodeComponent(ownerName ?? "")}'
                              : '';
                          context.push(
                              '/diary-records/$diaryId/${record.id}$queryParams',
                              extra: record);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      record.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (record.amount != null)
                                    Text(
                                      '₹${record.amount!.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: color,
                                      ),
                                    ),
                                ],
                              ),
                              if (record.subtitle != null &&
                                  record.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  record.subtitle!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('d MMM yyyy')
                                        .format(record.recordDate),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                  const Spacer(),
                                  if (record.isPrivate)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lock_rounded,
                                              size: 11,
                                              color: Colors.purple.shade700),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Private',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.purple.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
