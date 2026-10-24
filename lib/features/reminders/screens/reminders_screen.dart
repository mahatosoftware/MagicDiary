import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/date_calculators.dart';
import '../models/reminder.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  void _showDeferDialog(BuildContext context, WidgetRef ref, Reminder reminder) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(reminderRepositoryProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Snooze / Defer "${reminder.title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose deferral duration:'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.today, color: Colors.blue),
              title: const Text('Defer +1 Day'),
              onTap: () async {
                Navigator.pop(context);
                await repo.deferReminder(user.uid, reminder.id, DeferOption.plus1Day);
                ref.invalidate(remindersProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.purple),
              title: const Text('Defer +1 Week'),
              onTap: () async {
                Navigator.pop(context);
                await repo.deferReminder(user.uid, reminder.id, DeferOption.plus1Week);
                ref.invalidate(remindersProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.orange),
              title: const Text('Defer +1 Month'),
              onTap: () async {
                Navigator.pop(context);
                await repo.deferReminder(user.uid, reminder.id, DeferOption.plus1Month);
                ref.invalidate(remindersProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar, color: Colors.teal),
              title: const Text('Custom Days (+3 days)'),
              onTap: () async {
                Navigator.pop(context);
                await repo.deferReminder(user.uid, reminder.id, DeferOption.customDays, customDays: 3);
                ref.invalidate(remindersProvider);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Shared Reminders System'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming & Active Notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            remindersAsync.when(
              data: (reminders) {
                if (reminders.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No active reminders scheduled.'),
                    ),
                  );
                }

                return Column(
                  children: reminders.map((r) {
                    final isCompleted = r.status == 'completed';
                    final isSnoozed = r.status == 'snoozed';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isCompleted ? Colors.grey.shade100 : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: r.module == 'Warranty'
                              ? Colors.blue.shade100
                              : r.module == 'SchoolFees'
                                  ? Colors.purple.shade100
                                  : Colors.orange.shade100,
                          child: Icon(
                            r.module == 'Warranty'
                                ? Icons.verified
                                : r.module == 'SchoolFees'
                                    ? Icons.school
                                    : Icons.receipt_long,
                            color: Colors.black87,
                          ),
                        ),
                        title: Text(
                          r.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.description),
                            Text('Due: ${AppFormatters.date(r.dueDate)}',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            if (isSnoozed && r.snoozedUntil != null)
                              Text('Snoozed until: ${AppFormatters.date(r.snoozedUntil!)}',
                                  style: const TextStyle(color: Colors.orange, fontSize: 12)),
                          ],
                        ),
                        trailing: isCompleted
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.snooze, color: Colors.orange),
                                    tooltip: 'Defer / Snooze',
                                    onPressed: () => _showDeferDialog(context, ref, r),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.done_all, color: Colors.green),
                                    tooltip: 'Mark Completed',
                                    onPressed: () async {
                                      final user = ref.read(userProfileProvider);
                                      if (user == null) return;
                                      final repo = ref.read(reminderRepositoryProvider);
                                      await repo.completeReminder(user.uid, r.id);
                                      ref.invalidate(remindersProvider);
                                    },
                                  ),
                                ],
                              ),
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
    );
  }
}
