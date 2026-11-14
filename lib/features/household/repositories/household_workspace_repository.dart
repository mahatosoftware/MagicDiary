import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/household_management_models.dart';

class HouseholdWorkspaceRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  HouseholdWorkspaceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // --- Households ---
  Future<Household> createHousehold({
    required String ownerUid,
    required String ownerEmail,
    required String ownerDisplayName,
    required String householdName,
    String timezone = 'Asia/Kolkata',
  }) async {
    final householdId = _uuid.v4();
    final ownerMember = HouseholdMember(
      uid: ownerUid,
      email: ownerEmail,
      displayName: ownerDisplayName,
      role: 'owner',
      joinedAt: DateTime.now(),
      canRecordAttendance: true,
      canApproveSalary: true,
      canViewFinancials: true,
      canManageTasks: true,
    );

    final household = Household(
      id: householdId,
      name: householdName,
      ownerId: ownerUid,
      members: [ownerMember],
      timezone: timezone,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('households').doc(householdId).set(household.toJson());
    // Also track in user's profile/membership index
    await _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('userHouseholds')
        .doc(householdId)
        .set({
      'householdId': householdId,
      'householdName': householdName,
      'role': 'owner',
      'joinedAt': Timestamp.fromDate(DateTime.now()),
    });

    return household;
  }

  Future<List<Household>> getUserHouseholds(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final membershipsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('userHouseholds')
          .get();
      final householdIds = membershipsSnap.docs.map((d) => d.id).toList();
      if (householdIds.isEmpty) return const [];

      final list = <Household>[];
      for (final hId in householdIds) {
        final doc = await _firestore.collection('households').doc(hId).get();
        if (doc.exists && doc.data() != null) {
          list.add(Household.fromJson(doc.data()!));
        }
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  // --- Invitations ---
  Future<HouseholdInvitation> createInvitation({
    required String householdId,
    required String householdName,
    required String inviterUid,
    required String inviterName,
    required String inviteeEmail,
    String role = 'member',
  }) async {
    final invitationId = _uuid.v4();
    final token = _uuid.v4().substring(0, 8); // 8-char secure shareable token
    final invitation = HouseholdInvitation(
      id: invitationId,
      householdId: householdId,
      householdName: householdName,
      inviterUid: inviterUid,
      inviterName: inviterName,
      inviteeEmail: inviteeEmail.trim().toLowerCase(),
      role: role,
      token: token,
      status: 'pending',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    );

    await _firestore.collection('household_invitations').doc(invitationId).set(invitation.toJson());
    return invitation;
  }

  Future<List<HouseholdInvitation>> getPendingInvitationsForEmail(String email) async {
    if (email.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('household_invitations')
          .where('inviteeEmail', isEqualTo: email.trim().toLowerCase())
          .where('status', isEqualTo: 'pending')
          .get();
      return snap.docs
          .map((d) => HouseholdInvitation.fromJson(d.data()))
          .where((i) => !i.isExpired)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> acceptInvitation({
    required String invitationId,
    required String userUid,
    required String userEmail,
    required String userDisplayName,
  }) async {
    final invRef = _firestore.collection('household_invitations').doc(invitationId);
    final invDoc = await invRef.get();
    if (!invDoc.exists || invDoc.data() == null) return false;

    final invitation = HouseholdInvitation.fromJson(invDoc.data()!);
    if (invitation.isExpired || invitation.status != 'pending') return false;

    final householdRef = _firestore.collection('households').doc(invitation.householdId);
    final householdDoc = await householdRef.get();
    if (!householdDoc.exists || householdDoc.data() == null) return false;

    final household = Household.fromJson(householdDoc.data()!);

    // Prevent duplicate membership
    if (household.isMember(userUid)) {
      await invRef.update({'status': 'accepted'});
      return true;
    }

    final newMember = HouseholdMember(
      uid: userUid,
      email: userEmail,
      displayName: userDisplayName,
      role: invitation.role,
      joinedAt: DateTime.now(),
      canRecordAttendance: invitation.role != 'viewer',
      canApproveSalary: invitation.role == 'admin',
      canViewFinancials: invitation.role == 'admin',
      canManageTasks: invitation.role != 'viewer',
    );

    final updatedMembers = List<HouseholdMember>.from(household.members)..add(newMember);
    await householdRef.update({'members': updatedMembers.map((m) => m.toJson()).toList()});

    // Mark user membership index
    await _firestore
        .collection('users')
        .doc(userUid)
        .collection('userHouseholds')
        .doc(household.id)
        .set({
      'householdId': household.id,
      'householdName': household.name,
      'role': invitation.role,
      'joinedAt': Timestamp.fromDate(DateTime.now()),
    });

    await invRef.update({'status': 'accepted'});
    return true;
  }

  Future<void> removeMember(String householdId, String memberUid) async {
    final householdRef = _firestore.collection('households').doc(householdId);
    final doc = await householdRef.get();
    if (!doc.exists || doc.data() == null) return;

    final household = Household.fromJson(doc.data()!);
    final updatedMembers = household.members.where((m) => m.uid != memberUid).toList();

    await householdRef.update({'members': updatedMembers.map((m) => m.toJson()).toList()});
    await _firestore
        .collection('users')
        .doc(memberUid)
        .collection('userHouseholds')
        .doc(householdId)
        .delete();
  }

  // --- Shared Tasks ---
  Future<List<HouseholdTask>> getTasks(String householdId) async {
    if (householdId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('household_tasks')
          .where('householdId', isEqualTo: householdId)
          .get();
      final list = snap.docs.map((d) => HouseholdTask.fromJson(d.data())).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> addTask(HouseholdTask task) async {
    await _firestore.collection('household_tasks').doc(task.id).set(task.toJson());
  }

  Future<void> toggleTaskComplete(String taskId, bool isCompleted, String completedByUid) async {
    await _firestore.collection('household_tasks').doc(taskId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? DateTime.now().toIso8601String() : null,
      'completedByUid': isCompleted ? completedByUid : null,
    });
  }

  // --- Inter-Member Reimbursements ---
  Future<List<InterMemberSettlement>> getSettlements(String householdId) async {
    if (householdId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('household_settlements')
          .where('householdId', isEqualTo: householdId)
          .get();
      return snap.docs.map((d) => InterMemberSettlement.fromJson(d.data())).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> recordSettlement(InterMemberSettlement settlement) async {
    await _firestore
        .collection('household_settlements')
        .doc(settlement.id)
        .set(settlement.toJson());
  }

  Future<void> markSettlementPaid(String settlementId) async {
    await _firestore.collection('household_settlements').doc(settlementId).update({
      'isSettled': true,
      'settledAt': DateTime.now().toIso8601String(),
    });
  }
}
