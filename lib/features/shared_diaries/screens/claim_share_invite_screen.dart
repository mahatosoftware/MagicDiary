import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/providers/app_providers.dart';
import '../models/shared_diary_models.dart';
import '../repositories/frequent_contacts_repository.dart';
import '../repositories/shared_diary_repository.dart';

class ClaimShareInviteScreen extends ConsumerStatefulWidget {
  final String token;

  const ClaimShareInviteScreen({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<ClaimShareInviteScreen> createState() => _ClaimShareInviteScreenState();
}

class _ClaimShareInviteScreenState extends ConsumerState<ClaimShareInviteScreen> {
  bool _isLoading = true;
  bool _isClaiming = false;
  OneTimeShareInvite? _invite;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(sharedDiaryRepositoryProvider);
      final invite = await repo.getShareInvite(widget.token);
      if (mounted) {
        setState(() {
          _invite = invite;
          _isLoading = false;
          if (invite == null) {
            _errorMessage = 'Invite link not found or has been revoked.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load invite: $e';
        });
      }
    }
  }

  Future<void> _claimInvite() async {
    final user = ref.read(userProfileProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first to claim this invitation.')),
      );
      return;
    }

    if (_invite == null) return;

    setState(() => _isClaiming = true);

    try {
      final repo = ref.read(sharedDiaryRepositoryProvider);
      final shareAccess = await repo.claimOneTimeInvite(
        token: widget.token,
        recipientUser: user,
      );

      // Record frequent contact usage for mutual fast lookup
      try {
        await ref.read(frequentContactsRepositoryProvider).recordContactUsage(
              userId: user.uid,
              email: _invite!.ownerUid, // owner reference
              name: _invite!.ownerName,
            );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access to "${_invite!.diaryName}" successfully claimed!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        // Navigate to the shared diary
        context.go(
          '/diary-records/${_invite!.diaryId}?ownerId=${_invite!.ownerUid}&ownerName=${Uri.encodeComponent(_invite!.ownerName)}',
          extra: shareAccess,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClaiming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
        _loadInvite();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(userProfileProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diary Invitation')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying one-time invite link...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _invite == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invalid Invitation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off_rounded, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Invalid or Expired Link',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'This invite link is invalid.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Return to Home'),
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final invite = _invite!;
    final diaryDef = DiaryRegistry.getDiaryById(invite.diaryId);
    final diaryColor = diaryDef?.color ?? Colors.teal;
    final diaryIcon = diaryDef?.icon ?? Icons.menu_book_rounded;
    final isOwner = currentUser?.uid == invite.ownerUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Diary Invitation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Diary Badge Icon
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: diaryColor.withValues(alpha: 0.15),
                      child: Icon(diaryIcon, color: diaryColor, size: 36),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      invite.diaryName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),

                    // Inviter
                    Text(
                      'Shared by ${invite.ownerName}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),

                    // One-Time Usable Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 4),
                          Text(
                            'One-Time Usable Deep Link',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Divider(),
                    const SizedBox(height: 12),

                    // Details Breakdown
                    _buildDetailRow(
                      icon: Icons.security_rounded,
                      label: 'Permission Level',
                      value: invite.permission.label,
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: Icons.tune_rounded,
                      label: 'Sharing Mode',
                      value: invite.sharingMode == SharingMode.entire
                          ? 'Entire Diary'
                          : '${invite.grantedRecordIds.length} Selected Records',
                    ),
                    if (invite.expiresAt != null) ...[
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        icon: Icons.timer_outlined,
                        label: 'Link Expires',
                        value: DateFormat.yMMMd().add_jm().format(invite.expiresAt!),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Status Banners & Actions
                    if (invite.isClaimed) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This one-time invite has already been claimed by ${invite.claimedByName ?? 'a recipient'} and cannot be reused.',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (invite.isExpired) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.timer_off_outlined, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This invitation link has expired.',
                                style: TextStyle(fontSize: 12.5, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isOwner) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You created this invitation link. Share the link or QR code with your recipient.',
                                style: TextStyle(fontSize: 12.5, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Ready to claim button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: _isClaiming
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _isClaiming ? 'Claiming Access...' : 'Accept & Claim Access',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isClaiming ? null : _claimInvite,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextButton(
                      child: const Text('Back to Shared Diaries'),
                      onPressed: () => context.go('/shared-diaries'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
