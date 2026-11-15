import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared_diaries/repositories/frequent_contacts_repository.dart';
import '../../shared_diaries/repositories/shared_diary_repository.dart';
import '../screens/magic_circles_screen.dart';

class ConnectedUser {
  final String uid;
  final String email;
  final String displayName;
  final String? username;
  final String sourceDescription;
  final int interactionCount;

  const ConnectedUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.username,
    required this.sourceDescription,
    this.interactionCount = 1,
  });

  ConnectedUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? username,
    String? sourceDescription,
    int? interactionCount,
  }) {
    return ConnectedUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      sourceDescription: sourceDescription ?? this.sourceDescription,
      interactionCount: interactionCount ?? this.interactionCount,
    );
  }
}

/// Provides a unified list of people already connected to the current user
/// through previous sharing (Frequent Contacts, Shared Diaries, and Magic Circles).
final connectedUsersStreamProvider =
    StreamProvider.autoDispose<List<ConnectedUser>>((ref) {
  final currentUser = ref.watch(userProfileProvider);
  if (currentUser == null) {
    return Stream.value(const []);
  }

  final controller = StreamController<List<ConnectedUser>>.broadcast();

  final frequentContactsRepo = ref.watch(frequentContactsRepositoryProvider);
  final sharedDiaryRepo = ref.watch(sharedDiaryRepositoryProvider);
  final circleRepo = ref.watch(magicCircleRepositoryProvider);

  StreamSubscription? subFrequent;
  StreamSubscription? subSharedWithMe;
  StreamSubscription? subSharedByMe;
  StreamSubscription? subCircles;

  final Map<String, ConnectedUser> map = {};

  void emit() {
    if (controller.isClosed) return;
    final list = map.values.toList()
      ..sort((a, b) => b.interactionCount.compareTo(a.interactionCount));
    controller.add(list);
  }

  // 1. Frequent contacts
  subFrequent =
      frequentContactsRepo.watchFrequentContacts(currentUser.uid).listen((contacts) {
    for (final c in contacts) {
      if (c.email.trim().toLowerCase() == currentUser.email.trim().toLowerCase()) continue;
      final key = c.email.trim().toLowerCase();
      map[key] = ConnectedUser(
        uid: '',
        email: c.email,
        displayName: c.displayName.isNotEmpty ? c.displayName : c.email.split('@').first,
        username: c.username,
        sourceDescription: 'Frequent Contact',
        interactionCount: c.useCount + 5,
      );
    }
    emit();
  }, onError: (_) => emit());

  // 2. Shared with me
  subSharedWithMe = sharedDiaryRepo
      .watchSharedWithMe(
        uid: currentUser.uid,
        email: currentUser.email,
        displayName: currentUser.displayName,
      )
      .listen((shares) {
    for (final s in shares) {
      if (s.ownerUid == currentUser.uid) continue;
      final key = s.ownerUid.isNotEmpty ? s.ownerUid : s.ownerName;
      if (!map.containsKey(key)) {
        map[key] = ConnectedUser(
          uid: s.ownerUid,
          email: '${s.ownerUid}@magicdiary.user',
          displayName: s.ownerName.isNotEmpty ? s.ownerName : 'Collaborator',
          sourceDescription: 'Owner of "${s.diaryName}"',
          interactionCount: 3,
        );
      }
    }
    emit();
  }, onError: (_) => emit());

  // 3. Shared by me
  subSharedByMe =
      sharedDiaryRepo.watchSharedByMe(currentUser.uid).listen((shares) {
    for (final s in shares) {
      final email = s.sharedWithEmail.trim().toLowerCase();
      if (email.isEmpty || email == currentUser.email.trim().toLowerCase()) continue;
      final key = email;
      final existing = map[key];
      if (existing == null) {
        map[key] = ConnectedUser(
          uid: s.sharedWithUid,
          email: s.sharedWithEmail,
          displayName: s.sharedWithName.isNotEmpty ? s.sharedWithName : s.sharedWithEmail.split('@').first,
          sourceDescription: 'Shared diary collaborator',
          interactionCount: 2,
        );
      } else {
        map[key] = existing.copyWith(
          interactionCount: existing.interactionCount + 1,
        );
      }
    }
    emit();
  }, onError: (_) => emit());

  // 4. Other circles
  subCircles = circleRepo
      .watchUserCircles(
          uid: currentUser.uid,
          email: currentUser.email,
          displayName: currentUser.displayName)
      .listen((circles) {
    for (final circle in circles) {
      for (final m in circle.members) {
        if (m.uid == currentUser.uid ||
            m.email.trim().toLowerCase() == currentUser.email.trim().toLowerCase()) {
          continue;
        }
        final key = m.email.trim().toLowerCase();
        if (key.isNotEmpty) {
          final existing = map[key];
          if (existing == null) {
            map[key] = ConnectedUser(
              uid: m.uid,
              email: m.email,
              displayName: m.displayName,
              sourceDescription: 'Member of "${circle.name}"',
              interactionCount: 4,
            );
          } else {
            map[key] = existing.copyWith(
              uid: (existing.uid.isEmpty && m.uid.isNotEmpty) ? m.uid : existing.uid,
              interactionCount: existing.interactionCount + 2,
            );
          }
        }
      }
    }
    emit();
  }, onError: (_) => emit());

  controller.onCancel = () {
    subFrequent?.cancel();
    subSharedWithMe?.cancel();
    subSharedByMe?.cancel();
    subCircles?.cancel();
  };

  return controller.stream;
});
