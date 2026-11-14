import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/household_management_models.dart';

class FamilyWorkspaceScreen extends ConsumerStatefulWidget {
  const FamilyWorkspaceScreen({super.key});

  @override
  ConsumerState<FamilyWorkspaceScreen> createState() => _FamilyWorkspaceScreenState();
}

class _FamilyWorkspaceScreenState extends ConsumerState<FamilyWorkspaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final householdsAsync = ref.watch(userHouseholdsProvider);
    final activeHouseholdId = ref.watch(activeHouseholdIdProvider);
    final tasksAsync = ref.watch(activeHouseholdTasksProvider);
    final settlementsAsync = ref.watch(activeHouseholdSettlementsProvider);
    final currentUser = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/diaries');
            }
          },
        ),
        title: const Text('Family Workspace 👨‍👩‍👧‍👦'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.task_alt), text: 'Shared Tasks'),
            Tab(icon: Icon(Icons.group_outlined), text: 'Members & Roles'),
            Tab(icon: Icon(Icons.handshake_outlined), text: 'Shared Expenses'),
          ],
        ),
      ),
      body: householdsAsync.when(
        data: (households) {
          if (households.isEmpty) {
            return _buildNoHouseholdState(context, currentUser?.uid ?? '');
          }

          // Default active household to first if none chosen
          final activeHousehold = households.firstWhere(
            (h) => h.id == activeHouseholdId,
            orElse: () => households.first,
          );

          final currentMember = activeHousehold.getMember(currentUser?.uid ?? '');

          return Column(
            children: [
              // Household Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    const Icon(Icons.home, size: 20, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeHousehold.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${activeHousehold.members.length} members • Your Role: ${(currentMember?.role ?? "member").toUpperCase()}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (currentMember?.isOwner == true || currentMember?.isAdmin == true)
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.person_add, size: 14),
                        label: const Text('Invite', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showInviteDialog(context, activeHousehold),
                      ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Shared Household Tasks
                    _buildTasksTab(context, activeHousehold, tasksAsync),

                    // TAB 2: Members & Role-Based Permissions
                    _buildMembersTab(context, activeHousehold, currentMember),

                    // TAB 3: Shared Expenses & Reimbursement Settlement
                    _buildSettlementsTab(context, activeHousehold, settlementsAsync),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading household: $e')),
      ),
    );
  }

  Widget _buildNoHouseholdState(BuildContext context, String userUid) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom, size: 64, color: Colors.blueAccent),
            const SizedBox(height: 16),
            Text(
              'Create Your Shared Family Household',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Coordinate domestic staff, assign vehicle/bill tasks, and track shared expenses without exposing private diaries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add_home),
              label: const Text('Create Household'),
              onPressed: () => _showCreateHouseholdDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab(BuildContext context, Household household, AsyncValue<List<HouseholdTask>> tasksAsync) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeHouseholdTasksProvider);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Household Responsibilities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Task'),
                  onPressed: () => _showAddTaskDialog(context, household),
                ),
              ],
            ),
            const SizedBox(height: 12),

            tasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text('No shared tasks currently open. Tap "New Task" to delegate chores, renewals, or bill payments.'),
                      ),
                    ),
                  );
                }

                return Column(
                  children: tasks.map((t) => _buildTaskTile(context, t)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, HouseholdTask task) {
    final currentUser = ref.read(userProfileProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (val) async {
            if (val == null || currentUser == null) return;
            final repo = ref.read(householdWorkspaceRepositoryProvider);
            await repo.toggleTaskComplete(task.id, val, currentUser.uid);
            ref.invalidate(activeHouseholdTasksProvider);
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          'Assigned to: ${task.assignedToName ?? "Anyone"} • Due: ${DateFormat('dd MMM').format(task.dueDate)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: task.priority == 'high' ? Colors.red.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            task.priority.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: task.priority == 'high' ? Colors.red : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersTab(BuildContext context, Household household, HouseholdMember? currentMember) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Family Members (${household.members.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Roles control permissions. Regular members only see shared tasks & attendance without accessing private salary advances or personal vaults.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          ...household.members.map((m) {
            final isSelf = m.uid == currentMember?.uid;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: m.isOwner ? Colors.amber.shade100 : Colors.blue.shade100,
                  child: Icon(m.isOwner ? Icons.star : Icons.person, color: m.isOwner ? Colors.amber.shade900 : Colors.blue),
                ),
                title: Row(
                  children: [
                    Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      const Text('(You)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
                subtitle: Text('${m.email} • Joined: ${DateFormat('MMM yyyy').format(m.joinedAt)}'),
                trailing: Chip(
                  label: Text(m.role.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettlementsTab(BuildContext context, Household household, AsyncValue<List<InterMemberSettlement>> settlementsAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No Double Counting: When Member A pays an electricity bill of ₹4,000, only ONE ₹4,000 expense is created in the financial ledger. Member B owes Member A ₹2,000 as a separate internal reimbursement.',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Internal Reimbursements',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Split Expense'),
                onPressed: () => _showAddSettlementDialog(context, household),
              ),
            ],
          ),
          const SizedBox(height: 12),

          settlementsAsync.when(
            data: (settlements) {
              if (settlements.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Text('No inter-member balances owed. All shared household costs are squared up.'),
                    ),
                  ),
                );
              }

              return Column(
                children: settlements.map((s) => _buildSettlementTile(context, s)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementTile(BuildContext context, InterMemberSettlement s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: s.isSettled ? Colors.green.shade100 : Colors.orange.shade100,
          child: Icon(s.isSettled ? Icons.check : Icons.currency_rupee, color: s.isSettled ? Colors.green : Colors.orange.shade900),
        ),
        title: Text('${s.payerName} owes ${s.receiverName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('${s.reason} • ${DateFormat('dd MMM').format(s.date)}', style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppFormatters.currency(s.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            if (!s.isSettled)
              FilledButton.tonal(
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () async {
                  final repo = ref.read(householdWorkspaceRepositoryProvider);
                  await repo.markSettlementPaid(s.id);
                  ref.invalidate(activeHouseholdSettlementsProvider);
                },
                child: const Text('Settle', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  // --- Dialogs ---
  void _showCreateHouseholdDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'My Family Household');
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Family Household'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Household Name *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final repo = ref.read(householdWorkspaceRepositoryProvider);
              final h = await repo.createHousehold(
                ownerUid: user.uid,
                ownerEmail: user.email,
                ownerDisplayName: user.displayName,
                householdName: name,
              );

              ref.read(activeHouseholdIdProvider.notifier).state = h.id;
              ref.invalidate(userHouseholdsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, Household household) {
    final emailCtrl = TextEditingController();
    String role = 'member';
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Invite Family Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address *')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Assigned Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin (Can approve salary & view bills)')),
                  DropdownMenuItem(value: 'member', child: Text('Member (Can record attendance & tasks)')),
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer (Read-only)')),
                ],
                onChanged: (v) {
                  if (v != null) setSt(() => role = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty) return;

                final repo = ref.read(householdWorkspaceRepositoryProvider);
                final inv = await repo.createInvitation(
                  householdId: household.id,
                  householdName: household.name,
                  inviterUid: user.uid,
                  inviterName: user.displayName,
                  inviteeEmail: email,
                  role: role,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invitation token generated: ${inv.token} (valid 7 days)')),
                  );
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, Household household) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));
    String priority = 'medium';
    HouseholdMember? assignedMember;
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Assign Household Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task Title *')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<HouseholdMember?>(
                  initialValue: assignedMember,
                  decoration: const InputDecoration(labelText: 'Assign to Member'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Anyone in Household')),
                    ...household.members.map((m) => DropdownMenuItem(value: m, child: Text(m.displayName))),
                  ],
                  onChanged: (v) => setSt(() => assignedMember = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('🔴 High')),
                    DropdownMenuItem(value: 'medium', child: Text('🟡 Medium')),
                    DropdownMenuItem(value: 'low', child: Text('🟢 Low')),
                  ],
                  onChanged: (v) {
                    if (v != null) setSt(() => priority = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;

                final repo = ref.read(householdWorkspaceRepositoryProvider);
                await repo.addTask(
                  HouseholdTask(
                    id: const Uuid().v4(),
                    householdId: household.id,
                    title: title,
                    description: descCtrl.text.trim(),
                    assignedToUid: assignedMember?.uid,
                    assignedToName: assignedMember?.displayName,
                    dueDate: dueDate,
                    priority: priority,
                    createdByUid: user.uid,
                    createdAt: DateTime.now(),
                  ),
                );
                ref.invalidate(activeHouseholdTasksProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSettlementDialog(BuildContext context, Household household) {
    if (household.members.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least 2 members are required to split expenses.')));
      return;
    }

    HouseholdMember payer = household.members[0];
    HouseholdMember receiver = household.members[1];
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Electricity Bill Split (50%)');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Split Expense / Reimbursement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<HouseholdMember>(
                  initialValue: payer,
                  decoration: const InputDecoration(labelText: 'Who Owes (Payer)'),
                  items: household.members.map((m) => DropdownMenuItem(value: m, child: Text(m.displayName))).toList(),
                  onChanged: (v) {
                    if (v != null) setSt(() => payer = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<HouseholdMember>(
                  initialValue: receiver,
                  decoration: const InputDecoration(labelText: 'Who Paid (Receiver)'),
                  items: household.members.map((m) => DropdownMenuItem(value: m, child: Text(m.displayName))).toList(),
                  onChanged: (v) {
                    if (v != null) setSt(() => receiver = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Owed Amount (₹) *')),
                const SizedBox(height: 8),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason / Description *')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt <= 0 || payer.uid == receiver.uid) return;

                final repo = ref.read(householdWorkspaceRepositoryProvider);
                await repo.recordSettlement(
                  InterMemberSettlement(
                    id: const Uuid().v4(),
                    householdId: household.id,
                    payerUid: payer.uid,
                    payerName: payer.displayName,
                    receiverUid: receiver.uid,
                    receiverName: receiver.displayName,
                    amount: amt,
                    reason: reasonCtrl.text.trim(),
                    date: DateTime.now(),
                  ),
                );
                ref.invalidate(activeHouseholdSettlementsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Record Split'),
            ),
          ],
        ),
      ),
    );
  }
}
