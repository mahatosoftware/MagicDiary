import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/notifications/models/notification_enums.dart';
import '../../../core/notifications/models/notification_schedule.dart';
import '../../../core/notifications/services/notification_defer_manager.dart';
import '../../../core/notifications/services/notification_manager.dart';

class DeferBottomSheet extends StatefulWidget {
  final NotificationSchedule schedule;
  final String userId;
  final Future<void> Function(DateTime newDate)? onRescheduleEventCallback;

  const DeferBottomSheet({
    super.key,
    required this.schedule,
    required this.userId,
    this.onRescheduleEventCallback,
  });

  static Future<bool?> show(
    BuildContext context, {
    required NotificationSchedule schedule,
    required String userId,
    Future<void> Function(DateTime newDate)? onRescheduleEventCallback,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DeferBottomSheet(
        schedule: schedule,
        userId: userId,
        onRescheduleEventCallback: onRescheduleEventCallback,
      ),
    );
  }

  @override
  State<DeferBottomSheet> createState() => _DeferBottomSheetState();
}

class _DeferBottomSheetState extends State<DeferBottomSheet> {
  DeferMode _selectedMode = DeferMode.notificationOnly;
  DeferPreset _selectedPreset = DeferPreset.tomorrow;
  DateTime? _customDateTime;
  final TextEditingController _reasonController = TextEditingController();
  bool _updateRecurringSeries = false;

  bool _isSubmitting = false;
  String? _errorMessage;
  DeferImpactReport? _impactReport;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _recalculateImpact();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime _calculateCurrentTargetDate() {
    final payload = widget.schedule.payload;
    final dueDateStr = payload['dueDate'] as String?;
    final baseDate = dueDateStr != null
        ? (DateTime.tryParse(dueDateStr) ?? widget.schedule.originalScheduledAt)
        : widget.schedule.originalScheduledAt;

    final manager = NotificationManager();
    return manager.deferManager.calculateDeferredDate(
      baseDate: baseDate,
      preset: _selectedPreset,
      customDateTime: _customDateTime,
    );
  }

  Future<void> _recalculateImpact() async {
    final payload = widget.schedule.payload;
    final dueDateStr = payload['dueDate'] as String?;
    final originalDate = dueDateStr != null
        ? (DateTime.tryParse(dueDateStr) ?? widget.schedule.originalScheduledAt)
        : widget.schedule.originalScheduledAt;

    final newTarget = _calculateCurrentTargetDate();
    final manager = NotificationManager();

    final impact = await manager.deferManager.generateImpactReport(
      userId: widget.userId,
      recordId: widget.schedule.recordId,
      originalDate: originalDate,
      newDate: newTarget,
      mode: _selectedMode,
      updateRecurringSeries: _updateRecurringSeries,
    );

    if (mounted) {
      setState(() {
        _impactReport = impact;
      });
    }
  }

