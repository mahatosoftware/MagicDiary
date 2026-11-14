import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/notifications/models/notification_schedule.dart';
import '../../../core/notifications/providers/notification_providers.dart';
import '../../../core/notifications/services/notification_manager.dart';
import '../../../core/providers/app_providers.dart';
import '../widgets/defer_bottom_sheet.dart';
import '../widgets/mark_paid_confirmation_dialog.dart';
import '../widgets/notification_card.dart';
import '../widgets/snooze_bottom_sheet.dart';

class NotificationCentreScreen extends ConsumerStatefulWidget {
  const NotificationCentreScreen({super.key});

  @override
  ConsumerState<NotificationCentreScreen> createState() => _NotificationCentreScreenState();
}

class _NotificationCentreScreenState extends ConsumerState<NotificationCentreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedModuleFilter = 'all';
  String _searchQuery = '';

  final List<String> _tabs = [
    'Today',
    'Upcoming',
    'Overdue',
    'Snoozed',
    'Deferred',
    'Completed',
    'History',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<NotificationSchedule> _filterList(List<NotificationSchedule> list) {
    return list.where((s) {
      if (_selectedModuleFilter != 'all' && s.moduleId.toLowerCase() != _selectedModuleFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final title = (s.payload['title'] as String? ?? '').toLowerCase();
        final body = (s.payload['body'] as String? ?? '').toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!title.contains(q) && !body.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider);
    final userId = user?.uid ?? '';
    final categorizedAsync = ref.watch(categorizedNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Centre', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification Settings',
            onPressed: () => context.push('/notification-settings'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Notifications',
            onPressed: () => ref.invalidate(categorizedNotificationsProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.primaryColor,
            tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search alerts, bills, warranties...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list_rounded),
                  tooltip: 'Filter by Module',
                  initialValue: _selectedModuleFilter,
                  onSelected: (val) {
                    setState(() => _selectedModuleFilter = val);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'all', child: Text('All Modules')),
                    const PopupMenuItem(value: 'bills', child: Text('Bills & Utilities')),
                    const PopupMenuItem(value: 'finance', child: Text('Finance & EMIs')),
                    const PopupMenuItem(value: 'school_fees', child: Text('School Fees')),
                    const PopupMenuItem(value: 'vehicle', child: Text('Vehicle & Service')),
                    const PopupMenuItem(value: 'warranty', child: Text('Warranty')),
                    const PopupMenuItem(value: 'household', child: Text('Household & Rent')),
                    const PopupMenuItem(value: 'domestic_help', child: Text('Domestic Help')),
                    const PopupMenuItem(value: 'property', child: Text('Property & Taxes')),
                    const PopupMenuItem(value: 'personal', child: Text('Personal')),
                  ],
                ),
              ],
            ),
          ),

          // Active Module Filter Pill if not 'all'
          if (_selectedModuleFilter != 'all')
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
              child: Row(
                children: [
                  Chip(
                    label: Text('Module: ${_selectedModuleFilter.toUpperCase()}'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _selectedModuleFilter = 'all'),
                  ),
                ],
              ),
            ),

          // Tab Views
          Expanded(
            child: categorizedAsync.when(
              data: (map) {
                final todayList = _filterList(map['today'] ?? []);
                final upcomingList = _filterList(map['upcoming'] ?? []);
                final overdueList = _filterList(map['overdue'] ?? []);
                final snoozedList = _filterList(map['snoozed'] ?? []);
                final deferredList = _filterList(map['deferred'] ?? []);
                final completedList = _filterList(map['completed'] ?? []);

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScheduleList(todayList, userId, 'No notifications due today!'),
                    _buildScheduleList(upcomingList, userId, 'No upcoming notifications.'),
                    _buildScheduleList(overdueList, userId, 'Great! You have no overdue commitments.'),
                    _buildScheduleList(snoozedList, userId, 'No snoozed reminders.'),
                    _buildScheduleList(deferredList, userId, 'No deferred notifications.'),
                    _buildScheduleList(completedList, userId, 'No completed records yet.'),
                    _buildHistoryTab(userId),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(
    List<NotificationSchedule> list,
    String userId,
    String emptyMessage,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final schedule = list[idx];
        return NotificationCard(
          schedule: schedule,
          onOpen: () {
            final route = schedule.payload['actionRoute'] as String? ?? '/reminders';
            context.push(route);
          },
          onSnooze: () async {
            final res = await SnoozeBottomSheet.show(context, schedule: schedule, userId: userId);
            if (res == true) {
              ref.invalidate(categorizedNotificationsProvider);
            }
          },
          onDefer: () async {
            final res = await DeferBottomSheet.show(context, schedule: schedule, userId: userId);
            if (res == true) {
              ref.invalidate(categorizedNotificationsProvider);
            }
          },
          onMarkPaid: () async {
            final res = await MarkPaidConfirmationDialog.show(context, schedule: schedule, userId: userId);
            if (res == true) {
              ref.invalidate(categorizedNotificationsProvider);
            }
          },
          onMarkComplete: () async {
            final manager = NotificationManager();
            await manager.onRecordPaidOrCompleted(userId: userId, recordId: schedule.recordId);
            ref.invalidate(categorizedNotificationsProvider);
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(String userId) {
    return FutureBuilder(
      future: NotificationManager().historyManager.getAuditHistory(userId),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(
            child: Text('No historical notification audits recorded yet.', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (ctx, idx) => const Divider(height: 1),
          itemBuilder: (ctx, idx) {
            final item = list[idx];
            return ListTile(
              leading: const Icon(Icons.history_rounded, color: Colors.blueGrey),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                'Status: ${item.status.name} • ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: item.actionTaken != null
                  ? Chip(label: Text(item.actionTaken!, style: const TextStyle(fontSize: 10)))
                  : null,
            );
          },
        );
      },
    );
  }
}
