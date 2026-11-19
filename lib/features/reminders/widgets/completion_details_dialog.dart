import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/reminder_action_resolver.dart';

/// Optional details captured when resolving a non-financial reminder.
class ReminderCompletionDetails {
  final DateTime completedDate;
  final String? notes;
  final String? serviceProvider;
  final double? actualCost;

  const ReminderCompletionDetails({
    required this.completedDate,
    this.notes,
    this.serviceProvider,
    this.actualCost,
  });
}

/// Modal dialog for confirming and optionally annotating completion of non-financial reminders.
class CompletionDetailsDialog extends StatefulWidget {
  final Reminder reminder;
  final ReminderActionType actionType;
  final Future<void> Function(ReminderCompletionDetails details) onConfirm;

  const CompletionDetailsDialog({
    super.key,
    required this.reminder,
    required this.actionType,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Reminder reminder,
    required ReminderActionType actionType,
    required Future<void> Function(ReminderCompletionDetails details) onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompletionDetailsDialog(
        reminder: reminder,
        actionType: actionType,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<CompletionDetailsDialog> createState() => _CompletionDetailsDialogState();
}

class _CompletionDetailsDialogState extends State<CompletionDetailsDialog> {
  late final TextEditingController _notesController;
  late final TextEditingController _providerController;
  late final TextEditingController _costController;

  late DateTime _selectedDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _providerController = TextEditingController();
    _costController = TextEditingController();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _providerController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final parsedCost = double.tryParse(_costController.text.trim());
      final details = ReminderCompletionDetails(
        completedDate: _selectedDate,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        serviceProvider: _providerController.text.trim().isNotEmpty ? _providerController.text.trim() : null,
        actualCost: parsedCost,
      );

      await widget.onConfirm(details);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionColor = widget.actionType.color;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.actionType.icon, color: actionColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.actionType.label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.reminder.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            // Completion Date Selector
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date of Activity / Action',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Service Provider / Person Responsible (Optional)
            TextFormField(
              controller: _providerController,
              decoration: InputDecoration(
                labelText: 'Service Provider / Person (Optional)',
                hintText: 'e.g. Authorized Service Center / Dr. Sharma',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),

            // Actual Cost (Optional)
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Actual Cost Incurred (Optional)',
                prefixText: '₹ ',
                hintText: '0 if no cost',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),

            // Notes / Comments (Optional)
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Completion Notes (Optional)',
                hintText: 'Details of service, remarks, or observations',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: actionColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : _handleConfirm,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(widget.actionType.icon, size: 18),
          label: Text(_isSubmitting ? 'Processing...' : widget.actionType.label),
        ),
      ],
    );
  }
}
