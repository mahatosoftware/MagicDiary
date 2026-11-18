import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../diary_registry/diary_registry.dart';
import '../models/diary_record.dart';
import '../models/custom_field_definition.dart';
import 'generic_diary_list_screen.dart';
import '../../providers/app_providers.dart';
import '../../../features/reminders/models/reminder.dart';
import '../../notifications/services/notification_manager.dart';

class GenericRecordFormScreen extends ConsumerStatefulWidget {
  final String diaryId;
  final DiaryRecord? initialRecord;
  final String? ownerId;

  const GenericRecordFormScreen({
    super.key,
    required this.diaryId,
    this.initialRecord,
    this.ownerId,
  });

  @override
  ConsumerState<GenericRecordFormScreen> createState() => _GenericRecordFormScreenState();
}

class _GenericRecordFormScreenState extends ConsumerState<GenericRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _amountController;
  late DateTime _recordDate;
  bool _isPrivate = false;
  final Map<String, dynamic> _fieldValues = {};
  final List<String> _restrictedFields = [];
  bool _isSaving = false;

  // Reminder Configuration
  bool _hasReminder = false;
  final Set<int> _selectedRemindBeforeDays = {};
  String _selectedRepeatSchedule = 'one_time';

  static const List<Map<String, dynamic>> _remindBeforeOptions = [
    {'days': 30, 'label': '30 Days'},
    {'days': 15, 'label': '15 Days'},
    {'days': 7, 'label': '7 Days'},
    {'days': 1, 'label': '1 Day'},
    {'days': 0, 'label': 'On the Day'},
  ];

  static const List<Map<String, String>> _repeatScheduleOptions = [
    {'value': 'one_time', 'label': 'One Time'},
    {'value': 'monthly', 'label': 'Every Month'},
    {'value': 'quarterly', 'label': 'Every Quarter'},
    {'value': 'yearly', 'label': 'Every Year'},
  ];

  @override
  void initState() {
    super.initState();
    final rec = widget.initialRecord;
    _titleController = TextEditingController(text: rec?.title ?? '');
    _subtitleController = TextEditingController(text: rec?.subtitle ?? '');
    _amountController = TextEditingController(text: rec?.amount != null ? rec!.amount.toString() : '');
    _recordDate = rec?.recordDate ?? DateTime.now();
    _isPrivate = rec?.isPrivate ?? false;

    if (rec != null) {
      _fieldValues.addAll(rec.fields);
      _restrictedFields.addAll(rec.restrictedFields);
      _hasReminder = rec.hasReminder;
      _selectedRemindBeforeDays.addAll(rec.remindBeforeDays);
      _selectedRepeatSchedule = rec.repeatSchedule;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diary = DiaryRegistry.getDiaryById(widget.diaryId);
    final color = diary?.color ?? Colors.blue;
    final suggestedFields = diary?.suggestedFields ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialRecord != null ? 'Edit Record' : 'New Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _isSaving ? null : _saveRecord,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Core Title Field
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      hintText: 'Enter entry title',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Subtitle / Notes Field
                  TextFormField(
                    controller: _subtitleController,
                    decoration: InputDecoration(
                      labelText: 'Summary / Description',
                      hintText: 'Optional summary or brief notes',
                      prefixIcon: const Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Date Picker & Amount Row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _recordDate,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2200),
                            );
                            if (picked != null) {
                              setState(() => _recordDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              prefixIcon: const Icon(Icons.calendar_today_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(DateFormat('d MMM yyyy').format(_recordDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount (Optional)',
                            prefixText: '₹ ',
                            prefixIcon: const Icon(Icons.currency_rupee_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Suggested Fields Section
                  if (suggestedFields.isNotEmpty) ...[
                    Text(
                      'DIARY FIELDS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...suggestedFields.map((field) => _buildCustomField(field)),
                    const SizedBox(height: 16),
                  ],

                  // Reminder Configuration Section
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text('Set Reminder', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Get alerts before the date arrives'),
                            value: _hasReminder,
                            secondary: Icon(
                              _hasReminder ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                              color: _hasReminder ? color : Colors.grey,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _hasReminder = val;
                                if (val && _selectedRemindBeforeDays.isEmpty) {
                                  _selectedRemindBeforeDays.add(0); // Default to On the Day
                                }
                              });
                            },
                          ),
                          if (_hasReminder) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'REMIND ME BEFORE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: _remindBeforeOptions.map((opt) {
                                      final days = opt['days'] as int;
                                      final label = opt['label'] as String;
                                      final isSelected = _selectedRemindBeforeDays.contains(days);
                                      return FilterChip(
                                        label: Text(label),
                                        selected: isSelected,
                                        selectedColor: color.withValues(alpha: 0.18),
                                        checkmarkColor: color,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? color : Colors.black87,
                                        ),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedRemindBeforeDays.add(days);
                                            } else {
                                              _selectedRemindBeforeDays.remove(days);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'REPEAT SCHEDULE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedRepeatSchedule,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.repeat_rounded),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    items: _repeatScheduleOptions
                                        .map((opt) => DropdownMenuItem(
                                              value: opt['value'],
                                              child: Text(opt['label']!),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedRepeatSchedule = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Privacy Switch
                  SwitchListTile(
                    title: const Text('Mark as Private Entry'),
                    subtitle: const Text('Keeps this record private even if the diary is shared'),
                    value: _isPrivate,
                    secondary: Icon(
                      _isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: _isPrivate ? Colors.purple : Colors.grey,
                    ),
                    onChanged: (val) {
                      setState(() => _isPrivate = val);
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveRecord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      widget.initialRecord != null ? 'Update Entry' : 'Save Entry',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomField(CustomFieldDefinition field) {
    switch (field.type) {
      case CustomFieldType.dropdown:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: DropdownButtonFormField<String>(
            initialValue: _fieldValues[field.key] as String? ?? field.dropdownOptions.firstOrNull,
            decoration: InputDecoration(
              labelText: field.label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: field.dropdownOptions
                .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _fieldValues[field.key] = val);
              }
            },
          ),
        );

      case CustomFieldType.date:
        final dateVal = _fieldValues[field.key] is String
            ? DateTime.tryParse(_fieldValues[field.key] as String)
            : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: InkWell(
            onTap: () async {
              final isBirthOrHistorical = field.key.toLowerCase().contains('birth') ||
                  field.key.toLowerCase().contains('dob') ||
                  field.label.toLowerCase().contains('birth') ||
                  field.key.toLowerCase().contains('anniversary') ||
                  field.label.toLowerCase().contains('anniversary');
              final picked = await showDatePicker(
                context: context,
                initialDate: dateVal ?? (isBirthOrHistorical ? DateTime(1990, 1, 1) : DateTime.now()),
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
                initialDatePickerMode: isBirthOrHistorical ? DatePickerMode.year : DatePickerMode.day,
              );
              if (picked != null) {
                setState(() => _fieldValues[field.key] = picked.toIso8601String());
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: field.label,
                prefixIcon: const Icon(Icons.event_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(dateVal != null ? DateFormat('d MMM yyyy').format(dateVal) : 'Select Date'),
            ),
          ),
        );

      case CustomFieldType.currency:
      case CustomFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: TextFormField(
            initialValue: _fieldValues[field.key]?.toString() ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: field.label,
              prefixText: field.type == CustomFieldType.currency ? '₹ ' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) {
              _fieldValues[field.key] = double.tryParse(val) ?? val;
            },
          ),
        );

      case CustomFieldType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: SwitchListTile(
            title: Text(field.label),
            value: _fieldValues[field.key] as bool? ?? false,
            onChanged: (val) {
              setState(() => _fieldValues[field.key] = val);
            },
          ),
        );

      case CustomFieldType.multiline:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: TextFormField(
            initialValue: _fieldValues[field.key]?.toString() ?? '',
            decoration: InputDecoration(
              labelText: field.label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 3,
            onChanged: (val) {
              _fieldValues[field.key] = val;
            },
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: TextFormField(
            initialValue: _fieldValues[field.key]?.toString() ?? '',
            decoration: InputDecoration(
              labelText: field.label,
              hintText: field.placeholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) {
              _fieldValues[field.key] = val;
            },
          ),
        );
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(userProfileProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save records')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final recordId = widget.initialRecord?.id ?? const Uuid().v4();
      final amount = double.tryParse(_amountController.text.trim());
      final targetUserId = (widget.ownerId != null && widget.ownerId!.isNotEmpty) ? widget.ownerId! : user.uid;
      final repo = ref.read(diaryRecordRepositoryProvider);

      // Duplicate detection to prevent accidental duplicate entries
      if (widget.initialRecord == null) {
        final duplicate = await repo.findPotentialDuplicate(
          userId: targetUserId,
          diaryId: widget.diaryId,
          title: _titleController.text.trim(),
          recordDate: _recordDate,
        );
        if (duplicate != null && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Duplicate Entry Detected'),
                ],
              ),
              content: Text(
                'An entry with the title "${duplicate.title}" already exists for this date in this diary. Do you want to save anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save Anyway'),
                ),
              ],
            ),
          );
          if (proceed != true) {
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      final List<int> remindDays = _hasReminder
          ? (_selectedRemindBeforeDays.toList()..sort((a, b) => b.compareTo(a)))
          : const [];
      final String repeatSchedule = _hasReminder ? _selectedRepeatSchedule : 'one_time';
      final String? reminderId = _hasReminder
          ? (widget.initialRecord?.reminderId ?? 'reminder_record_$recordId')
          : null;

      final record = DiaryRecord(
        id: recordId,
        ownerId: targetUserId,
        sourceDiaryId: widget.diaryId,
        circleId: widget.initialRecord?.circleId,
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim().isNotEmpty ? _subtitleController.text.trim() : null,
        recordDate: _recordDate,
        amount: amount,
        fields: _fieldValues,
        restrictedFields: _restrictedFields,
        isPrivate: _isPrivate,
        attachmentIds: widget.initialRecord?.attachmentIds ?? const [],
        reminderId: reminderId,
        remindBeforeDays: remindDays,
        repeatSchedule: repeatSchedule,
        createdBy: widget.initialRecord?.createdBy ?? user.uid,
        updatedBy: user.uid,
        createdAt: widget.initialRecord?.createdAt ?? now,
        updatedAt: now,
      );

      await repo.saveRecord(userId: targetUserId, record: record);

      // Manage Reminder sync
      final reminderRepo = ref.read(reminderRepositoryProvider);
      final diary = DiaryRegistry.getDiaryById(widget.diaryId);
      if (_hasReminder && reminderId != null) {
        final reminder = Reminder(
          id: reminderId,
          userId: targetUserId,
          title: record.title,
          description: record.subtitle ?? '${diary?.name ?? "Diary"} entry reminder',
          module: diary?.categoryId ?? 'General',
          dueDate: _recordDate,
          relatedId: record.id,
          amount: record.amount,
          actionRoute: '/diary-records/${widget.diaryId}',
          actionType: 'Review',
          remindBeforeDays: remindDays,
          repeatSchedule: repeatSchedule,
          createdAt: now,
        );
        await reminderRepo.syncReminder(targetUserId, reminder);

        // Standardize schedule in notification_schedules for GitHub Actions Worker & Local Push
        try {
          final notifManager = NotificationManager();
          await notifManager.scheduleForRecord(
            userId: targetUserId,
            recordId: record.id,
            moduleId: diary?.categoryId ?? 'general',
            categoryId: diary?.categoryId ?? 'general',
            eventType: 'diary_entry_reminder',
            title: record.title,
            dueDate: _recordDate,
            amount: record.amount,
            actionRoute: '/diary-records/${widget.diaryId}',
            tokenData: {'description': record.subtitle ?? ''},
          );
        } catch (_) {}
      } else if (widget.initialRecord?.reminderId != null) {
        // Delete the reminder if it was previously set and is now disabled
        await reminderRepo.deleteReminder(targetUserId, widget.initialRecord!.reminderId!);
        try {
          final notifManager = NotificationManager();
          await notifManager.cancelForRecord(
            userId: targetUserId,
            recordId: widget.initialRecord!.id,
          );
        } catch (_) {}
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save record: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
