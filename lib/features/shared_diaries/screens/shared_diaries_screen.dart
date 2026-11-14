import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/shared_diary_models.dart';
import '../repositories/shared_diary_repository.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/diary_registry/diary_definition.dart';
import '../../../core/diary_registry/diary_category.dart';
import '../../../core/providers/app_providers.dart';

final sharedDiaryRepositoryProvider = Provider<SharedDiaryRepository>((ref) => SharedDiaryRepository());

final sharedWithMeStreamProvider = StreamProvider<List<SharedDiaryAccess>>((ref) {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.read(sharedDiaryRepositoryProvider);
  return repo.watchSharedWithMe(user.uid);
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
  ConsumerState<SharedDiariesScreen> createState() => _SharedDiariesScreenState();
}

class _SharedDiariesScreenState extends ConsumerState<SharedDiariesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DiaryCategoryType? _selectedCategory;

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
        label: const Text('Share Diary', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Category Filter Chips
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
                      avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
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
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Shared With Me
                sharedWithMeAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (shares) {
                    final displayedShares = _selectedCategory == null
                        ? shares
                        : shares.where((s) {
                            final def = DiaryRegistry.getDiaryById(s.diaryId);
                            return def?.categoryType == _selectedCategory;
                          }).toList();

                    if (displayedShares.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.inbox_outlined,
                        title: _selectedCategory != null
                            ? 'No Shared Diaries in this Category'
                            : 'No Diaries Shared With You',
                        subtitle: _selectedCategory != null
                            ? 'Try selecting "All Categories" to view other shared diaries.'
                            : 'When family members or colleagues share diaries with you, they will appear here.',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: displayedShares.length,
                      itemBuilder: (context, index) {
                        final share = displayedShares[index];
                  final diaryDef = DiaryRegistry.getDiaryById(share.diaryId);
                  return Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (diaryDef?.color ?? Colors.blue).withValues(alpha: 0.15),
                                child: Icon(diaryDef?.icon ?? Icons.auto_stories, color: diaryDef?.color ?? Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      share.diaryName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Owner: ${share.ownerName}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  share.permission.label,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                ),
                              ),
                            ],
                          ),
                          if (share.circleName != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.groups_outlined, size: 14, color: Colors.purple),
                                const SizedBox(width: 4),
                                Text(
                                  'Linked to Circle: ${share.circleName}',
                                  style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.exit_to_app_rounded, size: 16, color: Colors.red),
                                label: const Text('Leave Diary', style: TextStyle(color: Colors.red, fontSize: 12)),
                                onPressed: () => _confirmLeaveDiary(context, share),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (diaryDef?.hasDedicatedRoute ?? false) {
                                    context.push(diaryDef!.dedicatedRoute!);
                                  } else {
                                    context.push('/diary-records/${share.diaryId}');
                                  }
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (shares) {
              final displayedShares = _selectedCategory == null
                  ? shares
                  : shares.where((s) {
                      final def = DiaryRegistry.getDiaryById(s.diaryId);
                      return def?.categoryType == _selectedCategory;
                    }).toList();

              if (displayedShares.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.outbox_outlined,
                  title: _selectedCategory != null
                      ? 'No Shared Diaries in this Category'
                      : 'You haven\'t shared any diaries yet',
                  subtitle: _selectedCategory != null
                      ? 'Try selecting "All Categories" to view other shared diaries.'
                      : 'Share bills, vehicles, warranties or properties with family members or friends.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: displayedShares.length,
                itemBuilder: (context, index) {
                  final share = displayedShares[index];
                  final diaryDef = DiaryRegistry.getDiaryById(share.diaryId);
                  return Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (diaryDef?.color ?? Colors.blue).withValues(alpha: 0.15),
                                child: Icon(diaryDef?.icon ?? Icons.auto_stories, color: diaryDef?.color ?? Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      share.diaryName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Shared with: ${share.sharedWithEmail}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  share.permission.name.toUpperCase(),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Shared on ${DateFormat('d MMM yyyy').format(share.createdAt)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.block_rounded, size: 16, color: Colors.red),
                                label: const Text('Revoke Access', style: TextStyle(color: Colors.red, fontSize: 12)),
                                onPressed: () => _confirmRevoke(context, share),
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
        content: Text('Are you sure you want to revoke access for ${share.sharedWithEmail}? They will immediately lose access to ${share.diaryName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sharedDiaryRepositoryProvider).revokeShareAccess(share.id);
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
        content: Text('Are you sure you want to leave ${share.diaryName}? You will lose access until re-invited.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(sharedDiaryRepositoryProvider).revokeShareAccess(share.id);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showShareDiaryModal(BuildContext context) {
    final emailController = TextEditingController();
    var selectedDiary = DiaryRegistry.predefinedDiaries.first;
    var selectedPermission = SharedDiaryPermission.viewer;
    var shareEntire = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share a Diary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              DropdownButtonFormField<DiaryDefinition>(
                initialValue: selectedDiary,
                decoration: InputDecoration(
                  labelText: 'Select Diary to Share',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: DiaryRegistry.predefinedDiaries
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedDiary = val);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Recipient Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<SharedDiaryPermission>(
                initialValue: selectedPermission,
                decoration: InputDecoration(
                  labelText: 'Permission Level',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: SharedDiaryPermission.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedPermission = val);
                },
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Share Complete Diary'),
                subtitle: const Text('Shares all non-private records in this diary'),
                value: shareEntire,
                onChanged: (val) => setModalState(() => shareEntire = val),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid email')),
                      );
                      return;
                    }
                    final user = ref.read(userProfileProvider);
                    if (user == null) return;

                    final shareId = const Uuid().v4();
                    final share = SharedDiaryAccess(
                      id: shareId,
                      diaryId: selectedDiary.id,
                      diaryName: selectedDiary.name,
                      ownerUid: user.uid,
                      ownerName: user.displayName,
                      sharedWithUid: 'pending_$email',
                      sharedWithEmail: email,
                      sharedWithName: email.split('@').first,
                      permission: selectedPermission,
                      shareEntireDiary: shareEntire,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    await ref.read(sharedDiaryRepositoryProvider).createShareAccess(share);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Send Invitation', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
