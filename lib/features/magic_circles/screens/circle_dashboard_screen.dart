import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/magic_circle_models.dart';
import 'magic_circles_screen.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/diary_registry/diary_definition.dart';
import '../../../core/diary_registry/diary_category.dart';
import '../../../core/providers/app_providers.dart';

final circleTasksStreamProvider = StreamProvider.family<List<CircleResponsibilityTask>, String>((ref, circleId) {
  final repo = ref.read(magicCircleRepositoryProvider);
  return repo.watchCircleTasks(circleId);
});

final circleExpensesStreamProvider = StreamProvider.family<List<CircleExpense>, String>((ref, circleId) {
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
  ConsumerState<CircleDashboardScreen> createState() => _CircleDashboardScreenState();
}

class _CircleDashboardScreenState extends ConsumerState<CircleDashboardScreen> with SingleTickerProviderStateMixin {
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
          orElse: () => widget.initialCircle ?? MagicCircle(
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
    final expensesAsync = ref.watch(circleExpensesStreamProvider(widget.circleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(circle.name),
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
  Widget _buildTasksTab(AsyncValue<List<CircleResponsibilityTask>> tasksAsync, MagicCircle circle) {
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
                  Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Tasks in this Circle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Assign responsibilities like paying bills or grocery shopping to members.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: IconButton(
                    icon: Icon(
                      task.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
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
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? Colors.grey : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Assigned to: ${task.assignedToName ?? "Unassigned"} • Due: ${DateFormat('d MMM yyyy').format(task.dueDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    final allSharedDiaries = circle.sharedDiaryIds
        .map((id) => DiaryRegistry.getDiaryById(id))
        .whereType<DiaryDefinition>()
        .toList();

    final filteredDiaries = _selectedDiaryCategory == null
        ? allSharedDiaries
        : allSharedDiaries.where((d) => d.categoryType == _selectedDiaryCategory).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDiaryModal(context, circle),
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('Add Diary to Circle'),
      ),
      body: Column(
        children: [
          // Category Filter Chips
          if (allSharedDiaries.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  ChoiceChip(
                    label: const Text('All Categories'),
                    selected: _selectedDiaryCategory == null,
                    onSelected: (_) => setState(() => _selectedDiaryCategory = null),
                  ),
                  const SizedBox(width: 8),
                  ...DiaryCategory.allCategories.map((cat) {
                    final isSelected = _selectedDiaryCategory == cat.type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_stories_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _selectedDiaryCategory != null
                              ? 'No Diaries in this Category'
                              : 'No Diaries Added Yet',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedDiaryCategory != null
                              ? 'Try selecting "All Categories" or add a new diary.'
                              : 'Share bills, groceries, vehicle or property diaries with circle members.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: filteredDiaries.length,
                    itemBuilder: (context, index) {
                      final diary = filteredDiaries[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: diary.color.withValues(alpha: 0.15),
                            child: Icon(diary.icon, color: diary.color),
                          ),
                          title: Text(diary.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(diary.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            if (diary.hasDedicatedRoute) {
                              context.push(diary.dedicatedRoute!);
                            } else {
                              context.push('/diary-records/${diary.id}');
                            }
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
  Widget _buildExpensesTab(AsyncValue<List<CircleExpense>> expensesAsync, MagicCircle circle) {
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
          final totalSpent = expenses.fold<double>(0.0, (acc, e) => acc + e.amount);

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
                      child: const Icon(Icons.account_balance_wallet, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Group Expenditure', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          '₹${totalSpent.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade800),
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
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('No Group Expenses Recorded', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            const Text('Record group groceries, travel, or maintenance bills and split them evenly.',
                                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Paid by ${expense.paidByName} • Split among ${expense.participantUids.length} members',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: Text(
                                '₹${expense.amount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
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
  Widget _buildMembersTab(MagicCircle circle, MagicCircleMember? currentMember) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteMemberModal(context, circle),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Invite Member'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: circle.members.length,
        itemBuilder: (context, index) {
          final member = circle.members[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : 'M',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(member.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: member.role == CircleRole.owner ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  member.role.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: member.role == CircleRole.owner ? Colors.purple.shade700 : Colors.blue.shade700,
                  ),
                ),
              ),
            ),
          );
        },
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
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Responsibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title *',
                  hintText: 'e.g. Pay electricity bill, Buy milk',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MagicCircleMember>(
                decoration: InputDecoration(
                  labelText: 'Assign to Member',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: circle.members
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName)))
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
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setModalState(() => dueDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                    await ref.read(magicCircleRepositoryProvider).saveCircleTask(task);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Assign Task', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDiaryModal(BuildContext context, MagicCircle circle) {
    var selectedDiary = DiaryRegistry.predefinedDiaries.first;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Diary to Circle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 14),
              DropdownButtonFormField<DiaryDefinition>(
                initialValue: selectedDiary,
                decoration: InputDecoration(
                  labelText: 'Select Predefined Diary',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: DiaryRegistry.predefinedDiaries
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedDiary = val);
                },
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
                    if (!circle.sharedDiaryIds.contains(selectedDiary.id)) {
                      final updatedIds = [...circle.sharedDiaryIds, selectedDiary.id];
                      final updatedCircle = MagicCircle(
                        id: circle.id,
                        name: circle.name,
                        description: circle.description,
                        category: circle.category,
                        ownerId: circle.ownerId,
                        members: circle.members,
                        sharedDiaryIds: updatedIds,
                        createdAt: circle.createdAt,
                        updatedAt: DateTime.now(),
                      );
                      await ref.read(magicCircleRepositoryProvider).updateCircle(updatedCircle);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Add to Circle', style: TextStyle(fontWeight: FontWeight.bold)),
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
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Group Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Expense Description *',
                  hintText: 'e.g. Weekly Groceries, Fuel, Hotel Booking',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MagicCircleMember>(
                initialValue: paidByMember,
                decoration: InputDecoration(
                  labelText: 'Paid By',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: circle.members
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName)))
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (title.isEmpty || amount <= 0 || paidByMember == null) return;

                    final participants = circle.members.map((m) => m.uid).toList();
                    final splitPerPerson = amount / (participants.isEmpty ? 1 : participants.length);
                    final matrix = {for (final uid in participants) uid: splitPerPerson};

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

                    await ref.read(magicCircleRepositoryProvider).saveCircleExpense(expense);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteMemberModal(BuildContext context, MagicCircle circle) {
    final emailController = TextEditingController();
    var selectedRole = CircleRole.contributor;

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
              const Text('Invite Member to Circle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Member Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CircleRole>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: CircleRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedRole = val);
                },
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
                    if (email.isEmpty || !email.contains('@')) return;

                    final newMember = MagicCircleMember(
                      uid: 'pending_$email',
                      email: email,
                      displayName: email.split('@').first,
                      role: selectedRole,
                      joinedAt: DateTime.now(),
                      status: 'invited',
                    );

                    final updatedCircle = MagicCircle(
                      id: circle.id,
                      name: circle.name,
                      description: circle.description,
                      category: circle.category,
                      ownerId: circle.ownerId,
                      members: [...circle.members, newMember],
                      sharedDiaryIds: circle.sharedDiaryIds,
                      createdAt: circle.createdAt,
                      updatedAt: DateTime.now(),
                    );

                    await ref.read(magicCircleRepositoryProvider).updateCircle(updatedCircle);
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
