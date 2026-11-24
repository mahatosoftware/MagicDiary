import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/magic_circle_models.dart';
import '../models/circle_candidate_member.dart';
import '../widgets/add_circle_member_sheet.dart';
import '../widgets/circle_share_invite_dialog.dart';
import 'magic_circles_screen.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/diary_registry/diary_definition.dart';
import '../../../core/diary_registry/diary_category.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared_diaries/models/shared_diary_models.dart';
import '../../shared_diaries/repositories/frequent_contacts_repository.dart';
import '../../shared_diaries/screens/shared_diaries_screen.dart';
import '../../shared_diaries/widgets/sharing_wizard_sheet.dart';

final circleTasksStreamProvider =
    StreamProvider.family<List<CircleResponsibilityTask>, String>(
        (ref, circleId) {
  final repo = ref.read(magicCircleRepositoryProvider);
  return repo.watchCircleTasks(circleId);
});

final circleExpensesStreamProvider =
    StreamProvider.family<List<CircleExpense>, String>((ref, circleId) {
  final repo = ref.read(magicCircleRepositoryProvider);
  return repo.watchCircleExpenses(circleId);
});

class CircleDashboardScreen extends ConsumerStatefulWidget {
  final String circleId;
  final MagicCircle? initialCircle;

  const CircleDashboardScreen({
    super.key,
    required this.circleId,
    this.initialCircle,
  });

  @override
  ConsumerState<CircleDashboardScreen> createState() =>
      _CircleDashboardScreenState();
}

