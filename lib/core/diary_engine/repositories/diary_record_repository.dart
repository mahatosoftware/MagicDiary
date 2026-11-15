import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diary_record.dart';

class DiaryRecordRepository {
  final FirebaseFirestore _firestore;

  DiaryRecordRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userRecordsRef(
      String userId, String diaryId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('diaries')
        .doc(diaryId)
        .collection('records');
  }

  Future<void> saveRecord({
    required String userId,
    required DiaryRecord record,
  }) async {
    final ref = _userRecordsRef(userId, record.sourceDiaryId).doc(record.id);
    await ref.set(record.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteRecord({
    required String userId,
    required String diaryId,
    required String recordId,
  }) async {
    await _userRecordsRef(userId, diaryId).doc(recordId).delete();
  }

  Future<DiaryRecord?> getRecord({
    required String userId,
    required String diaryId,
    required String recordId,
  }) async {
    final doc = await _userRecordsRef(userId, diaryId).doc(recordId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DiaryRecord.fromMap(doc.data()!, doc.id);
  }

  Stream<List<DiaryRecord>> watchRecords({
    required String userId,
    required String diaryId,
  }) {
    return _userRecordsRef(userId, diaryId)
        .orderBy('recordDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiaryRecord.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<List<DiaryRecord>> getRecords({
    required String userId,
    required String diaryId,
  }) async {
    final snapshot = await _userRecordsRef(userId, diaryId)
        .orderBy('recordDate', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => DiaryRecord.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Reads named records individually. This is required for selected-record
  /// shares: Firestore cannot authorize an unconstrained collection query when
  /// access is granted to only a known list of record IDs.
  Future<List<DiaryRecord>> getRecordsByIds({
    required String userId,
    required String diaryId,
    required Iterable<String> recordIds,
  }) async {
    final records = await Future.wait(
      recordIds.toSet().map(
            (recordId) => getRecord(
              userId: userId,
              diaryId: diaryId,
              recordId: recordId,
            ),
          ),
    );
    final resolved = records.whereType<DiaryRecord>().toList()
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
    return resolved;
  }
}
