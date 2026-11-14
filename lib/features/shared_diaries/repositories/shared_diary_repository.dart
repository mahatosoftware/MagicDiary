import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shared_diary_models.dart';

class SharedDiaryRepository {
  final FirebaseFirestore _firestore;

  SharedDiaryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sharesRef =>
      _firestore.collection('shared_diary_access');

  Future<void> createShareAccess(SharedDiaryAccess access) async {
    await _sharesRef.doc(access.id).set(access.toMap(), SetOptions(merge: true));
  }

  Future<void> revokeShareAccess(String accessId) async {
    await _sharesRef.doc(accessId).delete();
  }

  Future<void> updatePermission(String accessId, SharedDiaryPermission permission) async {
    await _sharesRef.doc(accessId).update({
      'permission': permission.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Stream<List<SharedDiaryAccess>> watchSharedWithMe(String uid) {
    return _sharesRef
        .where('sharedWithUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedDiaryAccess.fromMap(doc.data(), doc.id))
            .where((s) => !s.isExpired)
            .toList());
  }

  Stream<List<SharedDiaryAccess>> watchSharedByMe(String uid) {
    return _sharesRef
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedDiaryAccess.fromMap(doc.data(), doc.id))
            .toList());
  }
}
