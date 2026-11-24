import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/magic_circle_models.dart';

class MagicCircleRepository {
  final FirebaseFirestore _firestore;

  MagicCircleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _circlesRef =>
      _firestore.collection('circles');

  CollectionReference<Map<String, dynamic>> _circleTasksRef(String circleId) =>
      _circlesRef.doc(circleId).collection('tasks');

  CollectionReference<Map<String, dynamic>> _circleExpensesRef(String circleId) =>
      _circlesRef.doc(circleId).collection('expenses');

  CollectionReference<Map<String, dynamic>> _circleMembersRef(String circleId) =>
      _circlesRef.doc(circleId).collection('members');

  CollectionReference<Map<String, dynamic>> _circleInvitationsRef(String circleId) =>
      _circlesRef.doc(circleId).collection('invitations');

  /// Collision-resistant code generator avoiding ambiguous chars (0, O, 1, I, L)
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    String code;
    bool exists = true;
    do {
      code = String.fromCharCodes(Iterable.generate(
        7, (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ));
      final query = await _circlesRef.where('code', isEqualTo: code).limit(1).get();
      exists = query.docs.isNotEmpty;
    } while (exists);
    return code;
  }

  Future<MagicCircle> createCircle(MagicCircle circle) async {
    var finalCircle = circle;
    if (finalCircle.code.trim().isEmpty) {
      final code = await _generateUniqueCode();
      finalCircle = finalCircle.copyWith(code: code);
    }

    final batch = _firestore.batch();
    batch.set(_circlesRef.doc(finalCircle.id), finalCircle.toMap(), SetOptions(merge: true));

    // Persist members to dedicated /circles/{id}/members/{uid} subcollection
    for (final member in finalCircle.members) {
      if (member.uid.isNotEmpty && !member.uid.startsWith('pending_')) {
        batch.set(
          _circleMembersRef(finalCircle.id).doc(member.uid),
          member.toMap(),
          SetOptions(merge: true),
        );
      } else if (member.email.isNotEmpty) {
        final inviteId = member.email.replaceAll('/', '_').replaceAll('.', '_');
        batch.set(
          _circleInvitationsRef(finalCircle.id).doc(inviteId),
          {
            'id': inviteId,
            'circleId': finalCircle.id,
            'email': member.email.trim().toLowerCase(),
            'role': member.role.name,
            'status': 'pending',
            'invitedBy': finalCircle.ownerId,
            'createdAt': Timestamp.now(),
          },
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
    return finalCircle;
  }

  /// Look up circle by permanent alphanumeric code OR disposable one-time code
  Future<MagicCircle?> getCircleByCode(String rawCode) async {
    final clean = rawCode.trim().toUpperCase();
    if (clean.isEmpty) return null;

    // 1. Try finding by permanent code
    final permQuery = await _circlesRef.where('code', isEqualTo: clean).limit(1).get();
    if (permQuery.docs.isNotEmpty) {
      final doc = permQuery.docs.first;
      return MagicCircle.fromMap(doc.data(), doc.id);
    }

    // 2. Try finding by oneTimeCodes array
    final oneTimeQuery = await _circlesRef.where('oneTimeCodes', arrayContains: clean).limit(1).get();
    if (oneTimeQuery.docs.isNotEmpty) {
      final doc = oneTimeQuery.docs.first;
      return MagicCircle.fromMap(doc.data(), doc.id);
    }

    return null;
  }

  /// Appends user to pendingMemberIds queue for review
  Future<void> requestJoin(String circleId, String userId) async {
    await _circlesRef.doc(circleId).update({
      'pendingMemberIds': FieldValue.arrayUnion([userId]),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Generates a single-use disposable invite code
  Future<String> generateOneTimeCode(String circleId) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final randomSuffix = String.fromCharCodes(Iterable.generate(
      6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
    final code = 'IN-$randomSuffix';

    await _circlesRef.doc(circleId).update({
      'oneTimeCodes': FieldValue.arrayUnion([code]),
      'updatedAt': Timestamp.now(),
    });
    return code;
  }

  /// Deletes or revokes a one-time disposable invite code
  Future<void> deleteOneTimeCode(String circleId, String code) async {
    await _circlesRef.doc(circleId).update({
      'oneTimeCodes': FieldValue.arrayRemove([code.trim().toUpperCase()]),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Transactional Join with One-Time Code (Atomic redemption & burn)
  Future<void> joinWithOneTimeCode(
    String circleId,
    String userId,
    String rawCode, {
    required String email,
    required String displayName,
  }) async {
    final cleanCode = rawCode.trim().toUpperCase();
    await _firestore.runTransaction((transaction) async {
      final docRef = _circlesRef.doc(circleId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Circle not found');
      }

      final data = snapshot.data()!;
      final oneTimeCodes = List<String>.from(data['oneTimeCodes'] ?? []);

      if (!oneTimeCodes.contains(cleanCode)) {
        throw Exception('This one-time invite code has already been used or expired.');
      }

      // Check if already member
      final memberUids = List<String>.from(data['memberUids'] ?? []);
      if (memberUids.contains(userId)) {
        return; // Already joined
      }

      // Atomically burn the one-time code
      oneTimeCodes.remove(cleanCode);

      final circle = MagicCircle.fromMap(data, snapshot.id);
      final newMember = MagicCircleMember(
        uid: userId,
        email: email.trim().toLowerCase(),
        displayName: displayName.isNotEmpty ? displayName : 'Member',
        role: CircleRole.contributor,
        joinedAt: DateTime.now(),
        status: 'active',
      );

      final updatedMembers = [...circle.members.where((m) => m.uid != userId), newMember];
      final pendingMemberIds = List<String>.from(data['pendingMemberIds'] ?? [])..remove(userId);
      memberUids.add(userId);

      final emails = List<String>.from(data['memberEmails'] ?? []);
      if (email.isNotEmpty && !emails.contains(email.trim().toLowerCase())) {
        emails.add(email.trim().toLowerCase());
      }

      transaction.update(docRef, {
        'oneTimeCodes': oneTimeCodes,
        'memberUids': memberUids,
        'memberEmails': emails,
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'pendingMemberIds': pendingMemberIds,
        'updatedAt': Timestamp.now(),
      });

      final memberDocRef = _circleMembersRef(circleId).doc(userId);
      transaction.set(memberDocRef, newMember.toMap(), SetOptions(merge: true));
    });
  }

  /// Admin approval moving user from pendingMemberIds to active member
  Future<void> approveMember(
    String circleId,
    String applicantUid, {
    String? displayName,
    String? email,
    CircleRole role = CircleRole.contributor,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _circlesRef.doc(circleId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Circle not found');
      }

      final data = snapshot.data()!;
      final circle = MagicCircle.fromMap(data, snapshot.id);

      final pendingMemberIds = List<String>.from(data['pendingMemberIds'] ?? [])..remove(applicantUid);
      final memberUids = List<String>.from(data['memberUids'] ?? []);
      if (!memberUids.contains(applicantUid)) {
        memberUids.add(applicantUid);
      }

      final newMember = MagicCircleMember(
        uid: applicantUid,
        email: email?.trim().toLowerCase() ?? '',
        displayName: (displayName != null && displayName.isNotEmpty) ? displayName : 'Member',
        role: role,
        joinedAt: DateTime.now(),
        status: 'active',
      );

      final updatedMembers = [...circle.members.where((m) => m.uid != applicantUid), newMember];

      transaction.update(docRef, {
        'pendingMemberIds': pendingMemberIds,
        'memberUids': memberUids,
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'updatedAt': Timestamp.now(),
      });

      final memberDocRef = _circleMembersRef(circleId).doc(applicantUid);
      transaction.set(memberDocRef, newMember.toMap(), SetOptions(merge: true));
    });
  }

  /// Admin rejection removing user from pendingMemberIds
  Future<void> rejectMember(String circleId, String applicantUid) async {
    await _circlesRef.doc(circleId).update({
      'pendingMemberIds': FieldValue.arrayRemove([applicantUid]),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Promotes a member to Admin
  Future<void> promoteToAdmin(String circleId, String memberUid) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _circlesRef.doc(circleId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) return;
      final data = snapshot.data()!;
      final circle = MagicCircle.fromMap(data, snapshot.id);

      final updatedMembers = circle.members.map((m) {
        if (m.uid == memberUid) {
          return m.copyWith(role: CircleRole.admin);
        }
        return m;
      }).toList();

      final adminIds = List<String>.from(data['adminIds'] ?? []);
      if (!adminIds.contains(memberUid)) {
        adminIds.add(memberUid);
      }

      transaction.update(docRef, {
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'adminIds': adminIds,
        'updatedAt': Timestamp.now(),
      });

      final memberDocRef = _circleMembersRef(circleId).doc(memberUid);
      transaction.update(memberDocRef, {'role': CircleRole.admin.name});
    });
  }

  /// Demotes an Admin to Contributor
  Future<void> demoteFromAdmin(String circleId, String memberUid) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _circlesRef.doc(circleId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) return;
      final data = snapshot.data()!;
      final circle = MagicCircle.fromMap(data, snapshot.id);

      if (circle.ownerId == memberUid) {
        throw Exception('Cannot demote the Circle Owner.');
      }

      final updatedMembers = circle.members.map((m) {
        if (m.uid == memberUid) {
          return m.copyWith(role: CircleRole.contributor);
        }
        return m;
      }).toList();

      final adminIds = List<String>.from(data['adminIds'] ?? [])..remove(memberUid);

      transaction.update(docRef, {
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'adminIds': adminIds,
        'updatedAt': Timestamp.now(),
      });

      final memberDocRef = _circleMembersRef(circleId).doc(memberUid);
      transaction.update(memberDocRef, {'role': CircleRole.contributor.name});
    });
  }

  /// Remove Member / Safe Leaving (Transaction with Successor Rule & empty-circle check)
  Future<void> removeMember(String circleId, String memberUid) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _circlesRef.doc(circleId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Circle not found');
      }

      final data = snapshot.data()!;
      final circle = MagicCircle.fromMap(data, snapshot.id);

      final memberUids = List<String>.from(data['memberUids'] ?? []);
      final adminIds = List<String>.from(data['adminIds'] ?? []);

      // Successor Rule:
      // If the departing user is the sole admin AND other members remain, block removal
      final isSoleAdmin = (adminIds.length == 1 && adminIds.contains(memberUid)) ||
          (circle.ownerId == memberUid && adminIds.where((id) => id != memberUid).isEmpty);
      if (isSoleAdmin && memberUids.length > 1) {
        throw Exception(
          'Admin Transfer Required: You are the sole administrator of this circle. You must promote another member to Admin before leaving.',
        );
      }

      memberUids.remove(memberUid);
      adminIds.remove(memberUid);
      final updatedMembers = circle.members.where((m) => m.uid != memberUid).toList();
      final isPendingDelete = memberUids.isEmpty;

      transaction.update(docRef, {
        'memberUids': memberUids,
        'adminIds': adminIds,
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'isPendingDelete': isPendingDelete,
        'updatedAt': Timestamp.now(),
      });

      final memberDocRef = _circleMembersRef(circleId).doc(memberUid);
      transaction.delete(memberDocRef);
    });
  }

  Future<void> updateCircle(MagicCircle circle) async {
    final batch = _firestore.batch();
    batch.update(_circlesRef.doc(circle.id), circle.toMap());

    for (final member in circle.members) {
      if (member.uid.isNotEmpty && !member.uid.startsWith('pending_')) {
        batch.set(
          _circleMembersRef(circle.id).doc(member.uid),
          member.toMap(),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  Future<void> deleteCircle(String circleId) async {
    await _circlesRef.doc(circleId).delete();
  }

  Stream<MagicCircle?> watchCircle(String circleId) {
    return _circlesRef.doc(circleId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return MagicCircle.fromMap(doc.data()!, doc.id);
    });
  }

  Stream<List<MagicCircle>> watchUserCircles({
    required String uid,
    String? email,
    String? displayName,
  }) {
    final controller = StreamController<List<MagicCircle>>.broadcast();
    Map<String, MagicCircle> ownedCircles = {};
    Map<String, MagicCircle> memberCircles = {};
    Map<String, MagicCircle> emailCircles = {};

    void emit() {
      if (controller.isClosed) return;
      final merged = <String, MagicCircle>{...ownedCircles, ...memberCircles, ...emailCircles};
      final list = merged.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      controller.add(list);
    }

    // Stream 1: Circles owned by user (matches ownerId rule)
    final subOwned = _circlesRef
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            ownedCircles = {
              for (final doc in snapshot.docs)
                doc.id: MagicCircle.fromMap(doc.data(), doc.id),
            };
            emit();
          },
          onError: (err) {
            if (!controller.isClosed) {
              controller.addError(err);
            }
          },
        );

    // Stream 2: Circles where user is a member by UID (matches memberUids rule)
    final subMember = _circlesRef
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .listen(
          (snapshot) {
            memberCircles = {
              for (final doc in snapshot.docs)
                doc.id: MagicCircle.fromMap(doc.data(), doc.id),
            };
            emit();
          },
          onError: (err) {
            emit();
          },
        );

    // Stream 3: Circles where user was invited by email (matches memberEmails)
    StreamSubscription? subEmail;
    final cleanEmail = email?.trim().toLowerCase();
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      subEmail = _circlesRef
          .where('memberEmails', arrayContains: cleanEmail)
          .snapshots()
          .listen(
            (snapshot) {
              emailCircles = {
                for (final doc in snapshot.docs)
                  doc.id: MagicCircle.fromMap(doc.data(), doc.id),
              };
              emit();

              // Auto-claim any pending invited memberships
              for (final doc in snapshot.docs) {
                final circle = MagicCircle.fromMap(doc.data(), doc.id);
                final hasPending = circle.members.any(
                  (m) =>
                      m.email.trim().toLowerCase() == cleanEmail &&
                      (m.uid.startsWith('pending_') || m.uid.isEmpty || m.uid != uid),
                );
                if (hasPending || !circle.memberUids.contains(uid)) {
                  claimPendingMembership(
                    circleId: circle.id,
                    uid: uid,
                    email: cleanEmail,
                    displayName: displayName,
                  );
                }
              }
            },
            onError: (err) {
              emit();
            },
          );
    }

    controller.onCancel = () {
      subOwned.cancel();
      subMember.cancel();
      subEmail?.cancel();
    };

    return controller.stream;
  }

  /// Claims an invited membership, transitioning from pending email UID to actual user UID.
  Future<void> claimPendingMembership({
    required String circleId,
    required String uid,
    required String email,
    String? displayName,
  }) async {
    try {
      final docRef = _circlesRef.doc(circleId);
      final snap = await docRef.get();
      if (!snap.exists || snap.data() == null) return;
      final circle = MagicCircle.fromMap(snap.data()!, snap.id);
      final cleanEmail = email.trim().toLowerCase();

      bool modified = false;
      final updatedMembers = circle.members.map((m) {
        if (m.email.trim().toLowerCase() == cleanEmail &&
            (m.uid.startsWith('pending_') || m.uid.isEmpty || m.uid != uid)) {
          modified = true;
          return MagicCircleMember(
            uid: uid,
            email: m.email,
            displayName: (displayName != null && displayName.isNotEmpty)
                ? displayName
                : m.displayName,
            role: m.role,
            joinedAt: m.joinedAt,
            status: 'active',
          );
        }
        return m;
      }).toList();

      final updatedUids = {
        ...circle.memberUids,
        uid,
      }.toList();

      final updatedEmails = {
        ...circle.memberEmails,
        cleanEmail,
      }.toList();

      if (modified || !circle.memberUids.contains(uid)) {
        await docRef.update({
          'members': updatedMembers.map((m) => m.toMap()).toList(),
          'memberUids': updatedUids,
          'memberEmails': updatedEmails,
          'updatedAt': Timestamp.now(),
        });

        // Mirror active member into dedicated /members/{uid} subcollection
        final claimedMember = updatedMembers.firstWhere(
          (m) => m.uid == uid,
          orElse: () => MagicCircleMember(
            uid: uid,
            email: cleanEmail,
            displayName: displayName ?? 'Member',
            joinedAt: DateTime.now(),
          ),
        );
        await _circleMembersRef(circleId).doc(uid).set(
          claimedMember.toMap(),
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Ignored if user lacks permission or offline
    }
  }

  Stream<List<CircleResponsibilityTask>> watchCircleTasks(String circleId) {
    return _circleTasksRef(circleId)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CircleResponsibilityTask.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> saveCircleTask(CircleResponsibilityTask task) async {
    await _circleTasksRef(task.circleId)
        .doc(task.id)
        .set(task.toMap(), SetOptions(merge: true));
  }

  Future<void> completeCircleTask(String circleId, String taskId) async {
    await _circleTasksRef(circleId).doc(taskId).update({
      'status': 'completed',
      'completedAt': Timestamp.now(),
    });
  }

  Stream<List<CircleExpense>> watchCircleExpenses(String circleId) {
    return _circleExpensesRef(circleId)
        .orderBy('expenseDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CircleExpense.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> saveCircleExpense(CircleExpense expense) async {
    await _circleExpensesRef(expense.circleId)
        .doc(expense.id)
        .set(expense.toMap(), SetOptions(merge: true));
  }
}
