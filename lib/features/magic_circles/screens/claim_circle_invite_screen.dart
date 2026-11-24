import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/security/circle_permission_service.dart';
import '../models/magic_circle_models.dart';
import 'magic_circles_screen.dart';

class ClaimCircleInviteScreen extends ConsumerStatefulWidget {
  final String token;

  const ClaimCircleInviteScreen({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<ClaimCircleInviteScreen> createState() => _ClaimCircleInviteScreenState();
}

class _ClaimCircleInviteScreenState extends ConsumerState<ClaimCircleInviteScreen> {
  bool _isLoading = true;
  bool _isClaiming = false;
  CircleInvitation? _invitation;
  MagicCircle? _circle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Check authentication state
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please sign in to Magic Diary to view and join this Circle.';
        });
      }
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final repo = ref.read(magicCircleRepositoryProvider);

      // 1. Primary lookup: Permanent Circle Code or One-Time VIP Code
      final byCode = await repo.getCircleByCode(widget.token);
      if (byCode != null) {
        if (mounted) {
          setState(() {
            _circle = byCode;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Direct Circle ID lookup
      try {
        final circleDoc = await firestore.collection('circles').doc(widget.token).get();
        if (circleDoc.exists && circleDoc.data() != null) {
          if (mounted) {
            setState(() {
              _circle = MagicCircle.fromMap(circleDoc.data()!, circleDoc.id);
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {}

      // 3. Document ID lookup in circle_invitations
      try {
        final invDoc = await firestore.collection('circle_invitations').doc(widget.token).get();
        if (invDoc.exists && invDoc.data() != null) {
          final inv = CircleInvitation.fromMap(invDoc.data()!, invDoc.id);
          _invitation = inv;

          final cDoc = await firestore.collection('circles').doc(inv.circleId).get();
          if (cDoc.exists && cDoc.data() != null) {
            if (mounted) {
              setState(() {
                _circle = MagicCircle.fromMap(cDoc.data()!, cDoc.id);
                _isLoading = false;
              });
            }
            return;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invitation not found or code has expired.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load invitation: $e';
        });
      }
    }
  }

  Future<void> _joinCircle() async {
    final user = ref.read(userProfileProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first to join this Circle.')),
      );
      return;
    }

    if (_circle == null) return;

    // Check if already member
    if (_circle!.memberUids.contains(user.uid) ||
        _circle!.members.any((m) => m.uid == user.uid)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already a member of this Circle!')),
        );
        context.go('/circles/${_circle!.id}');
      }
      return;
    }

    setState(() => _isClaiming = true);

    try {
      final repo = ref.read(magicCircleRepositoryProvider);
      final cleanToken = widget.token.trim().toUpperCase();

      // Case A: One-time VIP invite code -> Atomic redemption & burn
      if (_circle!.oneTimeCodes.contains(cleanToken)) {
        await repo.joinWithOneTimeCode(
          _circle!.id,
          user.uid,
          cleanToken,
          email: user.email,
          displayName: user.displayName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined ${_circle!.name} successfully via VIP invite!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
          context.go('/circles/${_circle!.id}');
        }
        return;
      }

      // Case B: General circle code without individual invitation -> Route to pending approval
      if (_invitation == null && _circle!.code == cleanToken) {
        await repo.requestJoin(_circle!.id, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Join request sent to "${_circle!.name}"! An admin will review it.'),
              backgroundColor: Colors.deepPurple,
            ),
          );
          context.go('/circles');
        }
        return;
      }

      // Case C: Explicit invitation record -> Direct acceptance
      final roleStr = _invitation?.role ?? 'contributor';
      final role = CircleRole.values.firstWhere(
        (r) => r.name.toLowerCase() == roleStr.toLowerCase(),
        orElse: () => CircleRole.contributor,
      );

      final newMember = MagicCircleMember(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        role: role,
        joinedAt: DateTime.now(),
        status: 'active',
      );

      final updatedCircle = MagicCircle(
        id: _circle!.id,
        name: _circle!.name,
        description: _circle!.description,
        category: _circle!.category,
        ownerId: _circle!.ownerId,
        members: [..._circle!.members, newMember],
        sharedDiaryIds: _circle!.sharedDiaryIds,
        coverImageUrl: _circle!.coverImageUrl,
        createdAt: _circle!.createdAt,
        updatedAt: DateTime.now(),
      );

      await repo.updateCircle(updatedCircle);

      // Update invitation status if present
      if (_invitation != null) {
        try {
          await FirebaseFirestore.instance
              .collection('circle_invitations')
              .doc(_invitation!.id)
              .update({
            'status': 'accepted',
            'acceptedByUid': user.uid,
            'acceptedAt': Timestamp.now(),
          });
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to ${_circle!.name}!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        context.go('/circles/${_circle!.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClaiming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join circle: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Circle Invitation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _circle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Circle Invitation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 56, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Unable to find this Circle invitation.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                if (FirebaseAuth.instance.currentUser == null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign In to Join'),
                    onPressed: () => context.go('/login'),
                  )
                else
                  ElevatedButton(
                    onPressed: () => context.go('/circles'),
                    child: const Text('Go to My Circles'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final circle = _circle!;
    final inviterName = _invitation?.inviterName ?? 'A Circle member';

    return Scaffold(
      appBar: AppBar(title: const Text('Join Circle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.deepPurple.shade50,
              child: const Icon(Icons.groups_rounded, size: 48, color: Colors.deepPurple),
            ),
            const SizedBox(height: 16),
            Text(
              circle.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                circle.category.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (circle.description.isNotEmpty) ...[
              Text(
                circle.description,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Invited By: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(inviterName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Role: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        (_invitation?.role ?? 'Contributor').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.group_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Current Members: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text('${circle.members.length} members', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isClaiming ? null : _joinCircle,
                child: _isClaiming
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Accept & Join Circle',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
