import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/diary_registry/diary_definition.dart';
import '../../../core/providers/app_providers.dart';
import '../../auth/models/user_profile.dart';
import '../../magic_circles/models/magic_circle_models.dart';
import '../../magic_circles/screens/magic_circles_screen.dart';
import '../models/shared_diary_models.dart';
import '../repositories/frequent_contacts_repository.dart';
import '../repositories/shared_diary_repository.dart';
import '../screens/record_selection_screen.dart';
import 'frequent_contact_suggestions.dart';
import 'qr_code_scan_dialog.dart';
import 'invite_link_ready_dialog.dart';

class SharingWizardSheet extends ConsumerStatefulWidget {
  final DiaryDefinition initialDiary;
  final SharedDiaryAccess? initialShare; // If editing an existing share
  final MagicCircle? initialCircle;

  const SharingWizardSheet({
    super.key,
    required this.initialDiary,
    this.initialShare,
    this.initialCircle,
  });

  static Future<void> show(BuildContext context, DiaryDefinition diary,
      {SharedDiaryAccess? share}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          SharingWizardSheet(initialDiary: diary, initialShare: share),
    );
  }

  /// Lets a Circle start the share with itself already chosen.
  static Future<void> showForCircle(
    BuildContext context,
    DiaryDefinition diary,
    MagicCircle circle,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SharingWizardSheet(
        initialDiary: diary,
        initialCircle: circle,
      ),
    );
  }

  @override
  ConsumerState<SharingWizardSheet> createState() => _SharingWizardSheetState();
}

class _SharingWizardSheetState extends ConsumerState<SharingWizardSheet> {
  int _currentStep = 1; // 1 to 6 steps

  // Step 1: Destination
  RecipientType _recipientType = RecipientType.user;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _recipientNameController =
      TextEditingController();
  FrequentContact? _selectedContact;
  UserProfile? _resolvedUser;
  bool _isSearchingUsername = false;
  String? _usernameSearchError;
  int _inviteExpiryDays = 7;
  String? _selectedCircleId;
  String? _selectedCircleName;
  MagicCircle? _selectedCircle;

  // Step 2: Sharing Mode
  SharingMode _sharingMode = SharingMode.entire;

  // Step 3: Scope & Records
  FutureRecordPolicy _futurePolicy = FutureRecordPolicy.allFuture;
  Set<String> _selectedRecordIds = {};
  List<String> _restrictedFields = [];

  // Step 4: Permission Level
  SharedDiaryPermission _permission = SharedDiaryPermission.viewer;

