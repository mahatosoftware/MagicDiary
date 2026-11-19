import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/date_calculators.dart';
import '../../../core/utils/formatters.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/services/reminder_action_resolver.dart';
import '../../reminders/widgets/completion_details_dialog.dart';
import '../../reminders/widgets/payment_confirmation_dialog.dart';

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
      case 'finance':
        return Icons.account_balance_wallet;
      case 'personal':
        return Icons.event;
      default:
        return Icons.task_alt;
    }
  }

  Future<void> _handleCompleteAction(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(reminderRepositoryProvider);
    final resolvedAction = ReminderActionResolver.resolve(reminder);

    if (resolvedAction == ReminderActionType.markPaid) {
      // Open Payment Confirmation Dialog for Financial Reminders
      await PaymentConfirmationDialog.show(
        context,
        reminder: reminder,
        onConfirm: (details) async {
          await repo.markAsPaid(
            userId: user.uid,
            reminderId: reminder.id,
            paymentDetails: details,
          );

          // If linked to finance transaction, sync it
          final txId = reminder.effectiveLinkedRecordId;
          if (txId.isNotEmpty &&
              (reminder.module.toLowerCase() == 'finance' || reminder.id.startsWith('reminder_tx_'))) {
            try {
              await ref.read(financeRepositoryProvider).markTransactionAsPaid(
                user.uid,
                txId,
                paidAt: details.paidAt,
                paymentMethod: details.paymentMethod,
              );
              ref.invalidate(financialTransactionsProvider);
            } catch (_) {}
          }

          ref.invalidate(remindersProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Marked as paid: "${reminder.title}" (₹${details.amount.toStringAsFixed(0)})'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green.shade800,
              ),
            );
          }
        },
      );
    } else {
      // Open Completion Details Dialog for Non-Financial Reminders
      await CompletionDetailsDialog.show(
        context,
        reminder: reminder,
        actionType: resolvedAction,
        onConfirm: (details) async {
          await repo.markAsComplete(
            userId: user.uid,
            reminderId: reminder.id,
            completionDetails: details,
            actionType: resolvedAction,
          );
          ref.invalidate(remindersProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${resolvedAction.pastTenseLabel}: "${reminder.title}"'),
                duration: const Duration(seconds: 2),
                backgroundColor: resolvedAction.color,
              ),
            );
          }
        },
      );
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
    final resolvedAction = ReminderActionResolver.resolve(reminder);

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
                      if (val == 'resolve_action') {
                        await _handleCompleteAction(context, ref);
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
                      PopupMenuItem(
                        value: 'resolve_action',
                        child: Row(
                          children: [
                            Icon(resolvedAction.icon, color: resolvedAction.color, size: 18),
                            const SizedBox(width: 8),
                            Text(resolvedAction.label),
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? Colors.grey : null,
                        ),
                      ),
                      if (reminder.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCompleted ? Colors.grey : Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Date & Amount Meta Row
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: isOverdue ? Colors.red : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  AppFormatters.date(reminder.dueDate),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? Colors.red.shade700 : Colors.grey.shade800,
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
                if (reminder.repeatSchedule != null &&
                    reminder.repeatSchedule!.isNotEmpty &&
                    reminder.repeatSchedule != 'one_time')
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 2),
                          Text(
                            reminder.repeatSchedule!.replaceAll('_', ' '),
                            style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
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
                  _buildActionButton(context, ref, resolvedAction),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, ReminderActionType resolvedAction) {
    final route = (reminder.actionRoute != null && reminder.actionRoute!.isNotEmpty)
        ? reminder.actionRoute!
        : '/';

    if (resolvedAction == ReminderActionType.markPaid) {
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
            onPressed: () => _handleCompleteAction(context, ref),
          ),
        ],
      );
    }

    // Non-financial action button (Complete, Resolved, Acknowledged)
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
            label: const Text('Open in Diary'),
            onPressed: () => context.push(route),
          ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: resolvedAction.color,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          icon: Icon(resolvedAction.icon, size: 16),
          label: Text(resolvedAction.label),
          onPressed: () => _handleCompleteAction(context, ref),
        ),
      ],
    );
  }
}