class _CircleDashboardScreenState extends ConsumerState<CircleDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DiaryCategoryType? _selectedDiaryCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circlesAsync = ref.watch(userCirclesStreamProvider);
    final circle = circlesAsync.value?.firstWhere(
          (c) => c.id == widget.circleId,
          orElse: () =>
              widget.initialCircle ??
              MagicCircle(
                id: widget.circleId,
                name: 'Circle',
                ownerId: '',
                members: [],
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
        ) ??
        widget.initialCircle;

    if (circle == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = ref.watch(userProfileProvider);
    final currentMember = circle.getMember(user?.uid ?? '');
    final tasksAsync = ref.watch(circleTasksStreamProvider(widget.circleId));
    final expensesAsync =
        ref.watch(circleExpensesStreamProvider(widget.circleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(circle.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Circle QR & Share',
            onPressed: () {
              CircleShareInviteDialog.show(
                context,
                circle: circle,
                isAdmin: currentMember?.role.isAdmin ?? false,
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'share_diary') {
                _showAddDiaryModal(context, circle);
              } else if (val == 'share') {
                CircleShareInviteDialog.show(
                  context,
                  circle: circle,
                  isAdmin: currentMember?.role.isAdmin ?? false,
                );
              } else if (val == 'leave') {
                _handleLeaveCircle(context, circle, user?.uid ?? '');
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'share_diary',
                child: Row(
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 20, color: Colors.deepPurple),
                    SizedBox(width: 10),
                    Text('Share Diary with Circle'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Circle Code & QR'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Leave Circle', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.task_alt_rounded), text: 'Responsibilities'),
            Tab(icon: Icon(Icons.auto_stories_rounded), text: 'Shared Diaries'),
            Tab(icon: Icon(Icons.handshake_outlined), text: 'Shared Expenses'),
            Tab(icon: Icon(Icons.group_rounded), text: 'Members & Roles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Responsibilities (Tasks)
          _buildTasksTab(tasksAsync, circle),

          // 2. Shared Diaries
          _buildDiariesTab(circle),

          // 3. Shared Expenses
          _buildExpensesTab(expensesAsync, circle),

          // 4. Members & Roles
          _buildMembersTab(circle, currentMember),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: SHARED TASKS / RESPONSIBILITIES
  // -------------------------------------------------------------
  Widget _buildTasksTab(AsyncValue<List<CircleResponsibilityTask>> tasksAsync,
      MagicCircle circle) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskModal(context, circle),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Assign Task'),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Tasks in this Circle',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                      'Assign responsibilities like paying bills or grocery shopping to members.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: IconButton(
                    icon: Icon(
                      task.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: task.isCompleted ? Colors.green : Colors.grey,
                    ),
                    onPressed: task.isCompleted
                        ? null
                        : () async {
                            await ref
                                .read(magicCircleRepositoryProvider)
                                .completeCircleTask(circle.id, task.id);
                          },
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? Colors.grey : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Assigned to: ${task.assignedToName ?? "Unassigned"} • Due: ${DateFormat('d MMM yyyy').format(task.dueDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: task.priority == 'high'
                          ? Colors.red.shade50
                          : task.priority == 'low'
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: task.priority == 'high'
                            ? Colors.red.shade700
                            : task.priority == 'low'
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: SHARED DIARIES IN CIRCLE
  // -------------------------------------------------------------
  Widget _buildDiariesTab(MagicCircle circle) {
    final sharedWithMe = ref.watch(sharedWithMeStreamProvider).value ?? const [];
    final sharedByMe = ref.watch(sharedByMeStreamProvider).value ?? const [];
    final circleShares = [...sharedWithMe, ...sharedByMe].where((s) => s.circleId == circle.id);
    final combinedDiaryIds = {...circle.sharedDiaryIds, ...circleShares.map((s) => s.diaryId)}.toList();

    final allSharedDiaries = combinedDiaryIds
        .map((id) => DiaryRegistry.getDiaryById(id))
        .whereType<DiaryDefinition>()
        .toList();

    final filteredDiaries = _selectedDiaryCategory == null
        ? allSharedDiaries
        : allSharedDiaries
            .where((d) => d.categoryType == _selectedDiaryCategory)
            .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDiaryModal(context, circle),
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('Share Diary with Circle'),
      ),
      body: Column(
        children: [
          // Category Filter Chips
          if (allSharedDiaries.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  ChoiceChip(
                    label: const Text('All Categories'),
                    selected: _selectedDiaryCategory == null,
                    onSelected: (_) =>
                        setState(() => _selectedDiaryCategory = null),
                  ),
                  const SizedBox(width: 8),
                  ...DiaryCategory.allCategories.map((cat) {
                    final isSelected = _selectedDiaryCategory == cat.type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        avatar: Icon(cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : cat.color),
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) => setState(() {
                          _selectedDiaryCategory = isSelected ? null : cat.type;
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
          Expanded(
            child: filteredDiaries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _selectedDiaryCategory != null
                                ? 'No Diaries in this Category'
                                : 'No Diaries Added Yet',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedDiaryCategory != null
                                ? 'Try selecting "All Categories" or share a new diary.'
                                : 'Share bills, groceries, vehicle or property diaries with circle members.',
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _showAddDiaryModal(context, circle),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Share Diary with Circle'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: filteredDiaries.length,
                    itemBuilder: (context, index) {
                      final diary = filteredDiaries[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor:
                                diary.color.withValues(alpha: 0.15),
                            child: Icon(diary.icon, color: diary.color),
                          ),
                          title: Text(diary.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(diary.description,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            final currentUser = ref.read(userProfileProvider);
                            final sharedWithMe = ref.read(sharedWithMeStreamProvider).value ?? const [];
                            final sharedByMe = ref.read(sharedByMeStreamProvider).value ?? const [];

                            // 1. Check if another member shared this diary to this circle
                            final memberShare = sharedWithMe.where((s) => s.diaryId == diary.id && s.circleId == circle.id).firstOrNull;

                            // 2. Check if current user is the author who shared this diary to this circle
                            final ownShare = sharedByMe.where((s) => s.diaryId == diary.id && s.circleId == circle.id).firstOrNull;

                            if (ownShare != null || (memberShare == null && circle.ownerId == currentUser?.uid)) {
                              // Current user is the owner/author of this diary in the circle
                              context.push(
                                '/diary-records/${diary.id}?ownerId=${currentUser?.uid}&ownerName=${Uri.encodeComponent("You (${circle.name})")}&circleId=${circle.id}',
                              );
                              return;
                            }

                            // 3. User is viewing a diary shared by another member
                            final effectiveShare = memberShare ?? sharedWithMe.where((s) => s.diaryId == diary.id).firstOrNull;
                            final targetOwnerId = effectiveShare?.ownerUid.isNotEmpty == true ? effectiveShare!.ownerUid : circle.ownerId;
                            final targetOwnerName = effectiveShare?.ownerName.isNotEmpty == true ? effectiveShare!.ownerName : circle.name;
                            final permission = effectiveShare?.permission.name ?? SharedDiaryPermission.contributor.name;

                            context.push(
                              '/diary-records/${diary.id}?ownerId=$targetOwnerId&ownerName=${Uri.encodeComponent(targetOwnerName)}&permission=$permission&circleId=${circle.id}',
                              extra: effectiveShare,
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: SHARED EXPENSES
  // -------------------------------------------------------------
  Widget _buildExpensesTab(
      AsyncValue<List<CircleExpense>> expensesAsync, MagicCircle circle) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseModal(context, circle),
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Add Group Expense'),
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (expenses) {
          final totalSpent =
              expenses.fold<double>(0.0, (acc, e) => acc + e.amount);

          return Column(
            children: [
              // Summary Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.shade700,
                      child: const Icon(Icons.account_balance_wallet,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Group Expenditure',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '₹${totalSpent.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('No Group Expenses Recorded',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            const Text(
                                'Record group groceries, travel, or maintenance bills and split them evenly.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              title: Text(expense.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Paid by ${expense.paidByName} • Split among ${expense.participantUids.length} members',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: Text(
                                '₹${expense.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: MEMBERS & ROLES
  // -------------------------------------------------------------
  Widget _buildMembersTab(
      MagicCircle circle, MagicCircleMember? currentMember) {
    final isAdmin = currentMember?.role.isAdmin ?? false;
    final currentUserId = ref.read(userProfileProvider)?.uid ?? '';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          CircleShareInviteDialog.show(
            context,
            circle: circle,
            isAdmin: isAdmin,
          );
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Invite & Share QR'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          // 1. Pending Join Requests Section (Visible to Admins)
          if (isAdmin && circle.pendingMemberIds.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pending_actions_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Text(
                        'Pending Requests (${circle.pendingMemberIds.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These users requested to join via your general circle code and require approval.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                  const SizedBox(height: 12),
                  ...circle.pendingMemberIds.map(
                    (applicantUid) => _PendingApplicantCard(
                      applicantUid: applicantUid,
                      circle: circle,
                      ref: ref,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. Circle Code & Quick Info Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.vpn_key_rounded, color: Colors.deepPurple),
              title: Text('Group Code: ${circle.code.isNotEmpty ? circle.code : "N/A"}'),
              subtitle: const Text('Tap to view QR & Share invite link', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              onTap: () {
                CircleShareInviteDialog.show(
                  context,
                  circle: circle,
                  isAdmin: isAdmin,
                );
              },
            ),
          ),

          // 3. Active Members List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${circle.members.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                onPressed: () => _showInviteMemberModal(context, circle),
                icon: const Icon(Icons.mail_outline, size: 16),
                label: const Text('Invite by Email', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. Member Cards with Admin Actions
          ...circle.members.map((member) {
            final isSelf = member.uid == currentUserId;
            final isOwner = member.role == CircleRole.owner || circle.ownerId == member.uid;
            final isMemberAdmin = member.role == CircleRole.admin || isOwner;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : 'M',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                subtitle: Text(member.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOwner
                            ? Colors.purple.shade50
                            : (isMemberAdmin ? Colors.blue.shade50 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        member.role.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOwner
                              ? Colors.purple.shade700
                              : (isMemberAdmin ? Colors.blue.shade700 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                    if (isAdmin && !isSelf && !isOwner) ...[
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (action) async {
                          final repo = ref.read(magicCircleRepositoryProvider);
                          if (action == 'promote') {
                            await repo.promoteToAdmin(circle.id, member.uid);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Promoted ${member.displayName} to Admin')),
                            );
                          } else if (action == 'demote') {
                            await repo.demoteFromAdmin(circle.id, member.uid);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Demoted ${member.displayName} to Contributor')),
                            );
                          } else if (action == 'remove') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove Member?'),
                                content: Text('Remove ${member.displayName} from ${circle.name}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await repo.removeMember(circle.id, member.uid);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Removed ${member.displayName} from circle')),
                              );
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (!isMemberAdmin)
                            const PopupMenuItem(
                              value: 'promote',
                              child: Text('Promote to Admin'),
                            )
                          else
                            const PopupMenuItem(
                              value: 'demote',
                              child: Text('Demote from Admin'),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove Member', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _handleLeaveCircle(
    BuildContext context,
    MagicCircle circle,
    String currentUserId,
  ) {
    if (currentUserId.isEmpty) return;

    final isUserAdmin = circle.isCircleAdmin(currentUserId);
    final otherAdmins = circle.adminIds.where((id) => id != currentUserId).toList();

    // 1. Successor check: If user is the ONLY admin and other members exist
    if (isUserAdmin && otherAdmins.isEmpty && circle.members.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Admin Transfer Required'),
            ],
          ),
          content: const Text(
            'You are the sole administrator of this circle. You must promote another member to Admin before leaving.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Circle?'),
        content: Text(
          circle.members.length <= 1
              ? 'You are the last member. Leaving will schedule this circle for deletion.'
              : 'Are you sure you want to leave "${circle.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(magicCircleRepositoryProvider);
                await repo.removeMember(circle.id, currentUserId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Left circle successfully.')),
                  );
                  context.go('/circles');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to leave circle: $e')),
                  );
                }
              }
            },
            child: const Text('Leave Circle'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MODALS & ACTIONS
  // -------------------------------------------------------------
  void _showAddTaskModal(BuildContext context, MagicCircle circle) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    var dueDate = DateTime.now().add(const Duration(days: 1));
    String? assignedUid;
    String? assignedName;
    var priority = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Responsibility',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title *',
                  hintText: 'e.g. Pay electricity bill, Buy milk',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MagicCircleMember>(
                decoration: InputDecoration(
                  labelText: 'Assign to Member',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: circle.members
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m.displayName)))
                    .toList(),
                onChanged: (member) {
                  if (member != null) {
                    setModalState(() {
                      assignedUid = member.uid;
                      assignedName = member.displayName;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2200),
                  );
                  if (picked != null) setModalState(() => dueDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(DateFormat('d MMM yyyy').format(dueDate)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final user = ref.read(userProfileProvider);
                    if (user == null) return;

                    final task = CircleResponsibilityTask(
                      id: const Uuid().v4(),
                      circleId: circle.id,
                      title: title,
                      description: descController.text.trim(),
                      assignedToUid: assignedUid,
                      assignedToName: assignedName,
                      createdByUid: user.uid,
                      dueDate: dueDate,
                      priority: priority,
                      createdAt: DateTime.now(),
                    );

                    await ref
                        .read(magicCircleRepositoryProvider)
                        .saveCircleTask(task);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Assign Task',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDiaryModal(BuildContext context, MagicCircle circle) {
    final alphabeticalDiaries = DiaryRegistry.predefinedDiariesAlphabetical;
    var selectedDiary = alphabeticalDiaries.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: const Icon(Icons.auto_stories_rounded,
                        color: Colors.deepPurple),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Share Diary with Circle',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Collaborate on entries with circle members',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<DiaryDefinition>(
                initialValue: selectedDiary,
                decoration: InputDecoration(
                  labelText: 'Select Diary to Share *',
                  prefixIcon: Icon(selectedDiary.icon, color: selectedDiary.color),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: alphabeticalDiaries
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Row(
                            children: [
                              Icon(d.icon, color: d.color, size: 20),
                              const SizedBox(width: 10),
                              Text(d.name),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedDiary = val);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await SharingWizardSheet.showForCircle(
                      context,
                      selectedDiary,
                      circle,
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Configure & Share Diary',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddExpenseModal(BuildContext context, MagicCircle circle) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    var paidByMember = circle.members.firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Group Expense',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Expense Description *',
                  hintText: 'e.g. Weekly Groceries, Fuel, Hotel Booking',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MagicCircleMember>(
                initialValue: paidByMember,
                decoration: InputDecoration(
                  labelText: 'Paid By',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: circle.members
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m.displayName)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => paidByMember = val);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (title.isEmpty || amount <= 0 || paidByMember == null) {
                      return;
                    }

                    final participants =
                        circle.members.map((m) => m.uid).toList();
                    final splitPerPerson = amount /
                        (participants.isEmpty ? 1 : participants.length);
                    final matrix = {
                      for (final uid in participants) uid: splitPerPerson
                    };

                    final expense = CircleExpense(
                      id: const Uuid().v4(),
                      circleId: circle.id,
                      title: title,
                      amount: amount,
                      paidByUid: paidByMember!.uid,
                      paidByName: paidByMember!.displayName,
                      participantUids: participants,
                      splitType: 'equal',
                      splitMatrix: matrix,
                      expenseDate: DateTime.now(),
                    );

                    await ref
                        .read(magicCircleRepositoryProvider)
                        .saveCircleExpense(expense);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Expense',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteMemberModal(BuildContext context, MagicCircle circle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'Add Member to Circle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade50,
                child: const Icon(Icons.person_add_rounded, color: Colors.deepPurple),
              ),
              title: const Text('Add by Username, QR, Email, or Contacts'),
              subtitle: const Text('Search username, scan profile QR, or pick existing contacts'),
              trailing: const Icon(Icons.chevron_right_rounded),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              onTap: () {
                Navigator.pop(ctx);
                AddCircleMemberSheet.show(
                  context,
                  existingCircle: circle,
                  onMemberAdded: (candidate) async {
                    await _addMemberToCircle(context, circle, candidate);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.amber.shade50,
                child: Icon(Icons.link_rounded, color: Colors.amber.shade900),
              ),
              title: const Text('Share Invite Link'),
              subtitle: const Text('Generate link & QR code for WhatsApp, SMS or messaging'),
              trailing: const Icon(Icons.chevron_right_rounded),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              onTap: () {
                Navigator.pop(ctx);
                CircleShareInviteDialog.show(context, circle: circle);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _addMemberToCircle(
    BuildContext context,
    MagicCircle circle,
    CircleCandidateMember candidate,
  ) async {
    final existingMember = circle.members.where((m) =>
        (candidate.uid != null && m.uid == candidate.uid) ||
        m.email.toLowerCase() == candidate.email.toLowerCase()).firstOrNull;

    if (existingMember != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${candidate.displayName} is already a member of this Circle')),
        );
      }
      return;
    }

    final newMember = candidate.toMagicCircleMember();
    final updatedCircle = MagicCircle(
      id: circle.id,
      name: circle.name,
      description: circle.description,
      category: circle.category,
      ownerId: circle.ownerId,
      members: [...circle.members, newMember],
      sharedDiaryIds: circle.sharedDiaryIds,
      coverImageUrl: circle.coverImageUrl,
      createdAt: circle.createdAt,
      updatedAt: DateTime.now(),
    );

    await ref.read(magicCircleRepositoryProvider).updateCircle(updatedCircle);

    // Record frequent contact usage
    final currentUser = ref.read(userProfileProvider);
    if (currentUser != null) {
      try {
        await ref.read(frequentContactsRepositoryProvider).recordContactUsage(
              userId: currentUser.uid,
              email: candidate.email,
              name: candidate.displayName,
              username: candidate.username,
            );
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${candidate.displayName} to ${circle.name}!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }
}

class _PendingApplicantCard extends StatelessWidget {
  final String applicantUid;
  final MagicCircle circle;
  final WidgetRef ref;

  const _PendingApplicantCard({
    required this.applicantUid,
    required this.circle,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(applicantUid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['displayName'] as String? ??
            (applicantUid.length > 8 ? '${applicantUid.substring(0, 8)}...' : applicantUid);
        final email = data?['email'] as String? ?? 'Requested via circle code';
        final photoUrl = data?['photoUrl'] as String?;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.amber.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.shade100,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    )
                  : null,
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                  tooltip: 'Approve',
                  onPressed: () async {
                    final repo = ref.read(magicCircleRepositoryProvider);
                    await repo.approveMember(
                      circle.id,
                      applicantUid,
                      displayName: data?['displayName'] as String?,
                      email: data?['email'] as String?,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$name approved and added to ${circle.name}!'),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                  tooltip: 'Reject',
                  onPressed: () async {
                    final repo = ref.read(magicCircleRepositoryProvider);
                    await repo.rejectMember(circle.id, applicantUid);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Request from $name rejected')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