  Future<void> _pickCustomDateTime() async {
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

    setState(() {
      _selectedPreset = DeferPreset.custom;
      _customDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
    await _recalculateImpact();
  }

  Future<void> _submitDefer() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final payload = widget.schedule.payload;
    final title = payload['title'] as String? ?? 'Reminder';
    final dueDateStr = payload['dueDate'] as String?;
    final originalDueDate = dueDateStr != null
        ? (DateTime.tryParse(dueDateStr) ?? widget.schedule.originalScheduledAt)
        : widget.schedule.originalScheduledAt;

    final newTarget = _calculateCurrentTargetDate();
    final manager = NotificationManager();

    if (_selectedMode == DeferMode.notificationOnly) {
      // Mode A
      final res = await manager.deferNotificationOnly(
        userId: widget.userId,
        recordId: widget.schedule.recordId,
        moduleId: widget.schedule.moduleId,
        categoryId: widget.schedule.categoryId,
        eventType: widget.schedule.eventType,
        originalDueDate: originalDueDate,
        newNotificationDate: newTarget,
        title: title,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
        occurrenceId: widget.schedule.occurrenceId,
      );

      if (!mounted) return;
      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deferred. Original commitment date kept intact.'),
            backgroundColor: Colors.indigo,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = res.errorMessage ?? 'Failed to defer notification.';
        });
      }
    } else {
      // Mode B
      final res = await manager.deferUnderlyingEvent(
        userId: widget.userId,
        recordId: widget.schedule.recordId,
        moduleId: widget.schedule.moduleId,
        categoryId: widget.schedule.categoryId,
        eventType: widget.schedule.eventType,
        originalDueDate: originalDueDate,
        newEventDueDate: newTarget,
        title: title,
        updateRecurringSeries: _updateRecurringSeries,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
        occurrenceId: widget.schedule.occurrenceId,
        rescheduleCallback: (newDate) async {
          if (widget.onRescheduleEventCallback != null) {
            await widget.onRescheduleEventCallback!(newDate);
          }
        },
      );

      if (!mounted) return;
      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commitment rescheduled and all notification alarms updated.'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = res.errorMessage ?? 'Failed to reschedule event date.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.schedule.payload['title'] as String? ?? 'Reminder';

    return SingleChildScrollView(
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
                backgroundColor: Colors.indigo,
                radius: 18,
                child: Icon(Icons.update_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Defer & Reschedule',
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
            ],
          ),

          const SizedBox(height: 14),

          // Mode Selection: Segmented Control
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedMode = DeferMode.notificationOnly);
                      _recalculateImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedMode == DeferMode.notificationOnly
                            ? theme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Defer Notification\n(Keep Due Date)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedMode == DeferMode.notificationOnly
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedMode = DeferMode.underlyingEvent);
                      _recalculateImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedMode == DeferMode.underlyingEvent
                            ? theme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Reschedule Event\n(Update Due Date)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedMode == DeferMode.underlyingEvent
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Preset Selection Chips
          const Text('Choose Reschedule Window:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip(DeferPreset.laterToday, 'Later today'),
              _buildPresetChip(DeferPreset.tomorrow, 'Tomorrow'),
              _buildPresetChip(DeferPreset.nextWorkingDay, 'Next working day'),
              _buildPresetChip(DeferPreset.in2Days, 'In 2 days'),
              _buildPresetChip(DeferPreset.in3Days, 'In 3 days'),
              _buildPresetChip(DeferPreset.nextWeek, 'Next week'),
              _buildPresetChip(DeferPreset.nextMonth, 'Next month'),
              ActionChip(
                avatar: const Icon(Icons.edit_calendar, size: 16),
                label: Text(
                  _customDateTime != null
                      ? DateFormat('dd MMM').format(_customDateTime!)
                      : 'Custom date...',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _selectedPreset == DeferPreset.custom
                    ? theme.primaryColor.withValues(alpha: 0.2)
                    : null,
                onPressed: _pickCustomDateTime,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Impact Report Confirmation Summary Card
          if (_impactReport != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _impactReport!.isPotentiallyOverdueWarning
                    ? Colors.red.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _impactReport!.isPotentiallyOverdueWarning
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Summary & Confirmation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Original Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_dateFormat.format(_impactReport!.originalDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New Target Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _dateFormat.format(_impactReport!.newDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _impactReport!.isPotentiallyOverdueWarning ? Colors.red : Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Days Deferred:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('+${_impactReport!.daysDeferred} days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Linked Financial Record:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _selectedMode == DeferMode.underlyingEvent ? 'Will be updated' : 'Unchanged',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedMode == DeferMode.underlyingEvent ? Colors.teal : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (_impactReport!.warningMessage != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _impactReport!.warningMessage!,
                            style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          if (_selectedMode == DeferMode.underlyingEvent) ...[
            const SizedBox(height: 10),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Apply date change to future recurring occurrences?',
                style: TextStyle(fontSize: 12),
              ),
              value: _updateRecurringSeries,
              onChanged: (val) {
                setState(() => _updateRecurringSeries = val ?? false);
                _recalculateImpact();
              },
            ),
          ],

          const SizedBox(height: 10),

          // Reason text field
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason for deferral (Optional)',
              hintText: 'e.g. Waiting for salary credit, bill dispute',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],

          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMode == DeferMode.underlyingEvent ? Colors.deepOrange : Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isSubmitting ? null : _submitDefer,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _selectedMode == DeferMode.underlyingEvent
                          ? 'Confirm & Reschedule Event Date'
                          : 'Defer Notification Only',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(DeferPreset preset, String label) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPreset = preset;
            _customDateTime = null;
          });
          _recalculateImpact();
        }
      },
    );
  }
}
