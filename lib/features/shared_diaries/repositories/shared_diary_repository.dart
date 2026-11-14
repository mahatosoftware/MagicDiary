import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shared_diary_models.dart';

final sharedDiaryRepositoryProvider = Provider<SharedDiaryRepository>((ref) => SharedDiaryRepository());

class SharedDiaryRepository {
  final FirebaseFirestore? _firestoreInstance;

  SharedDiaryRepository({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sharesRef =>
      _firestore.collection('shared_diary_access');

  /// Generates a deterministic document ID for instant O(1) Firestore security rules lookup.
  static String generateShareId({
    required String ownerUid,
    required String diaryId,
    required String target, // email or uid or circleId
  }) {
    final cleanTarget = target.trim().toLowerCase().replaceAll('/', '_');
    return '${ownerUid}_${diaryId}_$cleanTarget';
  }

  /// Creates or updates a shared diary access record.
  /// Generates a deterministic document ID and an optional UID alias.
  Future<void> createShareAccess(SharedDiaryAccess access) async {
    final cleanEmail = access.sharedWithEmail.trim().toLowerCase();
    final target = cleanEmail.isNotEmpty ? cleanEmail : access.sharedWithUid;
    final primaryDocId = generateShareId(
      ownerUid: access.ownerUid,
      diaryId: access.diaryId,
      target: target,
    );

    final normalized = access.copyWith(
      id: primaryDocId,
      sharedWithEmail: cleanEmail,
    );

    // 1. Save primary access record by deterministic email/target ID
    await _sharesRef.doc(primaryDocId).set(normalized.toMap(), SetOptions(merge: true));

    // 2. If shared with a real UID (not pending), also save/alias by UID docId for O(1) rules
    if (access.sharedWithUid.isNotEmpty && !access.sharedWithUid.startsWith('pending_')) {
      final uidDocId = generateShareId(
        ownerUid: access.ownerUid,
        diaryId: access.diaryId,
        target: access.sharedWithUid,
      );
      if (uidDocId != primaryDocId) {
        await _sharesRef.doc(uidDocId).set(normalized.copyWith(id: uidDocId).toMap(), SetOptions(merge: true));
      }
    }
  }

  /// Updates an entire share access document.
  Future<void> updateShareAccess(SharedDiaryAccess access) async {
    await createShareAccess(access.copyWith(updatedAt: DateTime.now()));
  }

  /// Adds specific records to an existing share without affecting other settings.
  Future<void> addRecordsToShare({
    required String shareId,
    required List<String> recordIds,
  }) async {
    final snap = await _sharesRef.doc(shareId).get();
    if (!snap.exists || snap.data() == null) return;
    final current = SharedDiaryAccess.fromMap(snap.data()!, snap.id);
    final updatedList = {...current.grantedRecordIds, ...recordIds}.toList();
    final updated = current.copyWith(
      grantedRecordIds: updatedList,
      updatedAt: DateTime.now(),
    );
    await updateShareAccess(updated);
  }

  /// Removes specific records from an existing share.
  Future<void> removeRecordsFromShare({
    required String shareId,
    required List<String> recordIds,
  }) async {
    final snap = await _sharesRef.doc(shareId).get();
    if (!snap.exists || snap.data() == null) return;
    final current = SharedDiaryAccess.fromMap(snap.data()!, snap.id);
    final toRemove = recordIds.toSet();
    final updatedList = current.grantedRecordIds.where((id) => !toRemove.contains(id)).toList();
    final updated = current.copyWith(
      grantedRecordIds: updatedList,
      updatedAt: DateTime.now(),
    );
    await updateShareAccess(updated);
  }

  /// Updates the future-record sharing policy without affecting existing record access.
  Future<void> updateFutureRecordPolicy({
    required String shareId,
    required FutureRecordPolicy policy,
    DateTime? cutoffTime,
  }) async {
    final snap = await _sharesRef.doc(shareId).get();
    if (!snap.exists || snap.data() == null) return;
    final current = SharedDiaryAccess.fromMap(snap.data()!, snap.id);
    final updated = current.copyWith(
      futureRecordPolicy: policy,
      snapshotCutoffTime: policy == FutureRecordPolicy.existingOnly
          ? (cutoffTime ?? DateTime.now())
          : current.snapshotCutoffTime,
      updatedAt: DateTime.now(),
    );
    await updateShareAccess(updated);
  }

  /// Claims a pending invitation when the recipient user logs in.
  Future<void> claimPendingShare({
    required String shareId,
    required String uid,
    required String displayName,
  }) async {
    try {
      final snap = await _sharesRef.doc(shareId).get();
      if (!snap.exists || snap.data() == null) return;
      final currentData = snap.data()!;
      final currentSharedWithUid = currentData['sharedWithUid'] as String? ?? '';
      if (currentSharedWithUid == uid) return; // Already claimed

      await _sharesRef.doc(shareId).update({
        'sharedWithUid': uid,
        'sharedWithName': displayName.isNotEmpty ? displayName : (currentData['sharedWithName'] ?? 'Member'),
        'updatedAt': Timestamp.now(),
      });

      // Also create UID-based document for direct O(1) rule evaluation
      final ownerUid = currentData['ownerUid'] as String? ?? '';
      final diaryId = currentData['diaryId'] as String? ?? '';
      if (ownerUid.isNotEmpty && diaryId.isNotEmpty) {
        final uidDocId = generateShareId(ownerUid: ownerUid, diaryId: diaryId, target: uid);
        final claimedShare = SharedDiaryAccess.fromMap({
          ...currentData,
          'id': uidDocId,
          'sharedWithUid': uid,
          'sharedWithName': displayName.isNotEmpty ? displayName : (currentData['sharedWithName'] ?? 'Member'),
          'updatedAt': Timestamp.now(),
        }, uidDocId);
        await _sharesRef.doc(uidDocId).set(claimedShare.toMap(), SetOptions(merge: true));
      }
    } catch (_) {
      // Best effort background sync
    }
  }

  /// Revokes or leaves a shared diary access.
  Future<void> revokeShareAccess(
    String accessId, {
    String? ownerUid,
    String? diaryId,
    String? target,
  }) async {
    try {
      await _sharesRef.doc(accessId).delete();
      if (ownerUid != null && diaryId != null && target != null) {
        final aliasId = generateShareId(ownerUid: ownerUid, diaryId: diaryId, target: target);
        if (aliasId != accessId) {
          try {
            await _sharesRef.doc(aliasId).delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Updates permission level for an existing share.
  Future<void> updatePermission(String accessId, SharedDiaryPermission permission) async {
    await _sharesRef.doc(accessId).update({
      'permission': permission.name,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Updates restrictions (attachments, comments, export, fields) for a share.
  Future<void> updateRestrictions({
    required String accessId,
    bool? allowAttachments,
    bool? allowComments,
    bool? allowExport,
    List<String>? restrictedFields,
  }) async {
    final updates = <String, dynamic>{'updatedAt': Timestamp.now()};
    if (allowAttachments != null) updates['allowAttachments'] = allowAttachments;
    if (allowComments != null) updates['allowComments'] = allowComments;
    if (allowExport != null) updates['allowExport'] = allowExport;
    if (restrictedFields != null) updates['restrictedFields'] = restrictedFields;
    await _sharesRef.doc(accessId).update(updates);
  }

  /// Updates the expiration date for a share.
  Future<void> updateExpiry({
    required String accessId,
    DateTime? expiresAt,
  }) async {
    await _sharesRef.doc(accessId).update({
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Watches all shares configured for a specific diary owned by `ownerUid`.
  Stream<List<SharedDiaryAccess>> watchDiaryShares({
    required String ownerUid,
    required String diaryId,
  }) {
    try {
      return _sharesRef
          .where('ownerUid', isEqualTo: ownerUid)
          .where('diaryId', isEqualTo: diaryId)
          .snapshots()
          .map((snapshot) {
            final map = <String, SharedDiaryAccess>{};
            for (final doc in snapshot.docs) {
              final share = SharedDiaryAccess.fromMap(doc.data(), doc.id);
              final key = share.recipientType == RecipientType.circle
                  ? 'circle_${share.circleId}'
                  : (share.sharedWithEmail.isNotEmpty ? share.sharedWithEmail : share.sharedWithUid);
              final existing = map[key];
              if (existing == null || (!share.isPending && existing.isPending)) {
                map[key] = share;
              }
            }
            return map.values.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Collects the set of all record IDs currently shared with ANY recipient in this diary.
  Future<Set<String>> getExistingSharedRecordIds({
    required String ownerUid,
    required String diaryId,
    String? excludeShareId,
  }) async {
    try {
      final snap = await _sharesRef
          .where('ownerUid', isEqualTo: ownerUid)
          .where('diaryId', isEqualTo: diaryId)
          .get();

      final sharedIds = <String>{};
      for (final doc in snap.docs) {
        if (excludeShareId != null && doc.id == excludeShareId) continue;
        final share = SharedDiaryAccess.fromMap(doc.data(), doc.id);
        if (share.isActive) {
          sharedIds.addAll(share.grantedRecordIds);
        }
      }
      return sharedIds;
    } catch (_) {
      return {};
    }
  }

  /// Watches diaries shared with the given user, matching both UID and email address.
  /// Automatically resolves and claims pending invitations.
  Stream<List<SharedDiaryAccess>> watchSharedWithMe({
    required String uid,
    String? email,
    String? displayName,
  }) {
    try {
      final cleanEmail = email?.trim().toLowerCase();
      if (cleanEmail == null || cleanEmail.isEmpty) {
        return _sharesRef
            .where('sharedWithUid', isEqualTo: uid)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => SharedDiaryAccess.fromMap(doc.data(), doc.id))
                .where((s) => !s.isExpired)
                .toList());
      }

      final controller = StreamController<List<SharedDiaryAccess>>.broadcast();
      Map<String, SharedDiaryAccess> uidShares = {};
      Map<String, SharedDiaryAccess> emailShares = {};

      void emit() {
        if (controller.isClosed) return;
        final merged = <String, SharedDiaryAccess>{};
        for (final s in [...uidShares.values, ...emailShares.values]) {
          if (!s.isExpired) {
            final compositeKey = '${s.ownerUid}_${s.diaryId}';
            final existing = merged[compositeKey];
            if (existing == null || (!s.isPending && existing.isPending)) {
              merged[compositeKey] = s;
            }
          }
        }
        final list = merged.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        controller.add(list);
      }

      // Stream 1: Direct UID match
      final subUid = _sharesRef
          .where('sharedWithUid', isEqualTo: uid)
          .snapshots()
          .listen(
            (snapshot) {
              uidShares = {
                for (final doc in snapshot.docs)
                  doc.id: SharedDiaryAccess.fromMap(doc.data(), doc.id),
              };
              emit();
            },
            onError: (err) {
              if (!controller.isClosed) controller.addError(err);
            },
          );

      // Stream 2: Email match (normalized lowercase)
      final subEmail = _sharesRef
          .where('sharedWithEmail', isEqualTo: cleanEmail)
          .snapshots()
          .listen(
            (snapshot) {
              emailShares = {
                for (final doc in snapshot.docs)
                  doc.id: SharedDiaryAccess.fromMap(doc.data(), doc.id),
              };
              emit();

              // Auto-claim pending invitations in background
              for (final doc in snapshot.docs) {
                final data = doc.data();
                final sharedWithUid = data['sharedWithUid'] as String? ?? '';
                if (sharedWithUid.startsWith('pending_') || (sharedWithUid.isNotEmpty && sharedWithUid != uid)) {
                  claimPendingShare(
                    shareId: doc.id,
                    uid: uid,
                    displayName: displayName ?? '',
                  );
                }
              }
            },
            onError: (err) {
              emit();
            },
          );

      controller.onCancel = () {
        subUid.cancel();
        subEmail.cancel();
      };

      return controller.stream;
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Watches diaries shared by the given user.
  Stream<List<SharedDiaryAccess>> watchSharedByMe(String uid) {
    try {
      return _sharesRef
          .where('ownerUid', isEqualTo: uid)
          .snapshots()
          .map((snapshot) {
            final map = <String, SharedDiaryAccess>{};
            for (final doc in snapshot.docs) {
              final share = SharedDiaryAccess.fromMap(doc.data(), doc.id);
              final key = '${share.diaryId}_${share.sharedWithEmail.isNotEmpty ? share.sharedWithEmail : share.sharedWithUid}';
              final existing = map[key];
              if (existing == null || (!share.isPending && existing.isPending)) {
                map[key] = share;
              }
            }
            final list = map.values.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return list;
          });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Direct lookup of active shared diary access for a given user on a specific diary.
  Future<SharedDiaryAccess?> getSharedDiaryAccess({
    required String ownerUid,
    required String diaryId,
    required String uid,
    String? email,
  }) async {
    // 1. Direct UID lookup
    final uidDocId = generateShareId(ownerUid: ownerUid, diaryId: diaryId, target: uid);
    final uidDoc = await _sharesRef.doc(uidDocId).get();
    if (uidDoc.exists && uidDoc.data() != null) {
      final access = SharedDiaryAccess.fromMap(uidDoc.data()!, uidDoc.id);
      if (!access.isExpired) return access;
    }

    // 2. Email lookup
    if (email != null && email.isNotEmpty) {
      final emailDocId = generateShareId(ownerUid: ownerUid, diaryId: diaryId, target: email);
      final emailDoc = await _sharesRef.doc(emailDocId).get();
      if (emailDoc.exists && emailDoc.data() != null) {
        final access = SharedDiaryAccess.fromMap(emailDoc.data()!, emailDoc.id);
        if (!access.isExpired) return access;
      }
    }

    return null;
  }
}
