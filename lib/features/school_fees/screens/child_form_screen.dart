import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../models/school_fees_models.dart';

class ChildFormScreen extends ConsumerStatefulWidget {
  final Child? child;
  const ChildFormScreen({super.key, this.child});

  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _schoolNameController;
  late TextEditingController _gradeController;
  late TextEditingController _notesController;
  late DateTime _dob;
  late String _gender;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child?.name ?? '');
    _schoolNameController = TextEditingController(text: widget.child?.schoolName ?? '');
    _gradeController = TextEditingController(text: widget.child?.grade ?? '');
    _notesController = TextEditingController(text: widget.child?.notes ?? '');
    _dob = widget.child?.dateOfBirth ?? DateTime(2016, 1, 1);
    _gender = widget.child?.gender ?? 'Male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolNameController.dispose();
    _gradeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChild() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(schoolFeesRepositoryProvider);

    final isEditing = widget.child != null;
    final child = Child(
      id: widget.child?.id ?? '',
      userId: user.uid,
      name: _nameController.text.trim(),
      dateOfBirth: _dob,
      gender: _gender,
      schoolName: _schoolNameController.text.trim().isNotEmpty ? _schoolNameController.text.trim() : null,
      grade: _gradeController.text.trim().isNotEmpty ? _gradeController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      createdAt: widget.child?.createdAt ?? DateTime.now(),
    );

    await repo.addChild(user.uid, child);
    ref.invalidate(childrenProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Child profile updated successfully!' : 'Child profile created successfully!')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/school-fees');
      }
    }
  }

  Future<void> _deleteChild() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Child Profile?'),
        content: Text('Are you sure you want to delete ${widget.child!.name}\'s profile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final user = ref.read(userProfileProvider);
    if (user != null) {
      await ref.read(schoolFeesRepositoryProvider).deleteChild(user.uid, widget.child!.id);
      ref.invalidate(childrenProvider);
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.child != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/school-fees');
            }
          },
        ),
        title: Text(isEditing ? 'Edit Child Profile' : 'Add Child Profile'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Child',
              onPressed: _deleteChild,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'e.g., Aarav Sharma',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter child name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _schoolNameController,
                decoration: const InputDecoration(
                  labelText: 'School / Institution Name',
                  hintText: 'e.g., Delhi Public School, Ryan International, St. Mary\'s',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gradeController,
                      decoration: const InputDecoration(
                        labelText: 'Grade / Class (Optional)',
                        hintText: 'e.g., Grade 5, Class 10, UKG',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _gender = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.cake, color: Colors.purple),
                title: const Text('Date of Birth'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_dob)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dob,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Special Remarks (Optional)',
                  hintText: 'e.g., Student ID / Roll number, section, bus route',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveChild,
                  icon: const Icon(Icons.check),
                  label: Text(isEditing ? 'Update Child Profile' : 'Save Child Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
