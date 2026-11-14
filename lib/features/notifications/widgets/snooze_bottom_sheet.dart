import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/notifications/models/notification_enums.dart';
import '../../../core/notifications/models/notification_schedule.dart';
import '../../../core/notifications/services/notification_manager.dart';

class SnoozeBottomSheet extends StatefulWidget {
  final NotificationSchedule schedule;
  final String userId;

  const SnoozeBottomSheet({
    super.key,
    required this.schedule,
    required this.userId,
  });

  static Future<bool?> show(BuildContext context, {
    required NotificationSchedule schedule,
    required String userId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SnoozeBottomSheet(schedule: schedule, userId: userId),
    );
  }

  @override
  State<SnoozeBottomSheet> createState() => _SnoozeBottomSheetState();
}

class _SnoozeBottomSheetState extends State<SnoozeBottomSheet> {
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<(SnoozePreset, String, IconData)> _presets = [
    (SnoozePreset.tenMinutes, '10 minutes', Icons.timer_outlined),
    (SnoozePreset.thirtyMinutes, '30 minutes', Icons.access_time_outlined),
    (SnoozePreset.oneHour, '1 hour', Icons.hourglass_bottom_outlined),
    (SnoozePreset.threeHours, '3 hours', Icons.history_toggle_off_outlined),
    (SnoozePreset.tomorrowMorning, 'Tomorrow morning (09:00 AM)', Icons.wb_sunny_outlined),
    (SnoozePreset.nextWorkingDay, 'Next working day (Monday if weekend)', Icons.business_center_outlined),
    (SnoozePreset.custom, 'Select custom date & time...', Icons.calendar_month_outlined),
  ];

  Future<void> _handleSnooze(SnoozePreset preset) async {
    DateTime? customDateTime;
    if (preset == SnoozePreset.custom) {
      final now = DateTime.now();
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: DateTime(2200),
      );
      if (pickedDate == null) return;
      if (!mounted) return;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
      );
      if (pickedTime == null) return;

      customDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final payload = widget.schedule.payload;
    final title = payload['title'] as String? ?? 'Reminder';
    final body = payload['body'] as String? ?? '';
    final dueDateStr = payload['dueDate'] as String?;
    final originalDueDate = dueDateStr != null
        ? (DateTime.tryParse(dueDateStr) ?? widget.schedule.originalScheduledAt)
        : widget.schedule.originalScheduledAt;

    final manager = NotificationManager();
    final res = await manager.snoozeNotification(
      userId: widget.userId,
      recordId: widget.schedule.recordId,
      moduleId: widget.schedule.moduleId,
      categoryId: widget.schedule.categoryId,
      eventType: widget.schedule.eventType,
      originalDueDate: originalDueDate,
      title: title,
      originalBody: body,
      preset: preset,
      customDateTime: customDateTime,
      currentSnoozeCount: widget.schedule.snoozeCount,
      isAlreadyOverdue: widget.schedule.isOverdueAlert,
      occurrenceId: widget.schedule.occurrenceId,
    );

    if (!mounted) return;

    if (res.isSuccess) {
      final formatter = DateFormat('hh:mm a, dd MMM');
      final timeStr = res.snoozedUntil != null ? formatter.format(res.snoozedUntil!) : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder postponed until $timeStr'),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = res.errorMessage ?? 'Failed to snooze reminder.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.schedule.payload['title'] as String? ?? 'Reminder';
    final count = widget.schedule.snoozeCount;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.orangeAccent,
                radius: 18,
                child: Icon(Icons.snooze_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Snooze Reminder',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Snoozed $count time${count > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Informational Notice (Section 6 Rule 1)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Snoozing only postpones the alert. Your underlying financial due date remains unchanged.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],

          const SizedBox(height: 16),

          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            ..._presets.map((item) {
              final preset = item.$1;
              final label = item.$2;
              final icon = item.$3;
              return ListTile(
                dense: true,
                leading: Icon(icon, color: Colors.indigo, size: 20),
                title: Text(label, style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () => _handleSnooze(preset),
              );
            }),
        ],
      ),
    );
  }
}
