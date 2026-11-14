import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/notifications/models/notification_enums.dart';
import '../../../core/notifications/models/notification_schedule.dart';

class NotificationCard extends StatelessWidget {
  final NotificationSchedule schedule;
  final VoidCallback? onOpen;
  final VoidCallback? onSnooze;
  final VoidCallback? onDefer;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onMarkComplete;
  final VoidCallback? onDismiss;

  const NotificationCard({
    super.key,
    required this.schedule,
    this.onOpen,
    this.onSnooze,
    this.onDefer,
    this.onMarkPaid,
    this.onMarkComplete,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = schedule.payload;
    final title = payload['title'] as String? ?? 'Reminder';
    final body = payload['body'] as String? ?? '';
    final amount = (payload['amount'] as num?)?.toDouble();
    final currency = payload['currency'] as String? ?? 'INR';
    final dueDateStr = payload['dueDate'] as String?;
    final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : schedule.originalScheduledAt;

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final dateOnlyFormat = DateFormat('dd MMM yyyy');

    final (statusColor, statusLabel) = _resolveStatusDetails();
    final isFinancial = schedule.moduleId == 'bills' ||
        schedule.moduleId == 'finance' ||
        schedule.moduleId == 'school_fees';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Module icon, Title, Status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _getModuleColor(schedule.moduleId).withValues(alpha: 0.15),
                  child: Icon(
                    _getModuleIcon(schedule.moduleId),
                    color: _getModuleColor(schedule.moduleId),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getModuleName(schedule.moduleId),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Body text
            if (body.isNotEmpty)
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
              ),

            const SizedBox(height: 10),

            // Metadata row: Amount (if financial) & Dates
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (amount != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Amount', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          '$currency ${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original Due Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        dueDate != null ? dateOnlyFormat.format(dueDate) : '—',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Next Reminder', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        dateFormat.format(schedule.scheduledAt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: schedule.scheduledAt.isBefore(DateTime.now())
                              ? Colors.red
                              : Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (isFinancial && onMarkPaid != null && schedule.isActive)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: onMarkPaid,
                  ),
                if (!isFinancial && onMarkComplete != null && schedule.isActive)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: onMarkComplete,
                  ),
                if (onSnooze != null && schedule.isActive)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.snooze_rounded, size: 16),
                    label: const Text('Snooze'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: onSnooze,
                  ),
                if (onDefer != null && schedule.isActive)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.update_rounded, size: 16),
                    label: const Text('Defer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: onDefer,
                  ),
                if (onOpen != null)
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open Record'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: onOpen,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, String) _resolveStatusDetails() {
    final now = DateTime.now();
    if (schedule.status == NotificationScheduleStatus.completed) {
      return (Colors.green, 'Completed');
    }
    if (schedule.isSnoozed) {
      return (Colors.orange, 'Snoozed (${schedule.snoozeCount})');
    }
    if (schedule.isDeferred) {
      return (Colors.indigo, 'Deferred');
    }
    if (schedule.isOverdueAlert || schedule.originalScheduledAt.isBefore(now)) {
      final days = now.difference(schedule.originalScheduledAt).inDays;
      return (Colors.red, days > 0 ? 'Overdue ($days d)' : 'Due Today');
    }
    return (Colors.blue, 'Upcoming');
  }

  IconData _getModuleIcon(String moduleId) {
    switch (moduleId.toLowerCase().trim()) {
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      case 'vehicle':
        return Icons.directions_car_rounded;
      case 'warranty':
        return Icons.verified_rounded;
      case 'school_fees':
      case 'schoolfees':
        return Icons.school_rounded;
      case 'household':
        return Icons.home_work_rounded;
      case 'domestic_help':
      case 'domestichelp':
        return Icons.clean_hands_rounded;
      case 'property':
        return Icons.apartment_rounded;
      case 'personal':
      default:
        return Icons.event_note_rounded;
    }
  }

  Color _getModuleColor(String moduleId) {
    switch (moduleId.toLowerCase().trim()) {
      case 'bills':
        return Colors.orange;
      case 'finance':
        return Colors.green;
      case 'vehicle':
        return Colors.red;
      case 'warranty':
        return Colors.blue;
      case 'school_fees':
      case 'schoolfees':
        return Colors.deepOrange;
      case 'household':
        return Colors.teal;
      case 'domestic_help':
      case 'domestichelp':
        return Colors.cyan;
      case 'property':
        return Colors.indigo;
      case 'personal':
      default:
        return Colors.purple;
    }
  }

  String _getModuleName(String moduleId) {
    switch (moduleId.toLowerCase().trim()) {
      case 'bills':
        return 'Bills & Subscriptions';
      case 'finance':
        return 'Financial Diary';
      case 'vehicle':
        return 'Vehicle Diary';
      case 'warranty':
        return 'Warranty Diary';
      case 'school_fees':
      case 'schoolfees':
        return 'Education Diary';
      case 'household':
        return 'Household Diary';
      case 'domestic_help':
      case 'domestichelp':
        return 'Domestic Help';
      case 'property':
        return 'Property Diary';
      case 'personal':
        return 'Personal Diary';
      default:
        return 'General Diary';
    }
  }
}
