import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';

class MyDayScreen extends ConsumerWidget {
  const MyDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider);
    final remindersAsync = ref.watch(remindersProvider);

    final todayStr = AppFormatters.date(DateTime.now());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(billsProvider);
          ref.invalidate(feeInstallmentsProvider);
          ref.invalidate(remindersProvider);
          ref.invalidate(journalEntriesProvider);
          ref.invalidate(vehiclesProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Header
              Card(
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Day ☀️',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              todayStr,
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Here is your agenda, upcoming payments, and active reminders for today.',
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Journal Today'),
                            onPressed: () => context.go('/personal'),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.payment),
                            label: const Text('Pay Bill'),
                            onPressed: () => context.go('/payments'),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.auto_stories),
                            label: const Text('All Diaries'),
                            onPressed: () => context.go('/diaries'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 1. Upcoming Payments & Activities
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Upcoming Payments & Due Bills',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/payments'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              billsAsync.when(
                data: (bills) {
                  final unpaid = bills.where((b) => b.status == 'unpaid').toList();
                  if (unpaid.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No pending payments for today! 🎉'),
                      ),
                    );
                  }
                  return Column(
                    children: unpaid.map((b) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orangeAccent,
                            child: Icon(Icons.payment, color: Colors.white),
                          ),
                          title: Text('Bill (${b.billPeriod})', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Due: ${AppFormatters.date(b.dueDate)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppFormatters.currency(b.amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const StatusBadge(status: 'unpaid'),
                            ],
                          ),
                          onTap: () => context.go('/payments'),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),

              const SizedBox(height: 24),

              // 2. Active Reminders Today
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Active Reminders & Alerts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/reminders'),
                    child: const Text('Reminders'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              remindersAsync.when(
                data: (reminders) {
                  final active = reminders.where((r) => r.status != 'completed').toList();
                  if (active.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No active reminders right now.'),
                      ),
                    );
                  }
                  return Column(
                    children: active.map((r) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: const Icon(Icons.alarm, color: Colors.teal),
                          ),
                          title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(r.description.isEmpty ? 'Due: ${AppFormatters.date(r.dueDate)}' : r.description),
                          onTap: () => context.go('/reminders'),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
