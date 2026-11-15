import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/shared_diary_models.dart';
import '../repositories/shared_diary_repository.dart';
import '../widgets/sharing_wizard_sheet.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/diary_registry/diary_definition.dart';
import '../../../core/diary_registry/diary_category.dart';
import '../../../core/diary_engine/models/diary_record.dart';
import '../../../core/diary_engine/repositories/diary_record_repository.dart';
import '../../../core/providers/app_providers.dart';

final sharedWithMeStreamProvider =
    StreamProvider<List<SharedDiaryAccess>>((ref) {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.read(sharedDiaryRepositoryProvider);
  return repo.watchSharedWithMe(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
  );
});

final sharedByMeStreamProvider = StreamProvider<List<SharedDiaryAccess>>((ref) {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.read(sharedDiaryRepositoryProvider);
  return repo.watchSharedByMe(user.uid);
});

class SharedDiariesScreen extends ConsumerStatefulWidget {
  const SharedDiariesScreen({super.key});

  @override
  ConsumerState<SharedDiariesScreen> createState() =>
      _SharedDiariesScreenState();
}

class _SharedDiariesScreenState extends ConsumerState<SharedDiariesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DiaryCategoryType? _selectedCategory;
  SharingMode? _selectedSharingMode;
  ShareStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sharedWithMeAsync = ref.watch(sharedWithMeStreamProvider);
    final sharedByMeAsync = ref.watch(sharedByMeStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Diaries 🤝'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inbox_rounded), text: 'Shared With Me'),
            Tab(icon: Icon(Icons.outbox_rounded), text: 'Shared By Me'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showShareDiaryModal(context),
        icon: const Icon(Icons.share_rounded),
        label: const Text('Share Diary',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Filter Chips: Categories
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                ChoiceChip(
                  label: const Text('All Categories'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...DiaryCategory.allCategories.map((cat) {
                  final isSelected = _selectedCategory == cat.type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      avatar: Icon(cat.icon,
                          size: 16,
                          color: isSelected ? Colors.white : cat.color),
                      label: Text(cat.name),
                      selected: isSelected,
                      onSelected: (_) => setState(() {
                        _selectedCategory = isSelected ? null : cat.type;
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Secondary Filter Chips: Sharing Mode & Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Mode filter dropdown/chip
                FilterChip(
                  label: Text(_selectedSharingMode == null
                      ? 'All Modes'
                      : _selectedSharingMode!.shortLabel),
                  selected: _selectedSharingMode != null,
                  onSelected: (_) => _showModeFilterDialog(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(_selectedStatus == null
                      ? 'All Status'
                      : _selectedStatus!.name.toUpperCase()),
                  selected: _selectedStatus != null,
                  onSelected: (_) => _showStatusFilterDialog(),
                ),
                const Spacer(),
                if (_selectedCategory != null ||
                    _selectedSharingMode != null ||
                    _selectedStatus != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                        _selectedSharingMode = null;
                        _selectedStatus = null;
                      });
                    },
                    child: const Text('Reset', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Shared With Me
                sharedWithMeAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (shares) {
                    final displayedShares = _filterShares(shares);

                    if (displayedShares.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.inbox_outlined,
                        title: _selectedCategory != null ||
                                _selectedSharingMode != null
                            ? 'No Shared Diaries match filters'
                            : 'No Diaries Shared With You',
                        subtitle: _selectedCategory != null ||
                                _selectedSharingMode != null
                            ? 'Try resetting the filters above to view other shared diaries.'
                            : 'When family members or colleagues share diaries with you, they will appear here.',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: displayedShares.length,
                      itemBuilder: (context, index) {
                        final share = displayedShares[index];
                        final diaryDef =
                            DiaryRegistry.getDiaryById(share.diaryId);
                        final isEntire =
                            share.sharingMode == SharingMode.entire;

                        return Card(
                          elevation: 1.5,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          (diaryDef?.color ?? Colors.blue)
                                              .withValues(alpha: 0.15),
                                      child: Icon(
                                          diaryDef?.icon ?? Icons.auto_stories,
                                          color:
                                              diaryDef?.color ?? Colors.blue),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            share.diaryName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Owner: ${share.ownerName}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        share.permission.label,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Mode & Record Scope Chips
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isEntire
                                                ? Colors.teal
                                                : Colors.indigo)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isEntire
                                                ? Icons.library_books_rounded
                                                : Icons.checklist_rounded,
                                            size: 13,
                                            color: isEntire
                                                ? Colors.teal.shade800
                                                : Colors.indigo.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isEntire
                                                ? 'Entire Diary'
                                                : '${share.grantedRecordIds.length} Selected Records',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isEntire
                                                  ? Colors.teal.shade800
                                                  : Colors.indigo.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isEntire &&
                                        share.futurePolicySafe !=
                                            FutureRecordPolicy.allFuture)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          share.futurePolicySafe.label,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700),
                                        ),
                                      ),
                                    if (share.isTemporary &&
                                        share.expiresAt != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Expires ${DateFormat('d MMM yyyy').format(share.expiresAt!)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),

                                if (share.circleName != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.groups_outlined,
                                          size: 14, color: Colors.purple),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Linked to Circle: ${share.circleName}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.purple,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                                if (!isEntire) ...[
                                  const SizedBox(height: 12),
                                  _SelectedRecordsPreview(share: share),
                                ],
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(
                                          Icons.exit_to_app_rounded,
                                          size: 16,
                                          color: Colors.red),
                                      label: const Text('Leave Diary',
                                          style: TextStyle(
                                              color: Colors.red, fontSize: 12)),
                                      onPressed: () =>
                                          _confirmLeaveDiary(context, share),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        context.push(
                                          '/diary-records/${share.diaryId}?ownerId=${share.ownerUid}&ownerName=${Uri.encodeComponent(share.ownerName)}&permission=${share.permission.name}',
                                          extra: share,
                                        );
                                      },
                                      child: const Text('Open Diary'),
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

                // 2. Shared By Me
                sharedByMeAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (shares) {
                    final displayedShares = _filterShares(shares);

                    if (displayedShares.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.outbox_outlined,
                        title: _selectedCategory != null ||
                                _selectedSharingMode != null
                            ? 'No Shared Diaries match filters'
                            : 'You haven\'t shared any diaries yet',
                        subtitle: _selectedCategory != null ||
                                _selectedSharingMode != null
                            ? 'Try resetting the filters above to view other shared diaries.'
                            : 'Share bills, vehicles, warranties or properties with family members or circles.',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: displayedShares.length,
                      itemBuilder: (context, index) {
                        final share = displayedShares[index];
                        final diaryDef =
                            DiaryRegistry.getDiaryById(share.diaryId);
                        final isEntire =
                            share.sharingMode == SharingMode.entire;

                        return Card(
                          elevation: 1.5,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          (diaryDef?.color ?? Colors.blue)
                                              .withValues(alpha: 0.15),
                                      child: Icon(
                                          diaryDef?.icon ?? Icons.auto_stories,
                                          color:
                                              diaryDef?.color ?? Colors.blue),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            share.diaryName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            share.recipientType ==
                                                        RecipientType.circle &&
                                                    share.circleName != null
                                                ? 'Circle: ${share.circleName}'
                                                : 'Shared with: ${share.sharedWithEmail}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        share.permission.name.toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Mode, Policy & Scope Badges
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isEntire
                                                ? Colors.teal
                                                : Colors.indigo)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isEntire
                                                ? Icons.library_books_rounded
                                                : Icons.checklist_rounded,
                                            size: 13,
                                            color: isEntire
                                                ? Colors.teal.shade800
                                                : Colors.indigo.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isEntire
                                                ? 'Entire Diary'
                                                : '${share.grantedRecordIds.length} Selected Records',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isEntire
                                                  ? Colors.teal.shade800
                                                  : Colors.indigo.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isEntire)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          share.futurePolicySafe.label,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700),
                                        ),
                                      ),
                                    if (share.status != ShareStatus.active)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          share.status.name.toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    if (share.isTemporary &&
                                        share.expiresAt != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Expires ${DateFormat('d MMM yyyy').format(share.expiresAt!)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),

                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                          Icons.settings_suggest_rounded,
                                          size: 16),
                                      label: const Text('Manage Sharing',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        context.push(
                                          '/manage-shares/${share.diaryId}?title=${Uri.encodeComponent(share.diaryName)}',
                                        );
                                      },
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.block_rounded,
                                          size: 16, color: Colors.red),
                                      label: const Text('Revoke',
                                          style: TextStyle(
                                              color: Colors.red, fontSize: 12)),
                                      onPressed: () =>
                                          _confirmRevoke(context, share),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<SharedDiaryAccess> _filterShares(List<SharedDiaryAccess> shares) {
    return shares.where((s) {
      if (_selectedCategory != null) {
        final def = DiaryRegistry.getDiaryById(s.diaryId);
        if (def?.categoryType != _selectedCategory) return false;
      }
      if (_selectedSharingMode != null) {
        if (s.sharingMode != _selectedSharingMode) return false;
      }
      if (_selectedStatus != null) {
        if (s.status != _selectedStatus) return false;
      }
      return true;
    }).toList();
  }

  void _showModeFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by Sharing Mode'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedSharingMode = null);
              Navigator.pop(ctx);
            },
            child: const Text('All Modes'),
          ),
          ...SharingMode.values.map((mode) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() => _selectedSharingMode = mode);
                Navigator.pop(ctx);
              },
              child: Text(mode.label),
            );
          }),
        ],
      ),
    );
  }

  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by Share Status'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedStatus = null);
              Navigator.pop(ctx);
            },
            child: const Text('All Statuses'),
          ),
          ...ShareStatus.values.map((status) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() => _selectedStatus = status);
                Navigator.pop(ctx);
              },
              child: Text(status.name.toUpperCase()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _confirmRevoke(BuildContext context, SharedDiaryAccess share) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Diary Access?'),
        content: Text(
            'Are you sure you want to revoke access for ${share.sharedWithEmail}? They will immediately lose access to ${share.diaryName}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveDiary(BuildContext context, SharedDiaryAccess share) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Shared Diary?'),
        content: Text(
            'Are you sure you want to leave ${share.diaryName}? You will lose access until re-invited.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showShareDiaryModal(BuildContext context) {
    final alphabeticalDiaries = DiaryRegistry.predefinedDiariesAlphabetical;
    DiaryDefinition selectedDiary = alphabeticalDiaries.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.share_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text('Select Diary to Share'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Choose one of your 45 Life OS Diaries to launch the sharing wizard:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<DiaryDefinition>(
                initialValue: selectedDiary,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: alphabeticalDiaries.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Row(
                      children: [
                        Icon(d.icon, size: 18, color: d.color),
                        const SizedBox(width: 8),
                        Expanded(
                            child:
                                Text(d.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedDiary = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Launch Sharing Wizard'),
              onPressed: () {
                Navigator.pop(ctx);
                SharingWizardSheet.show(context, selectedDiary);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays records granted individually without issuing a collection query.
/// The read rules can authorize these document reads one by one.
class _SelectedRecordsPreview extends StatefulWidget {
  final SharedDiaryAccess share;

  const _SelectedRecordsPreview({required this.share});

  @override
  State<_SelectedRecordsPreview> createState() =>
      _SelectedRecordsPreviewState();
}

class _SelectedRecordsPreviewState extends State<_SelectedRecordsPreview> {
  late final Future<List<DiaryRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = DiaryRecordRepository().getRecordsByIds(
      userId: widget.share.ownerUid,
      diaryId: widget.share.diaryId,
      recordIds: widget.share.grantedRecordIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DiaryRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        if (snapshot.hasError) {
          return Text(
            'Shared records are unavailable right now.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          );
        }

        final records = snapshot.data ?? const <DiaryRecord>[];
        if (records.isEmpty) {
          return Text(
            'No shared records are available.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shared records',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...records.take(3).map(
                  (record) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined, size: 18),
                    title: Text(record.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        DateFormat('d MMM yyyy').format(record.recordDate)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => context.push(
                      '/diary-records/${widget.share.diaryId}/${record.id}?ownerId=${widget.share.ownerUid}&ownerName=${Uri.encodeComponent(widget.share.ownerName)}',
                      extra: record,
                    ),
                  ),
                ),
            if (records.length > 3)
              Text(
                '+ ${records.length - 3} more records',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        );
      },
    );
  }
}
