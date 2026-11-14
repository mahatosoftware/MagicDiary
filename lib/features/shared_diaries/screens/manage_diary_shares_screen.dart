import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/diary_engine/screens/generic_diary_list_screen.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/providers/app_providers.dart';
import '../models/shared_diary_models.dart';
import '../repositories/shared_diary_repository.dart';
import '../widgets/sharing_wizard_sheet.dart';
import 'record_selection_screen.dart';

final diarySharesStreamProvider = StreamProvider.family<List<SharedDiaryAccess>, ({String ownerUid, String diaryId})>((ref, arg) {
  final repo = ref.read(sharedDiaryRepositoryProvider);
  return repo.watchDiaryShares(ownerUid: arg.ownerUid, diaryId: arg.diaryId);
});

class ManageDiarySharesScreen extends ConsumerWidget {
  final String diaryId;
  final String? diaryTitle;

  const ManageDiarySharesScreen({super.key, required this.diaryId, this.diaryTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = DiaryRegistry.getDiaryById(diaryId);
    final user = ref.watch(userProfileProvider);
    final color = diary?.color ?? Colors.blue;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final sharesAsync = ref.watch(diarySharesStreamProvider((ownerUid: user.uid, diaryId: diaryId)));
    final recordsAsync = ref.watch(diaryUserRecordsStreamProvider((diaryId: diaryId, userId: user.uid)));
    final allRecords = recordsAsync.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Sharing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(diary?.name ?? diaryId, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Recipient', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          if (diary != null) {
            SharingWizardSheet.show(context, diary);
          }
        },
      ),
      body: sharesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (shares) {
          if (shares.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Shares for ${diary?.name ?? "this diary"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can share this entire diary or select specific records to share with friends, family or Magic Circles.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: color),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share Diary Now'),
                      onPressed: () {
                        if (diary != null) {
                          SharingWizardSheet.show(context, diary);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: shares.length,
            itemBuilder: (context, index) {
              final share = shares[index];
              final accessibleCount = share.countAccessibleRecords(allRecords);

              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipient Header Row
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: share.recipientType == RecipientType.circle
                                ? Colors.purple.shade50
                                : Colors.blue.shade50,
                            child: Icon(
                              share.recipientType == RecipientType.circle
                                  ? Icons.groups_rounded
                                  : Icons.person_rounded,
                              color: share.recipientType == RecipientType.circle
                                  ? Colors.purple
                                  : Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        share.recipientType == RecipientType.circle
                                            ? (share.circleName ?? 'Magic Circle')
                                            : share.sharedWithName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        share.permission.label.split(' ').first.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  share.recipientType == RecipientType.circle
                                      ? 'Circle Collaboration'
                                      : share.sharedWithEmail,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 20),

                      // Sharing Specs Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildSpecItem(
                              icon: share.isSelectedMode ? Icons.checklist_rtl : Icons.menu_book,
                              label: 'Mode',
                              value: share.isSelectedMode ? 'Selected Records' : 'Entire Diary',
                              color: share.isSelectedMode ? Colors.indigo : Colors.teal,
                            ),
                          ),
                          Expanded(
                            child: _buildSpecItem(
                              icon: Icons.inventory_2_outlined,
                              label: 'Accessible Records',
                              value: share.isSelectedMode
                                  ? '${share.grantedRecordIds.length} of ${allRecords.length}'
                                  : 'All ($accessibleCount records)',
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: _buildSpecItem(
                              icon: Icons.update,
                              label: 'Future Policy',
                              value: share.isSelectedMode ? 'New Stay Private' : share.futureRecordPolicy.label.split(' ').first,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Expanded(
                            child: _buildSpecItem(
                              icon: Icons.timer_outlined,
                              label: 'Expires',
                              value: share.expiresAt != null
                                  ? DateFormat('dd MMM yyyy').format(share.expiresAt!)
                                  : 'Never',
                              color: share.isExpired ? Colors.red : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Action Chips Bar
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (share.isSelectedMode)
                            ActionChip(
                              avatar: const Icon(Icons.edit_note, size: 16),
                              label: const Text('Edit Records', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final result = await Navigator.push<List<String>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RecordSelectionScreen(
                                      diaryId: diaryId,
                                      ownerUid: user.uid,
                                      initiallySelectedRecordIds: share.grantedRecordIds.toSet(),
                                      currentShareId: share.id,
                                      recipientName: share.sharedWithName,
                                    ),
                                  ),
                                );
                                if (result != null) {
                                  await ref.read(sharedDiaryRepositoryProvider).updateShareAccess(
                                        share.copyWith(grantedRecordIds: result),
                                      );
                                }
                              },
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.shield_outlined, size: 16),
                            label: const Text('Change Role', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showChangePermissionModal(context, ref, share),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.access_time_rounded, size: 16),
                            label: const Text('Expiry', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showChangeExpiryModal(context, ref, share),
                          ),
                          if (!share.isSelectedMode)
                            ActionChip(
                              avatar: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text('Future Policy', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showChangeFuturePolicyModal(context, ref, share),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: const Text('Revoke', style: TextStyle(fontSize: 12, color: Colors.red)),
                            onPressed: () => _confirmRevoke(context, ref, share),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSpecItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  void _showChangePermissionModal(BuildContext context, WidgetRef ref, SharedDiaryAccess share) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change Permission for ${share.sharedWithName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...SharedDiaryPermission.values.map((p) => ListTile(
                  title: Text(p.label),
                  selected: share.permission == p,
                  trailing: share.permission == p ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(sharedDiaryRepositoryProvider).updatePermission(share.id, p);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showChangeFuturePolicyModal(BuildContext context, WidgetRef ref, SharedDiaryAccess share) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Future Record Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...FutureRecordPolicy.values.map((policy) => ListTile(
                  title: Text(policy.label),
                  subtitle: Text(policy.description, style: const TextStyle(fontSize: 11)),
                  selected: share.futureRecordPolicy == policy,
                  trailing: share.futureRecordPolicy == policy ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(sharedDiaryRepositoryProvider).updateFutureRecordPolicy(
                          shareId: share.id,
                          policy: policy,
                        );
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showChangeExpiryModal(BuildContext context, WidgetRef ref, SharedDiaryAccess share) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: share.expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked != null) {
      await ref.read(sharedDiaryRepositoryProvider).updateExpiry(
            accessId: share.id,
            expiresAt: picked,
          );
    }
  }

  void _confirmRevoke(BuildContext context, WidgetRef ref, SharedDiaryAccess share) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Share?'),
        content: Text('Are you sure you want to revoke access for ${share.sharedWithName}? They will immediately lose access to this diary.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sharedDiaryRepositoryProvider).revokeShareAccess(
                    share.id,
                    ownerUid: share.ownerUid,
                    diaryId: share.diaryId,
                    target: share.sharedWithUid,
                  );
            },
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );
  }
}
