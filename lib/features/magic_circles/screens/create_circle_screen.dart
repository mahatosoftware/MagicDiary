import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../models/magic_circle_models.dart';
import 'magic_circles_screen.dart';
import '../../../core/providers/app_providers.dart';

class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _memberEmailController = TextEditingController();

  CircleCategory _selectedCategory = CircleCategory.family;
  final List<String> _pendingMemberEmails = [];
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Magic Circle'),
      ),
      body: _isCreating
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Circle Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Circle Name *',
                      hintText: 'e.g., Mahato Family, Goa Trip 2026, Green Villa',
                      prefixIcon: const Icon(Icons.groups_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Circle name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Circle Category
                  DropdownButtonFormField<CircleCategory>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: const Icon(Icons.category_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: CircleCategory.values
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.label)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Purpose of this Circle (e.g., household chores & expense sharing)',
                      prefixIcon: const Icon(Icons.description_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Invite Members Section
                  Text(
                    'INITIAL MEMBERS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _memberEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter member email',
                            prefixIcon: const Icon(Icons.person_add_alt_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: _addMemberEmail,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_pendingMemberEmails.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pendingMemberEmails.map((email) {
                        return Chip(
                          avatar: const Icon(Icons.email, size: 14),
                          label: Text(email),
                          onDeleted: () {
                            setState(() => _pendingMemberEmails.remove(email));
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 32),

                  // Create Button
                  ElevatedButton(
                    onPressed: _createCircle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Create Circle',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _addMemberEmail() {
    final email = _memberEmailController.text.trim();
    if (email.isNotEmpty && email.contains('@') && !_pendingMemberEmails.contains(email)) {
      setState(() {
        _pendingMemberEmails.add(email);
        _memberEmailController.clear();
      });
    }
  }

  Future<void> _createCircle() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(userProfileProvider);
    if (user == null) return;

    setState(() => _isCreating = true);

    try {
      final now = DateTime.now();
      final circleId = const Uuid().v4();

      final ownerMember = MagicCircleMember(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        role: CircleRole.owner,
        joinedAt: now,
        status: 'active',
      );

      final invitedMembers = _pendingMemberEmails.map((email) {
        return MagicCircleMember(
          uid: 'pending_$email',
          email: email,
          displayName: email.split('@').first,
          role: CircleRole.contributor,
          joinedAt: now,
          status: 'invited',
        );
      }).toList();

      final circle = MagicCircle(
        id: circleId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        ownerId: user.uid,
        members: [ownerMember, ...invitedMembers],
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(magicCircleRepositoryProvider);
      await repo.createCircle(circle);

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create circle: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }
}
