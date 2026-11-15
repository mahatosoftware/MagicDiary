import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/frequent_contact.dart';

final frequentContactsRepositoryProvider =
    Provider<FrequentContactsRepository>((ref) => FrequentContactsRepository());

/// Stream provider watching the current user's frequent contacts sorted by frequency
final frequentContactsStreamProvider =
    StreamProvider.autoDispose.family<List<FrequentContact>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value([]);
  final repo = ref.watch(frequentContactsRepositoryProvider);
  return repo.watchFrequentContacts(userId);
});

/// Suggestions provider filtering frequent contacts by search query in real-time
final frequentContactSuggestionsProvider = FutureProvider.autoDispose
    .family<List<FrequentContact>, ({String userId, String query})>((ref, arg) async {
  if (arg.userId.isEmpty) return [];
  final repo = ref.watch(frequentContactsRepositoryProvider);
  return repo.lookupSuggestions(arg.userId, arg.query);
});

class FrequentContactsRepository {
  final FirebaseFirestore? _firestoreInstance;

  FrequentContactsRepository({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _contactsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('frequent_contacts');
  }

  /// Real-time stream of frequent contacts for a user, sorted by frequency (useCount) descending
  Stream<List<FrequentContact>> watchFrequentContacts(String userId, {int limit = 25}) {
    if (userId.isEmpty) return Stream.value([]);

    try {
      return _contactsRef(userId)
          .orderBy('useCount', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          return FrequentContact.fromMap(doc.data(), doc.id);
        }).toList();

        // Secondary in-memory sort by lastUsedAt descending
        list.sort((a, b) {
          final countComp = b.useCount.compareTo(a.useCount);
          if (countComp != 0) return countComp;
          return b.lastUsedAt.compareTo(a.lastUsedAt);
        });

        return list;
      });
    } catch (e) {
      debugPrint('Error watching frequent contacts for $userId: $e');
      return Stream.value([]);
    }
  }

  /// Get frequent contacts for a user
  Future<List<FrequentContact>> getFrequentContacts(String userId, {int limit = 25}) async {
    if (userId.isEmpty) return [];
    try {
      final snapshot = await _contactsRef(userId)
          .orderBy('useCount', descending: true)
          .limit(limit)
          .get();

      final list = snapshot.docs.map((doc) {
        return FrequentContact.fromMap(doc.data(), doc.id);
      }).toList();

      list.sort((a, b) {
        final countComp = b.useCount.compareTo(a.useCount);
        if (countComp != 0) return countComp;
        return b.lastUsedAt.compareTo(a.lastUsedAt);
      });

      return list;
    } catch (e) {
      debugPrint('Error getting frequent contacts: $e');
      return [];
    }
  }

  /// Lookup contact suggestions matching a search query (matches email, name, or username)
  Future<List<FrequentContact>> lookupSuggestions(
    String userId,
    String query, {
    int limit = 6,
  }) async {
    final contacts = await getFrequentContacts(userId, limit: 50);
    final clean = query.trim().toLowerCase();

    if (clean.isEmpty) {
      // If query is empty, return top frequent contacts
      return contacts.take(limit).toList();
    }

    final matched = contacts.where((c) => c.matchesQuery(clean)).take(limit).toList();
    return matched;
  }

  /// Records usage of a contact when sharing or sending an invite.
  /// If the contact already exists for this user, increments useCount and updates lastUsedAt.
  /// If it does not exist, creates a new FrequentContact record.
  Future<FrequentContact> recordContactUsage({
    required String userId,
    required String email,
    String? name,
    String? username,
    String? photoUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw ArgumentError('Contact email cannot be empty');
    }

    final docId = FrequentContact.generateId(userId, cleanEmail);
    final docRef = _contactsRef(userId).doc(docId);
    final now = DateTime.now();

    try {
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final existing = FrequentContact.fromMap(docSnapshot.data()!, docId);
        final newUseCount = existing.useCount + 1;
        final updatedName = (name != null && name.trim().isNotEmpty) ? name.trim() : existing.name;
        final updatedUsername =
            (username != null && username.trim().isNotEmpty) ? username.trim() : existing.username;
        final updatedPhoto = photoUrl ?? existing.photoUrl;

        final updated = existing.copyWith(
          name: updatedName,
          username: updatedUsername,
          photoUrl: updatedPhoto,
          useCount: newUseCount,
          lastUsedAt: now,
          updatedAt: now,
        );

        await docRef.set(updated.toMap(), SetOptions(merge: true));
        return updated;
      } else {
        final newContact = FrequentContact(
          id: docId,
          userId: userId,
          email: cleanEmail,
          name: name?.trim() ?? '',
          username: username?.trim(),
          photoUrl: photoUrl,
          useCount: 1,
          lastUsedAt: now,
          createdAt: now,
          updatedAt: now,
        );

        await docRef.set(newContact.toMap());
        return newContact;
      }
    } catch (e) {
      debugPrint('Error recording contact usage for $cleanEmail: $e');
      // Return a transient instance if network/firestore write failed
      return FrequentContact(
        id: docId,
        userId: userId,
        email: cleanEmail,
        name: name?.trim() ?? '',
        username: username?.trim(),
        photoUrl: photoUrl,
        useCount: 1,
        lastUsedAt: now,
        createdAt: now,
      );
    }
  }

  /// Automatically seeds frequent contacts from the user's past shared diary records
  Future<int> seedFromExistingShares(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final sharesSnapshot = await _firestore
          .collection('shared_diary_access')
          .where('ownerUid', isEqualTo: userId)
          .get();

      int count = 0;
      final seenEmails = <String>{};

      for (final doc in sharesSnapshot.docs) {
        final data = doc.data();
        final email = (data['sharedWithEmail'] as String? ?? '').trim().toLowerCase();
        final name = (data['sharedWithName'] as String? ?? '').trim();
        final recipientType = data['recipientType'] as String? ?? 'user';

        if (email.isNotEmpty && email.contains('@') && recipientType == 'user') {
          if (!seenEmails.contains(email)) {
            seenEmails.add(email);
            await recordContactUsage(
              userId: userId,
              email: email,
              name: name.isNotEmpty ? name : null,
            );
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error seeding frequent contacts from shares: $e');
      return 0;
    }
  }

  /// Remove a frequent contact
  Future<void> deleteContact(String userId, String contactId) async {
    try {
      await _contactsRef(userId).doc(contactId).delete();
    } catch (e) {
      debugPrint('Error deleting frequent contact $contactId: $e');
    }
  }
}
