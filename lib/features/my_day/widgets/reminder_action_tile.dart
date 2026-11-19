import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/date_calculators.dart';
import '../../../core/utils/formatters.dart';
import '../../reminders/models/reminder.dart';

class ReminderActionTile extends ConsumerWidget {
  final Reminder reminder;

  const ReminderActionTile({
    super.key,
    required this.reminder,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.amber.shade700;
      case 'low':
      default:
        return Colors.green;
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module.toLowerCase()) {
      case 'bills':
        return Icons.receipt_long;
      case 'vehicle':
        return Icons.directions_car;
      case 'property':
        return Icons.apartment;
      case 'household':
        return Icons.home_repair_service;
      case 'schoolfees':
        return Icons.school;
      case 'warranty':
        return Icons.verified_user;
      case 'personal':
        return Icons.edit_note;
      default:
        return Icons.task_alt;
    }
  }

  Future<void> _handleComplete(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(reminderRepositoryProvider);

    try {
      await repo.completeReminder(user.uid, reminder.id);

      // If linked to a finance transaction, also mark that transaction as paid
      if (reminder.module.toLowerCase() == 'finance' || reminder.id.startsWith('reminder_tx_')) {
        final txId = reminder.relatedId ??
            (reminder.id.startsWith('reminder_tx_') ? reminder.id.substring('reminder_tx_'.length) : null);
        if (txId != null && txId.isNotEmpty) {
          try {
            await ref.read(financeRepositoryProvider).markTransactionAsPaid(user.uid, txId);
            ref.invalidate(financialTransactionsProvider);
          } catch (_) {}
        }
      }

      final isPayment = reminder.actionType.toLowerCase().trim() == 'pay' ||
          reminder.title.toLowerCase().contains('emi') ||
          reminder.title.toLowerCase().contains('loan') ||
          reminder.module.toLowerCase() == 'finance' ||
          reminder.module.toLowerCase() == 'bills';

      ref.invalidate(remindersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPayment
                ? 'Marked as paid: "${reminder.title}"'
                : 'Completed: "${reminder.title}"'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    }
  }

  Future<void> _handleSnooze(BuildContext context, WidgetRef ref, DeferOption option, {int customDays = 0}) async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(reminderRepositoryProvider);

    try {
      await repo.deferReminder(user.uid, reminder.id, option, customDays: customDays);
      ref.invalidate(remindersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder snoozed!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to snooze: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isOverdue = reminder.isOverdue(now);
    final isCompleted = reminder.isCompleted;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isOverdue
              ? Colors.red.shade200
              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Module pill, Priority indicator, and Snooze Menu
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getModuleIcon(reminder.module), size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        reminder.module,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(reminder.priority),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  reminder.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getPriorityColor(reminder.priority),
                  ),
                ),
                const Spacer(),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'OVERDUE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                    ),
                  ),
                if (!isCompleted)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Options',
                    onSelected: (val) async {
                      if (val == 'mark_paid') {
                        await _handleComplete(context, ref);
                      } else if (val == '1day') {
                        await _handleSnooze(context, ref, DeferOption.plus1Day);
                      } else if (val == '1week') {
                        await _handleSnooze(context, ref, DeferOption.plus1Week);
                      } else if (val == '1month') {
                        await _handleSnooze(context, ref, DeferOption.plus1Month);
                      } else if (val == 'custom') {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: reminder.dueDate.isBefore(now) ? now.add(const Duration(days: 1)) : reminder.dueDate,
                          firstDate: now,
                          lastDate: DateTime(2200),
                        );
                        if (picked != null) {
                          final days = picked.difference(DateTime(now.year, now.month, now.day)).inDays;
                          if (context.mounted) {
                            await _handleSnooze(context, ref, DeferOption.customDays, customDays: days);
                          }
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'mark_paid',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text('Mark as Paid / Done'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: '1day', child: Text('Snooze +1 Day')),
                      const PopupMenuItem(value: '1week', child: Text('Snooze +1 Week')),
                      const PopupMenuItem(value: '1month', child: Text('Snooze +1 Month')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'custom', child: Text('Pick Custom Date...')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Middle: Title and Description
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(
                    isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isCompleted ? Colors.green : Colors.grey,
                  ),
                  onPressed: () => _handleComplete(context, ref),
                  tooltip: isCompleted ? 'Completed' : 'Mark complete',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? Colors.grey : null,
                        ),
                      ),
                      if (reminder.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          reminder.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Due: ${AppFormatters.date(reminder.dueDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOverdue ? Colors.red.shade700 : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reminder.amount != null && reminder.amount! > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      AppFormatters.currency(reminder.amount!),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Bottom: Next Action Button
            if (!isCompleted)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(context, ref),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    final route = (reminder.actionRoute != null && reminder.actionRoute!.isNotEmpty)
        ? reminder.actionRoute!
        : '/';
    final actionType = reminder.actionType.toLowerCase().trim();
    final isPayment = actionType == 'pay' ||
        reminder.title.toLowerCase().contains('emi') ||
        reminder.title.toLowerCase().contains('loan') ||
        reminder.module.toLowerCase() == 'finance' ||
        reminder.module.toLowerCase() == 'bills';

    if (isPayment) {
      final hasExternalRoute = route != '/' && route.isNotEmpty;
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasExternalRoute)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(reminder.amount != null
                  ? 'Pay ₹${reminder.amount!.toStringAsFixed(0)}'
                  : 'Pay Online'),
              onPressed: () => context.push(route),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Mark as Paid'),
            onPressed: () => _handleComplete(context, ref),
          ),
        ],
      );
    }

    String label;
    IconData icon;
    Color buttonColor;
    VoidCallback onPressed;

    switch (actionType) {
      case 'renew':
        label = 'Renew Policy / Item';
        icon = Icons.refresh;
        buttonColor = Colors.blue.shade700;
        onPressed = () => context.push(route);
        break;
      case 'schedule service':
        label = 'Schedule Service';
        icon = Icons.build_circle_outlined;
        buttonColor = Colors.deepOrange;
        onPressed = () => context.push(route);
        break;
      case 'upload receipt':
        label = 'Upload Receipt';
        icon = Icons.upload_file;
        buttonColor = Colors.indigo;
        onPressed = () => context.push(route);
        break;
      case 'review':
        label = 'Review Details';
        icon = Icons.visibility_outlined;
        buttonColor = Colors.purple;
        onPressed = () => context.push(route);
        break;
      case 'celebrate':
        label = 'Open in Diary';
        icon = Icons.celebration_rounded;
        buttonColor = Colors.pink;
        onPressed = () => context.push(route);
        break;
      case 'complete':
      case 'done':
      default:
        label = 'Mark as Done';
        icon = Icons.done;
        buttonColor = Colors.teal;
        onPressed = () => _handleComplete(context, ref);
        break;
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
