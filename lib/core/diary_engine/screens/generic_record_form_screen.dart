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
        reminderId: widget.initialRecord?.reminderId,
        createdBy: widget.initialRecord?.createdBy ?? user.uid,
        updatedBy: user.uid,
        createdAt: widget.initialRecord?.createdAt ?? now,
        updatedAt: now,
      );

      final repo = ref.read(diaryRecordRepositoryProvider);
      await repo.saveRecord(userId: targetUserId, record: record);

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
