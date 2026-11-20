import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_profile.dart';
import '../models/shared_diary_models.dart';

final sharedDiaryRepositoryProvider = Provider<SharedDiaryRepository>((ref) => SharedDiaryRepository());

class SharedDiaryRepository {
  final FirebaseFirestore? _firestoreInstance;

  SharedDiaryRepository({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sharesRef =>
      _firestore.collection('shared_diary_access');

  CollectionReference<Map<String, dynamic>> get _invitationsRef =>
      _firestore.collection('share_invitations');

  /// Looks up a user in Firestore by username, UID, or QR code metadata (case-insensitive & resilient)
  Future<UserProfile?> lookupUserByUsername(
    String username, {
    String? uidHint,
    String? displayNameHint,
    String? emailHint,
  }) async {
    final clean = username.trim().replaceAll('@', '');
    if (clean.isEmpty && (uidHint == null || uidHint.trim().isEmpty)) return null;
    final upper = clean.toUpperCase();
    final lower = clean.toLowerCase();

    // 1. Direct UID lookup if UID is known or hint provided (Fastest O(1) single-document get)
    final targetUid = uidHint?.trim() ?? (clean.length >= 26 && clean.length <= 36 && !clean.contains(' ') ? clean : null);
    if (targetUid != null && targetUid.isNotEmpty) {
      try {
        final userDoc = await _firestore.collection('users').doc(targetUid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final profile = UserProfile.fromMap(userDoc.data()!, targetUid);
          return profile;
        }
      } catch (e) {
        debugPrint('Direct user doc get note: $e');
      }
    }

    // 2. Check usernames registry (check uppercase, fallback lowercase)
    try {
      var usernameDoc = await _firestore.collection('usernames').doc(upper).get();
      if (!usernameDoc.exists && upper != lower) {
        usernameDoc = await _firestore.collection('usernames').doc(lower).get();
      }
      if (usernameDoc.exists && usernameDoc.data() != null) {
        final data = usernameDoc.data()!;
        final uid = data['uid'] as String?;
        if (uid != null && uid.isNotEmpty) {
          try {
            final userDoc = await _firestore.collection('users').doc(uid).get();
            if (userDoc.exists && userDoc.data() != null) {
              return UserProfile.fromMap(userDoc.data()!, uid);
            }
          } catch (e) {
            debugPrint('Direct users collection get failed ($e), using registry metadata');
          }
          // Resilient fallback: return user profile constructed from usernames registry metadata
          final displayName = data['displayName'] as String? ?? displayNameHint ?? '@$upper';
          final email = data['email'] as String? ?? emailHint ?? '$upper@magicdiary.internal';
          return UserProfile(
            uid: uid,
            email: email,
            displayName: displayName,
            username: upper,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('Note: Error checking usernames collection for "$upper": $e');
    }

    // 3. Fallback: Check if clean itself matches a user document ID directly
    try {
      final doc = await _firestore.collection('users').doc(clean).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!, clean);
      }
    } catch (_) {}

    // 4. Fallback: Direct query on users collection (check uppercase, fallback lowercase)
    try {
      var query = await _firestore
          .collection('users')
          .where('username', isEqualTo: upper)
          .limit(1)
          .get();
      if (query.docs.isEmpty && upper != lower) {
        query = await _firestore
            .collection('users')
            .where('username', isEqualTo: lower)
            .limit(1)
            .get();
      }
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return UserProfile.fromMap(doc.data(), doc.id);
      }
    } catch (e) {
      debugPrint('Note: Error querying users by username "$upper": $e');
    }

    // 5. Rich QR metadata fallback: if the QR payload embedded a valid UID or email
    if (uidHint != null && uidHint.trim().isNotEmpty) {
      return UserProfile(
        uid: uidHint.trim(),
        email: emailHint?.trim() ?? '$upper@magicdiary.internal',
        displayName: displayNameHint?.trim() ?? '@$upper',
        username: upper,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }

  /// Creates a one-time usable share invitation
  Future<OneTimeShareInvite> createOneTimeShareInvite(OneTimeShareInvite invite) async {
    final tokenHash = OneTimeShareInvite.hashToken(invite.id);
    final map = invite.toMap()..['tokenHash'] = tokenHash;
    await _invitationsRef.doc(invite.id).set(map);
    return invite.copyWith(tokenHash: tokenHash);
  }

  /// Fetches an invitation by token or tokenHash
  Future<OneTimeShareInvite?> getShareInvite(String token) async {
    try {
      final doc = await _invitationsRef.doc(token).get();
      if (doc.exists && doc.data() != null) {
        return OneTimeShareInvite.fromMap(doc.data()!, doc.id);
      }
      final hash = OneTimeShareInvite.hashToken(token);
      final hashDoc = await _invitationsRef.doc(hash).get();
      if (hashDoc.exists && hashDoc.data() != null) {
        return OneTimeShareInvite.fromMap(hashDoc.data()!, hashDoc.id);
      }
    } catch (e) {
      debugPrint('Error getting share invite $token: $e');
    }
    return null;
  }

  /// Claims a one-time usable invitation link in an atomic transaction
  Future<SharedDiaryAccess> claimOneTimeInvite({
    required String token,
    required UserProfile recipientUser,
  }) async {
    final inviteRef = _invitationsRef.doc(token);

    return await _firestore.runTransaction((transaction) async {
      final inviteSnap = await transaction.get(inviteRef);
      if (!inviteSnap.exists || inviteSnap.data() == null) {
        throw Exception('Invite link not found or invalid.');
      }

      final invite = OneTimeShareInvite.fromMap(inviteSnap.data()!, inviteSnap.id);

      if (invite.ownerUid == recipientUser.uid) {
        throw Exception('You cannot claim your own share invite link.');
      }

      if (invite.isClaimed) {
        throw Exception('This invite link has already been used and cannot be claimed again.');
      }

      if (invite.isExpired) {
        throw Exception('This invite link has expired.');
      }

      if (invite.boundEmail != null &&
          invite.boundEmail!.isNotEmpty &&
          invite.boundEmail!.trim().toLowerCase() != recipientUser.email.trim().toLowerCase()) {
        throw Exception('This invite link is bound to another email address.');
      }

      final now = DateTime.now();

      // Mark invite as claimed
      transaction.update(inviteRef, {
        'isClaimed': true,
        'claimedByUid': recipientUser.uid,
        'claimedByEmail': recipientUser.email,
        'claimedByName': recipientUser.displayName,
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Grant recipient SharedDiaryAccess
      final cleanEmail = recipientUser.email.trim().toLowerCase();
      final primaryDocId = generateShareId(
        ownerUid: invite.ownerUid,
        diaryId: invite.diaryId,
        target: cleanEmail.isNotEmpty ? cleanEmail : recipientUser.uid,
      );

      final share = SharedDiaryAccess(
        id: primaryDocId,
        diaryId: invite.diaryId,
        diaryName: invite.diaryName,
        ownerUid: invite.ownerUid,
        ownerName: invite.ownerName,
        recipientType: RecipientType.user,
        sharingMode: invite.sharingMode,
        futureRecordPolicy: FutureRecordPolicy.allFuture,
        sharedWithUid: recipientUser.uid,
        sharedWithEmail: cleanEmail,
        sharedWithName: recipientUser.displayName.isNotEmpty
            ? recipientUser.displayName
            : (recipientUser.username.isNotEmpty ? '@${recipientUser.username}' : cleanEmail),
        permission: invite.permission,
        shareEntireDiary: invite.sharingMode == SharingMode.entire,
        grantedRecordIds: invite.grantedRecordIds,
        allowAttachments: invite.allowAttachments,
        allowComments: invite.allowComments,
        allowExport: invite.allowExport,
        restrictedFields: invite.restrictedFields,
        status: ShareStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      // Save primary share access
      transaction.set(_sharesRef.doc(primaryDocId), share.toMap(), SetOptions(merge: true));

      // Synchronize sharedWithUids array on granted records for query-level protection
      if (invite.sharingMode == SharingMode.selected && invite.grantedRecordIds.isNotEmpty) {
        for (final recId in invite.grantedRecordIds) {
          final recRef = _firestore
              .collection('users')
              .doc(invite.ownerUid)
              .collection('diaries')
              .doc(invite.diaryId)
              .collection('records')
              .doc(recId);
          transaction.set(recRef, {
            'sharedWithUids': FieldValue.arrayUnion([recipientUser.uid]),
          }, SetOptions(merge: true));
        }
      }

      // Also set exact UID doc and lowercased UID doc for resilient O(1) rules matching
      final exactUidDocId = '${invite.ownerUid}_${invite.diaryId}_${recipientUser.uid.trim().replaceAll('/', '_')}';
      final lowerUidDocId = '${invite.ownerUid}_${invite.diaryId}_${recipientUser.uid.trim().toLowerCase().replaceAll('/', '_')}';

      if (exactUidDocId != primaryDocId) {
        transaction.set(_sharesRef.doc(exactUidDocId), share.copyWith(id: exactUidDocId).toMap(), SetOptions(merge: true));
      }
      if (lowerUidDocId != primaryDocId && lowerUidDocId != exactUidDocId) {
        transaction.set(_sharesRef.doc(lowerUidDocId), share.copyWith(id: lowerUidDocId).toMap(), SetOptions(merge: true));
      }

      return share;
    });
  }

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
    final safeEmail = cleanEmail.isNotEmpty
        ? cleanEmail
        : (access.sharedWithName.startsWith('@')
            ? '${access.sharedWithName.replaceAll('@', '')}@magicdiary.internal'
            : (access.sharedWithUid.isNotEmpty && !access.sharedWithUid.startsWith('pending_')
                ? '${access.sharedWithUid}@magicdiary.internal'
                : ''));

    final target = safeEmail.isNotEmpty ? safeEmail : access.sharedWithUid;
    final primaryDocId = generateShareId(
      ownerUid: access.ownerUid,
      diaryId: access.diaryId,
      target: target,
    );

    Future<void> writeShareDoc(String docId) async {
      try {
        final docRef = _sharesRef.doc(docId);
        final existingDoc = await docRef.get();
        final now = DateTime.now();

        final Map<String, dynamic> data = access.toMap();
        data['id'] = docId;
        data['sharedWithEmail'] = safeEmail;
        data['updatedAt'] = Timestamp.fromDate(now);

        if (existingDoc.exists && existingDoc.data() != null) {
          final existing = existingDoc.data()!;
          if (existing['createdAt'] != null) {
            data['createdAt'] = existing['createdAt'];
          }
          if (existing['ownerUid'] != null) {
            data['ownerUid'] = existing['ownerUid'];
          }
          if (existing['diaryId'] != null) {
            data['diaryId'] = existing['diaryId'];
          }
          if (existing['id'] != null) {
            data['id'] = existing['id'];
          }
        } else {
          data['createdAt'] = Timestamp.fromDate(access.createdAt);
        }

        await docRef.set(data, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error writing share doc $docId: $e');
        if (docId == primaryDocId) {
          rethrow;
        }
      }
    }

    // 1. Save primary access record by deterministic email/target ID
    await writeShareDoc(primaryDocId);

    // 2. If shared with a real UID (not pending), save both exact UID and lowercased UID docId for O(1) rules
    if (access.sharedWithUid.isNotEmpty && !access.sharedWithUid.startsWith('pending_')) {
      final exactUidDocId = '${access.ownerUid}_${access.diaryId}_${access.sharedWithUid.trim().replaceAll('/', '_')}';
      final lowerUidDocId = '${access.ownerUid}_${access.diaryId}_${access.sharedWithUid.trim().toLowerCase().replaceAll('/', '_')}';

      if (exactUidDocId != primaryDocId) {
        await writeShareDoc(exactUidDocId);
      }
      if (lowerUidDocId != primaryDocId && lowerUidDocId != exactUidDocId) {
        await writeShareDoc(lowerUidDocId);
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

    // Sync sharedWithUids array on records for query-compatible Firestore security rules
    if (current.sharedWithUid.isNotEmpty && !current.sharedWithUid.startsWith('pending_')) {
      final batch = _firestore.batch();
      for (final recId in recordIds) {
        final recRef = _firestore
            .collection('users')
            .doc(current.ownerUid)
            .collection('diaries')
            .doc(current.diaryId)
            .collection('records')
            .doc(recId);
        batch.set(recRef, {
          'sharedWithUids': FieldValue.arrayUnion([current.sharedWithUid]),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
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

    // Sync sharedWithUids removal on records
    if (current.sharedWithUid.isNotEmpty && !current.sharedWithUid.startsWith('pending_')) {
      final batch = _firestore.batch();
      for (final recId in recordIds) {
        final recRef = _firestore
            .collection('users')
            .doc(current.ownerUid)
            .collection('diaries')
            .doc(current.diaryId)
            .collection('records')
            .doc(recId);
        batch.update(recRef, {
          'sharedWithUids': FieldValue.arrayRemove([current.sharedWithUid]),
        });
      }
      await batch.commit();
    }
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
    // 1. Direct UID lookup (check exact UID first, then lowercased UID)
    final exactUidDocId = '${ownerUid}_${diaryId}_${uid.trim().replaceAll('/', '_')}';
    final exactDoc = await _sharesRef.doc(exactUidDocId).get();
    if (exactDoc.exists && exactDoc.data() != null) {
      final access = SharedDiaryAccess.fromMap(exactDoc.data()!, exactDoc.id);
      if (!access.isExpired) return access;
    }

    final lowerUidDocId = '${ownerUid}_${diaryId}_${uid.trim().toLowerCase().replaceAll('/', '_')}';
    if (lowerUidDocId != exactUidDocId) {
      final lowerDoc = await _sharesRef.doc(lowerUidDocId).get();
      if (lowerDoc.exists && lowerDoc.data() != null) {
        final access = SharedDiaryAccess.fromMap(lowerDoc.data()!, lowerDoc.id);
        if (!access.isExpired) return access;
      }
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