  // Step 5: Expiry & Restrictions
  DateTime? _expiresAt;
  bool _allowAttachments = true;
  bool _allowComments = true;
  bool _allowExport = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    final initialCircle = widget.initialCircle;
    if (initialCircle != null) {
      _recipientType = RecipientType.circle;
      _selectedCircleId = initialCircle.id;
      _selectedCircleName = initialCircle.name;
      _selectedCircle = initialCircle;
    }
    final s = widget.initialShare;
    if (s != null) {
      _recipientType = s.recipientType;
      _emailController.text = s.sharedWithEmail;
      _recipientNameController.text = s.sharedWithName;
      _selectedCircleId = s.circleId;
      _selectedCircleName = s.circleName;
      _sharingMode = s.sharingMode;
      _futurePolicy = s.futurePolicySafe;
      _selectedRecordIds = Set<String>.from(s.grantedRecordIds);
      _permission = s.permission;
      _expiresAt = s.expiresAt;
      _allowAttachments = s.allowAttachments;
      _allowComments = s.allowComments;
      _allowExport = s.allowExport;
      _restrictedFields = List<String>.from(s.restrictedFields);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider);
      if (user != null) {
        ref
            .read(frequentContactsRepositoryProvider)
            .seedFromExistingShares(user.uid);
      }
    });
  }

  void _onEmailChanged() {
    setState(() {});
  }

  void _selectFrequentContact(FrequentContact contact) {
    setState(() {
      _emailController.text = contact.email;
      _recipientNameController.text =
          contact.name.isNotEmpty ? contact.name : contact.displayName;
      _selectedContact = contact;
    });
  }

  void _clearSelectedContact() {
    setState(() {
      _emailController.clear();
      _recipientNameController.clear();
      _selectedContact = null;
      _resolvedUser = null;
      _usernameSearchError = null;
    });
  }

  Future<void> _searchUsername(
    String query, {
    String? uidHint,
    String? displayNameHint,
    String? emailHint,
  }) async {
    final clean = query.trim().replaceAll('@', '').toUpperCase();
    if (clean.isEmpty && (uidHint == null || uidHint.trim().isEmpty)) {
      setState(() {
        _resolvedUser = null;
        _usernameSearchError = null;
      });
      return;
    }

    final currentUser = ref.read(userProfileProvider);
    if (currentUser != null &&
        (currentUser.username.toUpperCase() == clean ||
            (uidHint != null && uidHint == currentUser.uid))) {
      setState(() {
        _resolvedUser = null;
        _usernameSearchError =
            'You cannot share a diary with your own username.';
      });
      return;
    }

    setState(() {
      _isSearchingUsername = true;
      _usernameSearchError = null;
    });

    try {
      final user =
          await ref.read(sharedDiaryRepositoryProvider).lookupUserByUsername(
                clean,
                uidHint: uidHint,
                displayNameHint: displayNameHint,
                emailHint: emailHint,
              );
      if (mounted) {
        setState(() {
          _isSearchingUsername = false;
          _resolvedUser = user;
          if (user != null) {
            _emailController.text = user.email.isNotEmpty
                ? user.email
                : '$clean@magicdiary.internal';
            _recipientNameController.text =
                user.displayName.isNotEmpty ? user.displayName : '@$clean';
            _selectedContact = null;
          } else {
            _usernameSearchError =
                'No user found with username "@$clean". Make sure the recipient has registered or shared their QR code.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingUsername = false;
          _usernameSearchError = 'Lookup failed: $e';
        });
      }
    }
  }

  Future<void> _openQrScanner() async {
    final result = await QrCodeScanDialog.show(context);
    if (result == null || !mounted) return;

    if (result.type == QrScanType.username) {
      setState(() {
        _recipientType = RecipientType.user;
        _emailController.text = '@${result.value}';
      });
      await _searchUsername(
        result.value,
        uidHint: result.uid,
        displayNameHint: result.displayName,
        emailHint: result.email,
      );
    } else if (result.type == QrScanType.email) {
      setState(() {
        _recipientType = RecipientType.user;
        _emailController.text = result.value;
        _recipientNameController.text =
            result.displayName ?? result.value.split('@').first;
        _resolvedUser = null;
      });
    } else if (result.type == QrScanType.inviteToken) {
      Navigator.of(context).pop();
      context.push('/share/invite/${result.value}');
    } else {
      setState(() {
        _recipientType = RecipientType.user;
        _emailController.text = result.value;
      });
      if (result.value.contains('@') && !result.value.startsWith('@')) {
        _recipientNameController.text = result.value.split('@').first;
      } else {
        await _searchUsername(
          result.value,
          uidHint: result.uid,
          displayNameHint: result.displayName,
          emailHint: result.email,
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _recipientNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diary = widget.initialDiary;
    final color = diary.color;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(diary.icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialShare != null
                          ? 'Edit Diary Share'
                          : 'Share Diary',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${diary.name} • Step $_currentStep of 6',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress Indicator
          LinearProgressIndicator(
            value: _currentStep / 6,
            color: color,
            backgroundColor: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),

          const SizedBox(height: 16),

          // Wizard Body by Step
          Expanded(
            child: SingleChildScrollView(
              child: _buildCurrentStepContent(context, color),
            ),
          ),

          const SizedBox(height: 14),

          // Navigation Buttons (Back & Next / Confirm)
          Row(
            children: [
              if (_currentStep > 1)
                OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Back'),
                ),
              if (_currentStep > 1) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _onNextOrConfirm,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _currentStep == 6
                              ? (widget.initialShare != null
                                  ? 'Update Share'
                                  : 'Confirm & Share')
                              : 'Continue',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(BuildContext context, Color color) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Destination(color);
      case 2:
        return _buildStep2SharingMode(color);
      case 3:
        return _buildStep3Scope(color);
      case 4:
        return _buildStep4Permissions(color);
      case 5:
        return _buildStep5ExpiryAndRestrictions(color);
      case 6:
        return _buildStep6Preview(color);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1: DESTINATION (User, Circle, or One-Time Deep Link)
  // ---------------------------------------------------------------------------
  Widget _buildStep1Destination(Color color) {
    final userCirclesAsync = ref.watch(userCirclesStreamProvider);
    final currentUser = ref.watch(userProfileProvider);
    final frequentContactsAsync = currentUser != null
        ? ref.watch(frequentContactsStreamProvider(currentUser.uid))
        : const AsyncValue<List<FrequentContact>>.data([]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Choose Sharing Destination',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'Share with an individual via email/username, collaborate in a Circle, or generate a one-time invite deep link.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        SegmentedButton<RecipientType>(
          segments: const [
            ButtonSegment(
              value: RecipientType.user,
              icon: Icon(Icons.person_outline),
              label: Text('User / Email'),
            ),
            ButtonSegment(
              value: RecipientType.circle,
              icon: Icon(Icons.groups_outlined),
              label: Text('Circle'),
            ),
            ButtonSegment(
              value: RecipientType.inviteLink,
              icon: Icon(Icons.link_rounded),
              label: Text('One-Time Link'),
            ),
          ],
          selected: {_recipientType},
          onSelectionChanged: (set) =>
              setState(() => _recipientType = set.first),
        ),
        const SizedBox(height: 16),
        if (_recipientType == RecipientType.user) ...[
          // Frequently Shared Contacts Chips
          frequentContactsAsync.maybeWhen(
            data: (contacts) {
              if (contacts.isEmpty) return const SizedBox.shrink();
              final text = _emailController.text.trim();
              if (text.isEmpty && _resolvedUser == null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: FrequentContactChipsRow(
                    contacts: contacts.take(8).toList(),
                    selectedEmail: _selectedContact?.email,
                    onContactSelected: _selectFrequentContact,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Email or Username Search Input
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Recipient Email or @Username *',
              hintText: 'e.g. spouse@example.com or @KYZMPTR',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSearchingUsername)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    if (_emailController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Clear recipient',
                        onPressed: _clearSelectedContact,
                      ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded, size: 20),
                      tooltip: 'Lookup Username',
                      onPressed: () => _searchUsername(_emailController.text),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    tooltip: 'Scan Recipient QR Code',
                    onPressed: _openQrScanner,
                  ),
                ],
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (val) {
              if (!val.contains('@') || val.startsWith('@')) {
                _searchUsername(val);
              }
            },
          ),
          const SizedBox(height: 8),

          // Quick Action Pill Buttons (Scan QR Code & Lookup Username)
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 15),
                label:
                    const Text('Scan QR Code', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openQrScanner,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 15),
                label: const Text('Search Username',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _searchUsername(_emailController.text),
              ),
            ],
          ),

          // Autocomplete suggestion dropdown when typing
          frequentContactsAsync.maybeWhen(
            data: (contacts) {
              final query = _emailController.text.trim();
              if (query.isEmpty ||
                  _selectedContact != null ||
                  _resolvedUser != null) {
                return const SizedBox.shrink();
              }
              final matches =
                  contacts.where((c) => c.matchesQuery(query)).take(5).toList();
              if (matches.isEmpty) return const SizedBox.shrink();

              return FrequentContactSuggestionsCard(
                suggestions: matches,
                onContactSelected: _selectFrequentContact,
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Resolved Verified User Card
          if (_resolvedUser != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.purple.shade100,
                    child: Text(
                      _resolvedUser!.displayName.isNotEmpty
                          ? _resolvedUser!.displayName[0].toUpperCase()
                          : '@',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _resolvedUser!.displayName.isNotEmpty
                                  ? _resolvedUser!.displayName
                                  : '@${_resolvedUser!.username}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                size: 16, color: Colors.teal),
                          ],
                        ),
                        Text(
                          '@${_resolvedUser!.username} • ${_resolvedUser!.email.isNotEmpty ? _resolvedUser!.email : 'MagicDiary Member'}',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.purple.shade800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Clear',
                    onPressed: _clearSelectedContact,
                  ),
                ],
              ),
            ),
          ],

          if (_usernameSearchError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _usernameSearchError!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_selectedContact != null && _resolvedUser == null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: Colors.teal.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Selected from frequent contacts • Shared ${_selectedContact!.useCount} time${_selectedContact!.useCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.teal.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          TextField(
            controller: _recipientNameController,
            decoration: InputDecoration(
              labelText: 'Recipient Name (Optional)',
              hintText: 'e.g. John Doe',
              prefixIcon: const Icon(Icons.badge_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else if (_recipientType == RecipientType.inviteLink) ...[
          // One-Time Deep Link Configuration
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.amber.shade100,
                      child: Icon(Icons.bolt_rounded,
                          color: Colors.amber.shade900, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'One-Time Usable Deep Link',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Generates a single-use deep link with an embedded QR code. It can only be claimed once by one recipient.',
                            style: TextStyle(
                                fontSize: 11.5, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _inviteExpiryDays,
                  decoration: InputDecoration(
                    labelText: 'Link Expiry Duration',
                    prefixIcon:
                        const Icon(Icons.timer_outlined, color: Colors.amber),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Day')),
                    DropdownMenuItem(value: 3, child: Text('3 Days')),
                    DropdownMenuItem(
                        value: 7, child: Text('7 Days (Recommended)')),
                    DropdownMenuItem(value: 30, child: Text('30 Days')),
                    DropdownMenuItem(
                        value: 0, child: Text('Never / No Expiry')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _inviteExpiryDays = val);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Deep link format: https://magicdiary.mahato.in/join/<token>',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ] else ...[
          userCirclesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading circles: $err'),
            data: (circles) {
              if (circles.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.groups_outlined,
                          size: 36, color: Colors.purple),
                      SizedBox(height: 8),
                      Text(
                        'No Magic Circles Found',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Create a Family or Household Circle first, or choose "Individual User".',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCircleId,
                    decoration: InputDecoration(
                      labelText: 'Select Magic Circle *',
                      prefixIcon: const Icon(Icons.groups_outlined,
                          color: Colors.purple),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: circles.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.members.length} members)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final c = circles.firstWhere((x) => x.id == val);
                        setState(() {
                          _selectedCircleId = c.id;
                          _selectedCircleName = c.name;
                          _selectedCircle = c;
                        });
                      }
                    },
                  ),
                  if (_selectedCircle != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share with ${_selectedCircle!.name} now',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Give every current Circle member contributor access to the whole diary, including future records.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _quickShareWithCircle,
                            icon: const Icon(Icons.groups_rounded),
                            label: const Text('Quick share entire diary'),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.purple),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: SHARING MODE (Entire Diary vs Selected Records)
  // ---------------------------------------------------------------------------
  Future<void> _quickShareWithCircle() async {
    if (_selectedCircleId == null) return;
    setState(() {
      _sharingMode = SharingMode.entire;
      _futurePolicy = FutureRecordPolicy.allFuture;
      _permission = SharedDiaryPermission.contributor;
      _expiresAt = null;
      _allowAttachments = true;
      _allowComments = true;
      _allowExport = false;
      _restrictedFields = [];
    });
    await _saveShare();
  }

  Widget _buildStep2SharingMode(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Choose Sharing Mode',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'Decide whether to share the full diary or only specific, hand-picked records.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // Option A: Share Entire Diary
        _buildModeCard(
          mode: SharingMode.entire,
          title: SharingMode.entire.label,
          description: SharingMode.entire.description,
          icon: Icons.menu_book_rounded,
          color: Colors.teal,
          isSelected: _sharingMode == SharingMode.entire,
        ),

        const SizedBox(height: 12),

        // Option B: Share Selected Records
        _buildModeCard(
          mode: SharingMode.selected,
          title: SharingMode.selected.label,
          description: SharingMode.selected.description,
          icon: Icons.checklist_rtl_rounded,
          color: Colors.indigo,
          isSelected: _sharingMode == SharingMode.selected,
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required SharingMode mode,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return Card(
      elevation: isSelected ? 2 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _sharingMode = mode),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSelected ? color : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle, color: color, size: 20),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: SCOPE & RECORD SELECTION
  // ---------------------------------------------------------------------------
  Widget _buildStep3Scope(Color color) {
    final user = ref.watch(userProfileProvider);

    if (_sharingMode == SharingMode.entire) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 3: Future Record Sharing Policy',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'How should new records created in this diary be handled in the future?',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ...FutureRecordPolicy.values.map((policy) {
            final isSelected = _futurePolicy == policy;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: isSelected ? 1.5 : 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 0.8,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _futurePolicy = policy),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected ? color : Colors.grey.shade500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(policy.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(policy.description,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    // Selected Mode: Open Record Selection
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Choose Records to Share',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'Only explicitly chosen records will be accessible. All other records remain strictly private.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_box_outlined,
                      color: Colors.indigo, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedRecordIds.length} Records Selected',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.indigo),
                        ),
                        Text(
                          _selectedRecordIds.isEmpty
                              ? 'Tap below to select which records to share'
                              : 'Ready to share with recipient',
                          style: TextStyle(
                              fontSize: 12, color: Colors.indigo.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text(_selectedRecordIds.isEmpty
                      ? 'Select Records Now'
                      : 'Modify Record Selection'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () async {
                    if (user == null) return;
                    final result = await Navigator.push<List<String>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordSelectionScreen(
                          diaryId: widget.initialDiary.id,
                          ownerUid: user.uid,
                          initiallySelectedRecordIds: _selectedRecordIds,
                          currentShareId: widget.initialShare?.id,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() => _selectedRecordIds = result.toSet());
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 4: PERMISSIONS
  // ---------------------------------------------------------------------------
  Widget _buildStep4Permissions(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 4: Configure Access Permission',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'Determine what actions the recipient can perform on the shared records.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ...SharedDiaryPermission.values.map((p) {
          final isSelected = _permission == p;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: isSelected ? 1.5 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _permission = p),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? color : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(_getPermissionExplanation(p),
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _getPermissionExplanation(SharedDiaryPermission p) {
    switch (p) {
      case SharedDiaryPermission.viewer:
        return 'Can view authorized records. Cannot add, edit, or delete anything.';
      case SharedDiaryPermission.contributor:
        return 'Can view records and add new records. Can only edit their own contributed entries.';
      case SharedDiaryPermission.editor:
        return 'Can view, add, and modify authorized diary records.';
      case SharedDiaryPermission.admin:
        return 'Full access including managing delegated sharing. (Owner retains root ownership).';
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 5: EXPIRY & RESTRICTIONS
  // ---------------------------------------------------------------------------
  Widget _buildStep5ExpiryAndRestrictions(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 5: Expiration & Safeguards',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'Configure optional access expiration and granular privacy toggles.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // Expiry Picker
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          leading: const Icon(Icons.timer_outlined, color: Colors.deepOrange),
          title: const Text('Access Expiry Date',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(
            _expiresAt != null
                ? 'Expires on ${DateFormat('dd MMM yyyy').format(_expiresAt!)}'
                : 'Never expires (Permanent access)',
            style: TextStyle(
                fontSize: 12,
                color: _expiresAt != null
                    ? Colors.deepOrange
                    : Colors.grey.shade600),
          ),
          trailing: _expiresAt != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _expiresAt = null),
                )
              : const Icon(Icons.calendar_month, size: 20),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (picked != null) {
              setState(() => _expiresAt = picked);
            }
          },
        ),

        const SizedBox(height: 14),

        // Safeguard Switches
        SwitchListTile(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200)),
          title: const Text('Allow Attachments Access',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: const Text(
              'Recipient can view & download documents and invoice images',
              style: TextStyle(fontSize: 11.5)),
          value: _allowAttachments,
          onChanged: (val) => setState(() => _allowAttachments = val),
        ),

        const SizedBox(height: 8),

        SwitchListTile(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200)),
          title: const Text('Allow Comments & Collaboration',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: const Text('Permit recipient to post comments on records',
              style: TextStyle(fontSize: 11.5)),
          value: _allowComments,
          onChanged: (val) => setState(() => _allowComments = val),
        ),

        const SizedBox(height: 8),

        SwitchListTile(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200)),
          title: const Text('Allow Report Export',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: const Text(
              'Allow recipient to export shared data as PDF/Excel',
              style: TextStyle(fontSize: 11.5)),
          value: _allowExport,
          onChanged: (val) => setState(() => _allowExport = val),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 6: PREVIEW & CONFIRM
  // ---------------------------------------------------------------------------
  Widget _buildStep6Preview(Color color) {
    final diary = widget.initialDiary;
    final String destinationLabel;
    final IconData destinationIcon;

    if (_recipientType == RecipientType.inviteLink) {
      destinationLabel = _inviteExpiryDays == 0
          ? 'One-Time Invite Deep Link (No Expiry)'
          : 'One-Time Invite Deep Link ($_inviteExpiryDays days)';
      destinationIcon = Icons.link_rounded;
    } else if (_recipientType == RecipientType.user) {
      if (_resolvedUser != null) {
        destinationLabel =
            '@${_resolvedUser!.username} (${_resolvedUser!.displayName.isNotEmpty ? _resolvedUser!.displayName : _resolvedUser!.email})';
      } else {
        destinationLabel = _emailController.text.trim().toLowerCase();
      }
      destinationIcon = Icons.person;
    } else {
      destinationLabel = _selectedCircleName ?? 'Magic Circle';
      destinationIcon = Icons.groups;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 6: Preview Access & Confirm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'Review exactly what will be shared before saving.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPreviewRow(Icons.auto_stories, 'Diary', diary.name),
                const Divider(height: 16),
                _buildPreviewRow(
                  destinationIcon,
                  'Destination',
                  destinationLabel,
                ),
                const Divider(height: 16),
                _buildPreviewRow(
                  Icons.layers_outlined,
                  'Sharing Mode',
                  _sharingMode == SharingMode.entire
                      ? 'Entire Diary'
                      : '${_selectedRecordIds.length} Selected Records',
                ),
                if (_sharingMode == SharingMode.entire) ...[
                  const Divider(height: 16),
                  _buildPreviewRow(
                    Icons.update_outlined,
                    'Future Records',
                    _futurePolicy.label,
                  ),
                ],
                const Divider(height: 16),
                _buildPreviewRow(
                  Icons.lock_person_outlined,
                  'Permission',
                  _permission.label,
                ),
                const Divider(height: 16),
                _buildPreviewRow(
                  Icons.timer_outlined,
                  'Expiration',
                  _expiresAt != null
                      ? DateFormat('dd MMM yyyy').format(_expiresAt!)
                      : 'Never (Permanent)',
                ),
                const Divider(height: 16),
                _buildPreviewRow(
                  Icons.attach_file,
                  'Attachments',
                  _allowAttachments ? 'Allowed' : 'Restricted',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _onNextOrConfirm() async {
    // Validate Step 1
    if (_currentStep == 1) {
      if (_recipientType == RecipientType.inviteLink) {
        // No pre-selected recipient needed for one-time deep links
      } else if (_recipientType == RecipientType.user) {
        final input = _emailController.text.trim();
        final currentUser = ref.read(userProfileProvider);

        if (input.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Please enter a recipient username or email address')),
          );
          return;
        }

        // If input looks like a username (@alice or plain alice without a dot or domain)
        final isUsername = input.startsWith('@') ||
            (!input.contains('@') && !input.contains('.'));
        if (isUsername) {
          if (_resolvedUser == null) {
            await _searchUsername(input);
            if (!mounted) return;
          }
          if (_resolvedUser == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(_usernameSearchError ??
                      'Please search and select a verified username')),
            );
            return;
          }
          if (currentUser != null && _resolvedUser!.uid == currentUser.uid) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('You cannot share a diary with yourself')),
            );
            return;
          }
        } else {
          final email = input.toLowerCase();
          if (!email.contains('@') || !email.contains('.')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Please enter a valid recipient email address')),
            );
            return;
          }
          final user = ref.read(userProfileProvider);
          if (user != null && email == user.email.trim().toLowerCase()) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('You cannot share a diary with your own email')),
            );
            return;
          }
        }
      } else {
        if (_selectedCircleId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select a Magic Circle to share with')),
          );
          return;
        }
      }
    }

    // Validate Step 3 for Selected Mode
    if (_currentStep == 3 && _sharingMode == SharingMode.selected) {
      if (_selectedRecordIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select at least 1 record to share')),
        );
        return;
      }
    }

    if (_currentStep < 6) {
      setState(() => _currentStep++);
      return;
    }

    // Step 6 Confirm & Save
    await _saveShare();
  }

  Future<void> _saveShare() async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final ownerName = _shareOwnerName(user);

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(sharedDiaryRepositoryProvider);
      final diary = widget.initialDiary;

      if (_recipientType == RecipientType.inviteLink) {
        final token = const Uuid().v4();
        final inviteExpiresAt = _inviteExpiryDays > 0
            ? DateTime.now().add(Duration(days: _inviteExpiryDays))
            : null;

        final invite = OneTimeShareInvite(
          id: token,
          diaryId: diary.id,
          diaryName: diary.name,
          ownerUid: user.uid,
          ownerName: ownerName,
          permission: _permission,
          sharingMode: _sharingMode,
          grantedRecordIds: _sharingMode == SharingMode.selected
              ? _selectedRecordIds.toList()
              : const [],
          restrictedFields: _restrictedFields,
          allowAttachments: _allowAttachments,
          allowComments: _allowComments,
          allowExport: _allowExport,
          createdAt: DateTime.now(),
          expiresAt: inviteExpiresAt,
        );

        await repo.createOneTimeShareInvite(invite);

        if (mounted) {
          Navigator.pop(context);
          await InviteLinkReadyDialog.show(context, invite);
        }
        return;
      } else if (_recipientType == RecipientType.user) {
        final String email;
        final String recipientName;
        final String recipientUid;

        if (_resolvedUser != null) {
          email = _resolvedUser!.email.isNotEmpty
              ? _resolvedUser!.email.toLowerCase()
              : '${_resolvedUser!.username.toLowerCase()}@magicdiary.internal';
          recipientName = _resolvedUser!.displayName.isNotEmpty
              ? _resolvedUser!.displayName
              : '@${_resolvedUser!.username}';
          recipientUid = _resolvedUser!.uid;
        } else {
          final rawInput = _emailController.text.trim().toLowerCase();
          email = rawInput.contains('@') && rawInput.contains('.')
              ? rawInput
              : '${rawInput.replaceAll('@', '')}@magicdiary.internal';
          recipientName = _recipientNameController.text.trim().isNotEmpty
              ? _recipientNameController.text.trim()
              : rawInput.replaceAll('@', '');
          recipientUid = widget.initialShare?.sharedWithUid ?? 'pending_$email';
        }

        final shareId = widget.initialShare?.id ??
            SharedDiaryRepository.generateShareId(
              ownerUid: user.uid,
              diaryId: diary.id,
              target: _resolvedUser != null ? recipientUid : email,
            );

        final share = SharedDiaryAccess(
          id: shareId,
          diaryId: diary.id,
          diaryName: diary.name,
          ownerUid: user.uid,
          ownerName: ownerName,
          recipientType: RecipientType.user,
          sharingMode: _sharingMode,
          futureRecordPolicy: _futurePolicy,
          snapshotCutoffTime: _futurePolicy == FutureRecordPolicy.existingOnly
              ? (widget.initialShare?.snapshotCutoffTime ?? DateTime.now())
              : null,
          sharedWithUid: recipientUid,
          sharedWithEmail: email,
          sharedWithName: recipientName,
          permission: _permission,
          shareEntireDiary: _sharingMode == SharingMode.entire,
          grantedRecordIds: _sharingMode == SharingMode.selected
              ? _selectedRecordIds.toList()
              : const [],
          allowAttachments: _allowAttachments,
          allowComments: _allowComments,
          allowExport: _allowExport,
          restrictedFields: _restrictedFields,
          status: ShareStatus.active,
          expiresAt: _expiresAt,
          createdAt: widget.initialShare?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repo.createShareAccess(share);

        // Maintain and record frequent contact usage for future lookup suggestions
        try {
          await ref.read(frequentContactsRepositoryProvider).recordContactUsage(
                userId: user.uid,
                email: email,
                name: recipientName,
                username: _resolvedUser?.username ?? _selectedContact?.username,
              );
        } catch (e) {
          debugPrint('Note recording frequent contact: $e');
        }
      } else {
        // Circle members read using their UID/email. Access remains per member;
        // the Circle document only indexes which diaries appear in its UI.
        final circleId = _selectedCircleId!;
        final circleName = _selectedCircleName ?? 'Circle';

        MagicCircle? circle = _selectedCircle;
        if (circle == null) {
          final availableCircles = ref.read(userCirclesStreamProvider).value;
          if (availableCircles != null) {
            for (final candidate in availableCircles) {
              if (candidate.id == circleId) {
                circle = candidate;
                break;
              }
            }
          }
        }

        if (circle == null) {
          throw Exception(
              'Could not load the selected Circle. Please try again.');
        }
        final selectedCircle = circle;

        // 1. Canonical Circle Share Access Record (guarantees circle-level indexing)
        final circleShareId = SharedDiaryRepository.generateShareId(
          ownerUid: user.uid,
          diaryId: diary.id,
          target: circleId,
        );

        final circleShare = SharedDiaryAccess(
          id: circleShareId,
          diaryId: diary.id,
          diaryName: diary.name,
          ownerUid: user.uid,
          ownerName: ownerName,
          circleId: circleId,
          circleName: circleName,
          recipientType: RecipientType.circle,
          sharingMode: _sharingMode,
          futureRecordPolicy: _futurePolicy,
          snapshotCutoffTime: _futurePolicy == FutureRecordPolicy.existingOnly
              ? (widget.initialShare?.snapshotCutoffTime ?? DateTime.now())
              : null,
          sharedWithUid: circleId,
          sharedWithEmail: '$circleId@magicdiary.internal',
          sharedWithName: circleName,
          permission: _permission,
          shareEntireDiary: _sharingMode == SharingMode.entire,
          grantedRecordIds: _sharingMode == SharingMode.selected
              ? _selectedRecordIds.toList()
              : const [],
          allowAttachments: _allowAttachments,
          allowComments: _allowComments,
          allowExport: _allowExport,
          restrictedFields: _restrictedFields,
          status: ShareStatus.active,
          expiresAt: _expiresAt,
          createdAt: widget.initialShare?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repo.createShareAccess(circleShare);

        // 2. Per-member access records so each circle member receives granular permissions
        final recipients = selectedCircle.members
            .where((member) =>
                member.status != 'inactive' &&
                member.status != 'removed' &&
                member.uid != user.uid)
            .toList();

        for (final member in recipients) {
          final cleanEmail = member.email.trim().toLowerCase();
          final email = cleanEmail.isNotEmpty
              ? cleanEmail
              : '${member.displayName.isNotEmpty ? member.displayName.replaceAll(' ', '_').toLowerCase() : (member.uid.isNotEmpty ? member.uid : 'member')}@magicdiary.internal';
          final recipientUid = member.uid.isNotEmpty
              ? member.uid
              : (cleanEmail.isNotEmpty
                  ? 'pending_$cleanEmail'
                  : 'pending_$email');
          if (recipientUid.isEmpty) continue;

          await repo.createShareAccess(
            circleShare.copyWith(
              id: SharedDiaryRepository.generateShareId(
                ownerUid: user.uid,
                diaryId: diary.id,
                target: email.isNotEmpty ? email : recipientUid,
              ),
              sharedWithUid: recipientUid,
              sharedWithEmail: email,
              sharedWithName: member.displayName,
            ),
          );
        }

        // 3. Keep circle.sharedDiaryIds in sync on the Circle document
        try {
          await ref.read(magicCircleRepositoryProvider).updateCircle(
                selectedCircle.copyWith(
                  sharedDiaryIds:
                      {...selectedCircle.sharedDiaryIds, diary.id}.toList(),
                  updatedAt: DateTime.now(),
                ),
              );
        } catch (e) {
          debugPrint('Could not update Circle diary index: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sharingMode == SharingMode.entire
                  ? 'Entire diary "${diary.name}" shared successfully!'
                  : '${_selectedRecordIds.length} records in "${diary.name}" shared successfully!',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share diary: $e')),
        );
      }
    }
  }

  String _shareOwnerName(UserProfile user) {
    final displayName = user.displayName.trim();
    if (displayName.isNotEmpty) return displayName;
    final username = user.username.trim();
    if (username.isNotEmpty) return '@$username';
    final email = user.email.trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Diary owner';
  }
}
