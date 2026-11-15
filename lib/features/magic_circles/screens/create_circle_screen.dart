import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../models/magic_circle_models.dart';
import '../models/circle_candidate_member.dart';
import '../widgets/add_circle_member_sheet.dart';
import '../widgets/circle_invite_ready_dialog.dart';
import 'magic_circles_screen.dart';
import '../../../core/security/circle_permission_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared_diaries/models/frequent_contact.dart';
import '../../shared_diaries/repositories/frequent_contacts_repository.dart';
import '../../shared_diaries/repositories/shared_diary_repository.dart';
import '../../shared_diaries/widgets/frequent_contact_suggestions.dart';
import '../../shared_diaries/widgets/qr_code_scan_dialog.dart';

class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  CircleCategory _selectedCategory = CircleCategory.family;
  final List<CircleCandidateMember> _candidateMembers = [];
  bool _generateInviteLink = true;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addCandidate(CircleCandidateMember member) {
    if (_candidateMembers.contains(member)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.displayName} is already added'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _candidateMembers.add(member);
    });
  }

  void _removeCandidate(CircleCandidateMember member) {
    setState(() {
      _candidateMembers.remove(member);
    });
  }

  void _updateCandidateRole(CircleCandidateMember member, CircleRole newRole) {
    final idx = _candidateMembers.indexOf(member);
    if (idx != -1) {
      setState(() {
        _candidateMembers[idx] = member.copyWith(role: newRole);
      });
    }
  }

  Future<void> _scanQrCode() async {
    final result = await QrCodeScanDialog.show(context);
    if (!mounted || result == null) return;

    if (result.type == QrScanType.username || result.type == QrScanType.email) {
      final clean = result.value.replaceAll('@', '').trim();
      final repo = ref.read(sharedDiaryRepositoryProvider);
      final profile = await repo.lookupUserByUsername(
        clean,
        uidHint: result.uid,
        displayNameHint: result.displayName,
        emailHint: result.email,
      );

      if (mounted) {
        if (profile != null) {
          _addCandidate(
            CircleCandidateMember(
              uid: profile.uid,
              email: profile.email.isNotEmpty
                  ? profile.email
                  : '${profile.username.toLowerCase()}@magicdiary.internal',
              displayName: profile.displayName.isNotEmpty
                  ? profile.displayName
                  : '@${profile.username}',
              username: profile.username,
              role: CircleRole.contributor,
              status: 'active',
              channel: 'qr',
            ),
          );
        } else if (result.email != null && result.email!.contains('@')) {
          _addCandidate(
            CircleCandidateMember(
              email: result.email!,
              displayName: result.displayName ?? result.email!.split('@').first,
              username: result.value,
              role: CircleRole.contributor,
              status: 'invited',
              channel: 'qr',
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scanned code: ${result.value}. User lookup not found.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProfileProvider);
    final frequentContactsAsync = currentUser != null
        ? ref.watch(frequentContactsStreamProvider(currentUser.uid))
        : const AsyncValue<List<FrequentContact>>.data([]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Magic Circle'),
      ),
      body: _isCreating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating Magic Circle...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
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

                  // Initial Members Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INITIAL MEMBERS (${_candidateMembers.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('Add Member'),
                        onPressed: () {
                          AddCircleMemberSheet.show(
                            context,
                            onMemberAdded: _addCandidate,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Multi-channel quick action buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.alternate_email_rounded, size: 16),
                          label: const Text('Username'),
                          onPressed: () {
                            AddCircleMemberSheet.show(
                              context,
                              onMemberAdded: _addCandidate,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                          label: const Text('Scan QR'),
                          onPressed: _scanQrCode,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.email_outlined, size: 16),
                          label: const Text('Email'),
                          onPressed: () {
                            AddCircleMemberSheet.show(
                              context,
                              onMemberAdded: _addCandidate,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.contacts_rounded, size: 16),
                          label: const Text('Contacts'),
                          onPressed: () {
                            AddCircleMemberSheet.show(
                              context,
                              onMemberAdded: _addCandidate,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.people_outline_rounded, size: 16),
                          label: const Text('Connected Users'),
                          onPressed: () {
                            AddCircleMemberSheet.show(
                              context,
                              onMemberAdded: _addCandidate,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Frequent Contacts Quick Suggestions
                  frequentContactsAsync.maybeWhen(
                    data: (contacts) {
                      final available = contacts
                          .where((c) => !_candidateMembers.any((m) =>
                              m.email.toLowerCase() == c.email.toLowerCase() ||
                              (m.username != null &&
                                  c.username != null &&
                                  m.username!.toUpperCase() == c.username!.toUpperCase())))
                          .take(6)
                          .toList();
                      if (available.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Frequent Contacts:',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            FrequentContactChipsRow(
                              contacts: available,
                              onContactSelected: (c) {
                                _addCandidate(
                                  CircleCandidateMember(
                                    email: c.email,
                                    displayName: c.displayName.isNotEmpty
                                        ? c.displayName
                                        : c.email.split('@').first,
                                    username: c.username,
                                    role: CircleRole.contributor,
                                    status: 'invited',
                                    channel: 'contacts',
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  // Candidate members list
                  if (_candidateMembers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          'No initial members added yet.\nYou can add members via Username, QR, Email, Contacts, or generate an invite link.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _candidateMembers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final m = _candidateMembers[i];
                        return _buildCandidateCard(m);
                      },
                    ),

                  const SizedBox(height: 24),

                  // Shareable Invite Link Checkbox Option (Channel 5)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurple.shade100),
                    ),
                    child: SwitchListTile(
                      value: _generateInviteLink,
                      activeThumbColor: Colors.deepPurple,
                      title: const Text(
                        'Generate Shareable Invite Link',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Generates a deep link & QR code to share via WhatsApp, SMS, or other apps upon creation.',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) => setState(() => _generateInviteLink = val),
                    ),
                  ),

                  const SizedBox(height: 24),

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

  Widget _buildCandidateCard(CircleCandidateMember member) {
    String channelLabel;
    IconData channelIcon;
    Color channelColor;

    switch (member.channel) {
      case 'username':
        channelLabel = 'Username';
        channelIcon = Icons.alternate_email_rounded;
        channelColor = Colors.deepPurple;
        break;
      case 'qr':
        channelLabel = 'QR Scan';
        channelIcon = Icons.qr_code_rounded;
        channelColor = Colors.indigo;
        break;
      case 'contacts':
        channelLabel = 'Contact';
        channelIcon = Icons.contacts_rounded;
        channelColor = Colors.orange.shade800;
        break;
      case 'existing_users':
        channelLabel = 'Connected';
        channelIcon = Icons.people_outline_rounded;
        channelColor = Colors.teal;
        break;
      default:
        channelLabel = 'Email';
        channelIcon = Icons.email_outlined;
        channelColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: channelColor.withValues(alpha: 0.15),
            foregroundColor: channelColor,
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (member.isRegisteredUser) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 14, color: Colors.blue),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Icon(channelIcon, size: 12, color: channelColor),
                    const SizedBox(width: 4),
                    Text(
                      channelLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: channelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      member.username != null ? ' • @${member.username}' : ' • ${member.email}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          DropdownButton<CircleRole>(
            value: member.role,
            underline: const SizedBox.shrink(),
            items: CircleRole.values
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.label, style: const TextStyle(fontSize: 11.5)),
                    ))
                .toList(),
            onChanged: (newRole) {
              if (newRole != null) _updateCandidateRole(member, newRole);
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => _removeCandidate(member),
          ),
        ],
      ),
    );
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

      final circleMembers = [
        ownerMember,
        ..._candidateMembers.map((c) => c.toMagicCircleMember(joinedAt: now)),
      ];

      final circle = MagicCircle(
        id: circleId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        ownerId: user.uid,
        members: circleMembers,
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(magicCircleRepositoryProvider);
      await repo.createCircle(circle);

      // Record contact usage for future suggestions
      for (final candidate in _candidateMembers) {
        try {
          await ref.read(frequentContactsRepositoryProvider).recordContactUsage(
                userId: user.uid,
                email: candidate.email,
                name: candidate.displayName,
                username: candidate.username,
              );
        } catch (_) {}
      }

      if (mounted) {
        if (_generateInviteLink) {
          final inviteToken = const Uuid().v4();
          // Optionally register invitation in Firestore
          try {
            final permService = CirclePermissionService();
            await permService.createInvitation(
              circleId: circle.id,
              circleName: circle.name,
              inviterUid: user.uid,
              inviterName: user.displayName,
              inviteeEmail: 'link@magicdiary.internal',
              role: 'contributor',
            );
          } catch (_) {}

          if (mounted) {
            await CircleInviteReadyDialog.show(
              context,
              circleId: circle.id,
              circleName: circle.name,
              token: inviteToken,
            );
          }
        }

        if (mounted) {
          context.pop();
        }
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
