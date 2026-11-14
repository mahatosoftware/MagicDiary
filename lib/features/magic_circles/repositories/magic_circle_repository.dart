import 'dart:async';
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

  Future<void> createCircle(MagicCircle circle) async {
    await _circlesRef.doc(circle.id).set(circle.toMap(), SetOptions(merge: true));
  }

  Future<void> updateCircle(MagicCircle circle) async {
    await _circlesRef.doc(circle.id).update(circle.toMap());
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
