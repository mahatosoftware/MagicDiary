import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/notifications/models/notification_schedule.dart';
import '../../../core/notifications/services/notification_manager.dart';

class MarkPaidConfirmationDialog extends StatefulWidget {
  final NotificationSchedule schedule;
  final String userId;
  final Future<void> Function()? onRecordPaidCallback;

  const MarkPaidConfirmationDialog({
    super.key,
    required this.schedule,
    required this.userId,
    this.onRecordPaidCallback,
  });

  static Future<bool?> show(
    BuildContext context, {
    required NotificationSchedule schedule,
    required String userId,
    Future<void> Function()? onRecordPaidCallback,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => MarkPaidConfirmationDialog(
        schedule: schedule,
        userId: userId,
        onRecordPaidCallback: onRecordPaidCallback,
      ),
    );
  }

  @override
  State<MarkPaidConfirmationDialog> createState() => _MarkPaidConfirmationDialogState();
}

class _MarkPaidConfirmationDialogState extends State<MarkPaidConfirmationDialog> {
  bool _isSubmitting = false;

  Future<void> _handleConfirm() async {
    setState(() => _isSubmitting = true);

    try {
      final manager = NotificationManager();
      // 1. Cancel all future reminders and overdue alerts for this record
      await manager.onRecordPaidOrCompleted(
        userId: widget.userId,
        recordId: widget.schedule.recordId,
        moduleId: widget.schedule.moduleId,
      );

      // 2. Call module payment handler if provided
      if (widget.onRecordPaidCallback != null) {
        await widget.onRecordPaidCallback!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded. Active reminders cancelled.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.schedule.payload;
    final title = payload['title'] as String? ?? 'Commitment';
    final amount = (payload['amount'] as num?)?.toDouble();
    final dueDateStr = payload['dueDate'] as String?;
    final dueDate = dueDateStr != null
        ? DateTime.tryParse(dueDateStr)
        : widget.schedule.originalScheduledAt;

    final dateFormat = DateFormat('dd MMM yyyy');

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green),
          SizedBox(width: 8),
          Text('Confirm Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you sure you want to mark this commitment as Paid?',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                if (amount != null)
                  Text(
                    'Amount: ₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14),
                  ),
                if (dueDate != null)
                  Text(
                    'Due Date: ${dateFormat.format(dueDate)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This will cancel all future advance reminders and overdue alerts for this record.',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _handleConfirm,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Confirm & Mark Paid'),
        ),
      ],
    );
  }
}
