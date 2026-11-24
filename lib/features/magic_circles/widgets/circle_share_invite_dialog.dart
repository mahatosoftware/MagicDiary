import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/magic_circle_models.dart';
import '../screens/magic_circles_screen.dart';

class CircleShareInviteDialog extends ConsumerStatefulWidget {
  final MagicCircle circle;
  final bool isAdmin;

  const CircleShareInviteDialog({
    super.key,
    required this.circle,
    this.isAdmin = false,
  });

  static Future<void> show(
    BuildContext context, {
    required MagicCircle circle,
    bool isAdmin = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CircleShareInviteDialog(
        circle: circle,
        isAdmin: isAdmin,
      ),
    );
  }

  @override
  ConsumerState<CircleShareInviteDialog> createState() =>
      _CircleShareInviteDialogState();
}

class _CircleShareInviteDialogState
    extends ConsumerState<CircleShareInviteDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MagicCircle _currentCircle;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _currentCircle = widget.circle;
    _tabController = TabController(length: widget.isAdmin ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _shareInvite(
    BuildContext buttonContext, {
    bool isOneTime = false,
    String? oneTimeCode,
  }) async {
    // 1. Synchronously resolve iPad/tablet popover bounding box before async gap
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final codeToShare = isOneTime ? oneTimeCode! : _currentCircle.code;
    final joinLink = 'https://magicdiary.mahato.in/join/$codeToShare';
    final message = isOneTime
        ? '🎉 Special one-time VIP invite to join "${_currentCircle.name}" on Magic Diary!\n\n'
            'Tap link to join directly:\n$joinLink\n\n'
            '(Or enter VIP code in app: $codeToShare)'
        : '👋 Join "${_currentCircle.name}" on Magic Diary!\n\n'
            'Tap link: $joinLink\n\n'
            '(Code: $codeToShare • Requires admin approval)';

    // 2. Immediate clipboard fallback
    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // 3. Platform native share sheet
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          title: 'Join ${_currentCircle.name}',
          subject: 'Join ${_currentCircle.name}',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      debugPrint('Native share sheet error: $e');
    }
  }

  Future<void> _generateOneTimeCode() async {
    setState(() => _isGenerating = true);
    try {
      final repo = ref.read(magicCircleRepositoryProvider);
      final newCode = await repo.generateOneTimeCode(_currentCircle.id);
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _currentCircle = _currentCircle.copyWith(
            oneTimeCodes: [..._currentCircle.oneTimeCodes, newCode],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated One-Time VIP Code: $newCode')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate code: $e')),
        );
      }
    }
  }

  Future<void> _revokeOneTimeCode(String code) async {
    try {
      final repo = ref.read(magicCircleRepositoryProvider);
      await repo.deleteOneTimeCode(_currentCircle.id, code);
      if (mounted) {
        setState(() {
          _currentCircle = _currentCircle.copyWith(
            oneTimeCodes:
                _currentCircle.oneTimeCodes.where((c) => c != code).toList(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code revoked successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke code: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joinLink =
        'https://magicdiary.mahato.in/join/${_currentCircle.code}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.deepPurple.shade50,
                    child: const Icon(Icons.share_rounded,
                        color: Colors.deepPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentCircle.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentCircle.category.label,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            if (widget.isAdmin)
              TabBar(
                controller: _tabController,
                labelColor: Colors.deepPurple,
                indicatorColor: Colors.deepPurple,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.qr_code_rounded),
                    text: 'Standard QR',
                  ),
                  Tab(
                    icon: Icon(Icons.flash_on_rounded),
                    text: 'One-Time VIP',
                  ),
                ],
              ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Standard Permanent Code & QR
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // QR View
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: joinLink,
                            version: QrVersions.auto,
                            size: 180.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Code Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.deepPurple.shade100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'CODE: ',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple),
                              ),
                              Text(
                                _currentCircle.code.isNotEmpty
                                    ? _currentCircle.code
                                    : '------',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: _currentCircle.code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Code copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.copy_rounded,
                                    size: 18, color: Colors.deepPurple),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Members joining with this code will enter your approval queue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),

                        // Share Button
                        Builder(
                          builder: (btnCtx) => FilledButton.icon(
                            onPressed: () => _shareInvite(btnCtx),
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Share Invite Link & QR',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: One-Time VIP Codes (Direct Join)
                  if (widget.isAdmin)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt_rounded,
                                    color: Colors.amber.shade900),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'One-time VIP codes grant instant membership and are automatically burned upon first use.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed:
                                _isGenerating ? null : _generateOneTimeCode,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.add_rounded),
                            label: const Text('Generate New One-Time VIP Code'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Active One-Time Codes',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _currentCircle.oneTimeCodes.isEmpty
                                ? Center(
                                    child: Text(
                                      'No active VIP codes.\nTap above to generate one.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount:
                                        _currentCircle.oneTimeCodes.length,
                                    itemBuilder: (context, index) {
                                      final code =
                                          _currentCircle.oneTimeCodes[index];
                                      return Card(
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          side: BorderSide(
                                              color: Colors.grey.shade200),
                                        ),
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          dense: true,
                                          title: Text(
                                            code,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          subtitle: const Text('Instant entry',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Builder(
                                                builder: (btnCtx) => IconButton(
                                                  icon: const Icon(
                                                      Icons.share_rounded,
                                                      size: 18),
                                                  tooltip: 'Share VIP code',
                                                  onPressed: () => _shareInvite(
                                                    btnCtx,
                                                    isOneTime: true,
                                                    oneTimeCode: code,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 18,
                                                    color: Colors.red),
                                                tooltip: 'Revoke VIP code',
                                                onPressed: () =>
                                                    _revokeOneTimeCode(code),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
