import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_profile.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared_diaries/repositories/frequent_contacts_repository.dart';
import '../../shared_diaries/repositories/shared_diary_repository.dart';
import '../../shared_diaries/widgets/qr_code_scan_dialog.dart';
import '../models/circle_candidate_member.dart';
import '../models/magic_circle_models.dart';
import '../providers/connected_users_provider.dart';

class AddCircleMemberSheet extends ConsumerStatefulWidget {
  final Function(CircleCandidateMember member) onMemberAdded;
  final MagicCircle? existingCircle;
  final VoidCallback? onInviteLinkRequested;

  const AddCircleMemberSheet({
    super.key,
    required this.onMemberAdded,
    this.existingCircle,
    this.onInviteLinkRequested,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(CircleCandidateMember member) onMemberAdded,
    MagicCircle? existingCircle,
    VoidCallback? onInviteLinkRequested,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddCircleMemberSheet(
        onMemberAdded: onMemberAdded,
        existingCircle: existingCircle,
        onInviteLinkRequested: onInviteLinkRequested,
      ),
    );
  }

  @override
  ConsumerState<AddCircleMemberSheet> createState() => _AddCircleMemberSheetState();
}

class _AddCircleMemberSheetState extends ConsumerState<AddCircleMemberSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Username channel state
  final _usernameController = TextEditingController();
  bool _isSearchingUsername = false;
  UserProfile? _resolvedUser;
  String? _usernameError;
  CircleRole _usernameRole = CircleRole.contributor;

  // Email channel state
  final _emailController = TextEditingController();
  CircleRole _emailRole = CircleRole.contributor;
  String? _emailError;

  // Contacts search query
  String _contactsFilter = '';

  // Existing users search query
  String _existingUsersFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text(
                'Add Circle Member',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.deepPurple,
            tabs: const [
              Tab(icon: Icon(Icons.alternate_email_rounded, size: 18), text: 'Username'),
              Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 18), text: 'QR Code'),
              Tab(icon: Icon(Icons.email_outlined, size: 18), text: 'Email'),
              Tab(icon: Icon(Icons.contacts_rounded, size: 18), text: 'Contacts'),
              Tab(icon: Icon(Icons.people_outline_rounded, size: 18), text: 'Connected'),
            ],
          ),
          const SizedBox(height: 12),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsernameTab(theme),
                _buildQrScanTab(theme),
                _buildEmailTab(theme),
                _buildContactsTab(theme),
                _buildConnectedUsersTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Channel 1: Username
  // ==========================================
  Widget _buildUsernameTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Search Magic Diary by 7-Character Username',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Usernames consist of 7 letters (uppercase) and digits (excluding O and 0).',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@]')),
                    UpperCaseTextFormatter(),
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    labelText: 'Username',
                    hintText: 'e.g. KYZMPTR',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    errorText: _usernameError,
                  ),
                  onSubmitted: (_) => _searchUsername(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSearchingUsername ? null : _searchUsername,
                child: _isSearchingUsername
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_resolvedUser != null) ...[
            _buildResolvedUserCard(
              user: _resolvedUser!,
              channel: 'username',
              role: _usernameRole,
              onRoleChanged: (r) => setState(() => _usernameRole = r),
              onAdd: () {
                _addCandidate(
                  CircleCandidateMember(
                    uid: _resolvedUser!.uid,
                    email: _resolvedUser!.email.isNotEmpty
                        ? _resolvedUser!.email
                        : '${_resolvedUser!.username.toLowerCase()}@magicdiary.internal',
                    displayName: _resolvedUser!.displayName.isNotEmpty
                        ? _resolvedUser!.displayName
                        : '@${_resolvedUser!.username}',
                    username: _resolvedUser!.username,
                    role: _usernameRole,
                    status: 'active',
                    channel: 'username',
                    photoUrl: _resolvedUser!.photoUrl,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _searchUsername() async {
    final raw = _usernameController.text.trim().replaceAll('@', '').toUpperCase();
    if (raw.isEmpty) {
      setState(() => _usernameError = 'Please enter a username');
      return;
    }

    final currentUser = ref.read(userProfileProvider);
    if (currentUser != null &&
        (currentUser.username.toUpperCase() == raw || currentUser.uid == raw)) {
      setState(() => _usernameError = 'You are already the owner of this Circle');
      return;
    }

    setState(() {
      _isSearchingUsername = true;
      _usernameError = null;
    });

    try {
      final repo = ref.read(sharedDiaryRepositoryProvider);
      final profile = await repo.lookupUserByUsername(raw);
      if (mounted) {
        setState(() {
          _isSearchingUsername = false;
          if (profile != null) {
            _resolvedUser = profile;
          } else {
            _usernameError = 'No user found with username "@$raw"';
            _resolvedUser = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingUsername = false;
          _usernameError = 'Lookup failed: $e';
        });
      }
    }
  }

  // ==========================================
  // Channel 2: QR Code Scan
  // ==========================================
  Widget _buildQrScanTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.deepPurple.shade50,
            child: const Icon(Icons.qr_code_scanner_rounded, size: 44, color: Colors.deepPurple),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scan User Profile QR',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Scan another member\'s Magic Diary profile QR code from camera or gallery to instantly add them.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Open QR Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _openQrScanner,
          ),
        ],
      ),
    );
  }

  Future<void> _openQrScanner() async {
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
    } else if (result.type == QrScanType.circleInviteToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scanned Circle invite token: ${result.value}')),
      );
    }
  }

  // ==========================================
  // Channel 3: Email
  // ==========================================
  Widget _buildEmailTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Invite via Email Address',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'New or existing members will receive an invite to join the Circle.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email_outlined),
              labelText: 'Email Address',
              hintText: 'e.g. member@example.com',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _emailError,
            ),
          ),
          const SizedBox(height: 16),

          // Role selection
          DropdownButtonFormField<CircleRole>(
            initialValue: _emailRole,
            decoration: InputDecoration(
              labelText: 'Member Role',
              prefixIcon: const Icon(Icons.shield_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: CircleRole.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _emailRole = val);
            },
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _addByEmail,
          ),
        ],
      ),
    );
  }

  void _addByEmail() {
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      return;
    }

    final currentUser = ref.read(userProfileProvider);
    if (currentUser != null && currentUser.email.trim().toLowerCase() == email) {
      setState(() => _emailError = 'You are already the owner of this Circle');
      return;
    }

    _addCandidate(
      CircleCandidateMember(
        email: email,
        displayName: email.split('@').first,
        role: _emailRole,
        status: 'invited',
        channel: 'email',
      ),
    );
  }

  // ==========================================
  // Channel 4: Frequent Contacts
  // ==========================================
  Widget _buildContactsTab(ThemeData theme) {
    final currentUser = ref.watch(userProfileProvider);
    if (currentUser == null) return const SizedBox.shrink();

    final contactsAsync =
        ref.watch(frequentContactsStreamProvider(currentUser.uid));

    return contactsAsync.when(
      data: (contacts) {
        final filtered = contacts.where((c) {
          final q = _contactsFilter.toLowerCase();
          return c.displayName.toLowerCase().contains(q) ||
              c.email.toLowerCase().contains(q) ||
              (c.username != null && c.username!.toLowerCase().contains(q));
        }).toList();

        return Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) => setState(() => _contactsFilter = val),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No frequent contacts found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple.shade100,
                            foregroundColor: Colors.deepPurple.shade900,
                            child: Text(
                              c.displayName.isNotEmpty
                                  ? c.displayName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(
                            c.displayName.isNotEmpty ? c.displayName : c.email,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            c.username != null ? '@${c.username} • ${c.email}' : c.email,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.add_rounded),
                            tooltip: 'Add to Circle',
                            onPressed: () {
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
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading contacts: $e')),
    );
  }

  // ==========================================
  // Channel 6: Existing Connected Users
  // ==========================================
  Widget _buildConnectedUsersTab(ThemeData theme) {
    final connectedUsersAsync = ref.watch(connectedUsersStreamProvider);

    return connectedUsersAsync.when(
      data: (users) {
        final filtered = users.where((u) {
          final q = _existingUsersFilter.toLowerCase();
          return u.displayName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              (u.username != null && u.username!.toLowerCase().contains(q));
        }).toList();

        return Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search connected users...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) => setState(() => _existingUsersFilter = val),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No connected users found yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final u = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            foregroundColor: Colors.teal.shade900,
                            child: Text(
                              u.displayName.isNotEmpty
                                  ? u.displayName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(
                            u.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.username != null
                                    ? '@${u.username} • ${u.email}'
                                    : u.email,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              Text(
                                u.sourceDescription,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton.filledTonal(
                            icon: const Icon(Icons.add_rounded),
                            tooltip: 'Add to Circle',
                            onPressed: () {
                              _addCandidate(
                                CircleCandidateMember(
                                  uid: u.uid.isNotEmpty ? u.uid : null,
                                  email: u.email,
                                  displayName: u.displayName,
                                  username: u.username,
                                  role: CircleRole.contributor,
                                  status: u.uid.isNotEmpty ? 'active' : 'invited',
                                  channel: 'existing_users',
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading connected users: $e')),
    );
  }

  // ==========================================
  // Helper: Card for Resolved User
  // ==========================================
  Widget _buildResolvedUserCard({
    required UserProfile user,
    required String channel,
    required CircleRole role,
    required ValueChanged<CircleRole> onRoleChanged,
    required VoidCallback onAdd,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : user.username[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName.isNotEmpty ? user.displayName : '@${user.username}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 16, color: Colors.blue),
                      ],
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CircleRole>(
            initialValue: role,
            decoration: InputDecoration(
              labelText: 'Role',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: CircleRole.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
            onChanged: (val) {
              if (val != null) onRoleChanged(val);
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add to Circle'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }

  void _addCandidate(CircleCandidateMember candidate) {
    widget.onMemberAdded(candidate);
    Navigator.of(context).pop();
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
