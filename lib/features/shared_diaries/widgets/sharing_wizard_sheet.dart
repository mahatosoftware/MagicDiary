import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/diary_registry/diary_definition.dart';
import '../../../core/providers/app_providers.dart';
import '../../magic_circles/screens/magic_circles_screen.dart';
import '../models/shared_diary_models.dart';
import '../repositories/shared_diary_repository.dart';
import '../screens/record_selection_screen.dart';

class SharingWizardSheet extends ConsumerStatefulWidget {
  final DiaryDefinition initialDiary;
  final SharedDiaryAccess? initialShare; // If editing an existing share

  const SharingWizardSheet({
    super.key,
    required this.initialDiary,
    this.initialShare,
  });

  static Future<void> show(BuildContext context, DiaryDefinition diary, {SharedDiaryAccess? share}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SharingWizardSheet(initialDiary: diary, initialShare: share),
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
  final TextEditingController _recipientNameController = TextEditingController();
  String? _selectedCircleId;
  String? _selectedCircleName;

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
  }

  @override
  void dispose() {
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
                      widget.initialShare != null ? 'Edit Diary Share' : 'Share Diary',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${diary.name} • Step $_currentStep of 6',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _onNextOrConfirm,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          _currentStep == 6 ? (widget.initialShare != null ? 'Update Share' : 'Confirm & Share') : 'Continue',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
  // STEP 1: DESTINATION (User or Circle)
  // ---------------------------------------------------------------------------
  Widget _buildStep1Destination(Color color) {
    final userCirclesAsync = ref.watch(userCirclesStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Choose Sharing Destination',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'Share with an individual person via email, or collaborate with an entire Magic Circle.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        SegmentedButton<RecipientType>(
          segments: const [
            ButtonSegment(
              value: RecipientType.user,
              icon: Icon(Icons.person_outline),
              label: Text('Individual User'),
            ),
            ButtonSegment(
              value: RecipientType.circle,
              icon: Icon(Icons.groups_outlined),
              label: Text('Magic Circle'),
            ),
          ],
          selected: {_recipientType},
          onSelectionChanged: (set) => setState(() => _recipientType = set.first),
        ),

        const SizedBox(height: 16),

        if (_recipientType == RecipientType.user) ...[
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Recipient Email Address *',
              hintText: 'e.g. spouse@example.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recipientNameController,
            decoration: InputDecoration(
              labelText: 'Recipient Name (Optional)',
              hintText: 'e.g. John Doe',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      Icon(Icons.groups_outlined, size: 36, color: Colors.purple),
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

              return DropdownButtonFormField<String>(
                initialValue: _selectedCircleId,
                decoration: InputDecoration(
                  labelText: 'Select Magic Circle *',
                  prefixIcon: const Icon(Icons.groups_outlined, color: Colors.purple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    });
                  }
                },
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
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? color : Colors.grey.shade500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(policy.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(policy.description, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
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
                  const Icon(Icons.check_box_outlined, color: Colors.indigo, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedRecordIds.length} Records Selected',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                        ),
                        Text(
                          _selectedRecordIds.isEmpty
                              ? 'Tap below to select which records to share'
                              : 'Ready to share with recipient',
                          style: TextStyle(fontSize: 12, color: Colors.indigo.shade700),
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
                  label: Text(_selectedRecordIds.isEmpty ? 'Select Records Now' : 'Modify Record Selection'),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? color : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(_getPermissionExplanation(p), style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
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
          title: const Text('Access Expiry Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(
            _expiresAt != null ? 'Expires on ${DateFormat('dd MMM yyyy').format(_expiresAt!)}' : 'Never expires (Permanent access)',
            style: TextStyle(fontSize: 12, color: _expiresAt != null ? Colors.deepOrange : Colors.grey.shade600),
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
              initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          title: const Text('Allow Attachments Access', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: const Text('Recipient can view & download documents and invoice images', style: TextStyle(fontSize: 11.5)),
          value: _allowAttachments,
          onChanged: (val) => setState(() => _allowAttachments = val),
        ),

        const SizedBox(height: 8),

        SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          title: const Text('Allow Comments & Collaboration', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: const Text('Permit recipient to post comments on records', style: TextStyle(fontSize: 11.5)),
          value: _allowComments,
          onChanged: (val) => setState(() => _allowComments = val),
        ),

        const SizedBox(height: 8),

        SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          title: const Text('Allow Report Export', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
          subtitle: const Text('Allow recipient to export shared data as PDF/Excel', style: TextStyle(fontSize: 11.5)),
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
    final destinationLabel = _recipientType == RecipientType.user
        ? _emailController.text.trim().toLowerCase()
        : (_selectedCircleName ?? 'Magic Circle');

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
                  _recipientType == RecipientType.user ? Icons.person : Icons.groups,
                  'Destination',
                  destinationLabel,
                ),
                const Divider(height: 16),
                _buildPreviewRow(
                  Icons.layers_outlined,
                  'Sharing Mode',
                  _sharingMode == SharingMode.entire ? 'Entire Diary' : '${_selectedRecordIds.length} Selected Records',
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
                  _expiresAt != null ? DateFormat('dd MMM yyyy').format(_expiresAt!) : 'Never (Permanent)',
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
        Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
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
      if (_recipientType == RecipientType.user) {
        final email = _emailController.text.trim().toLowerCase();
        if (email.isEmpty || !email.contains('@')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid recipient email address')),
          );
          return;
        }
        final user = ref.read(userProfileProvider);
        if (user != null && email == user.email.trim().toLowerCase()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You cannot share a diary with your own email')),
          );
          return;
        }
      } else {
        if (_selectedCircleId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a Magic Circle to share with')),
          );
          return;
        }
      }
    }

    // Validate Step 3 for Selected Mode
    if (_currentStep == 3 && _sharingMode == SharingMode.selected) {
      if (_selectedRecordIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least 1 record to share')),
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

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(sharedDiaryRepositoryProvider);
      final diary = widget.initialDiary;

      if (_recipientType == RecipientType.user) {
        final email = _emailController.text.trim().toLowerCase();
        final recipientName = _recipientNameController.text.trim().isNotEmpty
            ? _recipientNameController.text.trim()
            : email.split('@').first;

        final shareId = widget.initialShare?.id ??
            SharedDiaryRepository.generateShareId(
              ownerUid: user.uid,
              diaryId: diary.id,
              target: email,
            );

        final share = SharedDiaryAccess(
          id: shareId,
          diaryId: diary.id,
          diaryName: diary.name,
          ownerUid: user.uid,
          ownerName: user.displayName,
          recipientType: RecipientType.user,
          sharingMode: _sharingMode,
          futureRecordPolicy: _futurePolicy,
          snapshotCutoffTime: _futurePolicy == FutureRecordPolicy.existingOnly
              ? (widget.initialShare?.snapshotCutoffTime ?? DateTime.now())
              : null,
          sharedWithUid: widget.initialShare?.sharedWithUid ?? 'pending_$email',
          sharedWithEmail: email,
          sharedWithName: recipientName,
          permission: _permission,
          shareEntireDiary: _sharingMode == SharingMode.entire,
          grantedRecordIds: _sharingMode == SharingMode.selected ? _selectedRecordIds.toList() : const [],
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
      } else {
        // Circle Sharing: Provision Circle share access
        final circleId = _selectedCircleId!;
        final circleName = _selectedCircleName ?? 'Circle';

        final shareId = widget.initialShare?.id ??
            SharedDiaryRepository.generateShareId(
              ownerUid: user.uid,
              diaryId: diary.id,
              target: 'circle_$circleId',
            );

        final circleShare = SharedDiaryAccess(
          id: shareId,
          diaryId: diary.id,
          diaryName: diary.name,
          ownerUid: user.uid,
          ownerName: user.displayName,
          circleId: circleId,
          circleName: circleName,
          recipientType: RecipientType.circle,
          sharingMode: _sharingMode,
          futureRecordPolicy: _futurePolicy,
          snapshotCutoffTime: _futurePolicy == FutureRecordPolicy.existingOnly
              ? (widget.initialShare?.snapshotCutoffTime ?? DateTime.now())
              : null,
          sharedWithUid: 'circle_$circleId',
          sharedWithEmail: '$circleId@circle.internal',
          sharedWithName: circleName,
          permission: _permission,
          shareEntireDiary: _sharingMode == SharingMode.entire,
          grantedRecordIds: _sharingMode == SharingMode.selected ? _selectedRecordIds.toList() : const [],
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
}

