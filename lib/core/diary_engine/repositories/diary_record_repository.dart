import 'dart:async';
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

  DocumentReference<Map<String, dynamic>> _recordPrivateDataRef({
    required String userId,
    required String diaryId,
    required String recordId,
  }) {
    return _userRecordsRef(userId, diaryId)
        .doc(recordId)
        .collection('private_data')
        .doc('details');
  }

  DocumentReference<Map<String, dynamic>> _recordSecurePayloadRef({
    required String userId,
    required String diaryId,
    required String recordId,
  }) {
    return _userRecordsRef(userId, diaryId)
        .doc(recordId)
        .collection('private_data')
        .doc('secure_payload');
  }

  /// Saves a diary record.
  /// If [record.restrictedFields] is non-empty, sensitive fields are isolated into
  /// a separate `/private_data/secure_payload` subcollection protected by independent
  /// Firestore security rules, preventing unauthorized over-the-wire retrieval.
  Future<void> saveRecord({
    required String userId,
    required DiaryRecord record,
  }) async {
    final recordRef = _userRecordsRef(userId, record.sourceDiaryId).doc(record.id);

    if (record.restrictedFields.isNotEmpty) {
      final sensitiveData = <String, dynamic>{};
      final publicFields = Map<String, dynamic>.from(record.fields);

      for (final key in record.restrictedFields) {
        if (publicFields.containsKey(key)) {
          sensitiveData[key] = publicFields.remove(key);
        }
      }

      final isAmountRestricted = record.restrictedFields.contains('amount');
      if (isAmountRestricted && record.amount != null) {
        sensitiveData['amount'] = record.amount;
      }
      if (isAmountRestricted && record.amountMinor != null) {
        sensitiveData['amountMinor'] = record.amountMinor;
      }

      final sanitizedRecord = record.copyWith(
        fields: publicFields,
        clearAmount: isAmountRestricted,
        hasRestrictedData: true,
        restrictedFieldKeys: record.restrictedFields,
      );

      final batch = _firestore.batch();
      batch.set(recordRef, sanitizedRecord.toMap(), SetOptions(merge: true));

      final payload = {
        'recordId': record.id,
        'ownerId': userId,
        'diaryId': record.sourceDiaryId,
        'sensitiveFields': sensitiveData,
        'restrictedFields': record.restrictedFields,
        'updatedAt': Timestamp.now(),
      };

      // Write to both secure_payload and details for resilience and migration
      final securePayloadRef = _recordSecurePayloadRef(
        userId: userId,
        diaryId: record.sourceDiaryId,
        recordId: record.id,
      );
      batch.set(securePayloadRef, payload, SetOptions(merge: true));

      final privateRef = _recordPrivateDataRef(
        userId: userId,
        diaryId: record.sourceDiaryId,
        recordId: record.id,
      );
      batch.set(privateRef, payload, SetOptions(merge: true));

      await batch.commit();
    } else {
      await recordRef.set(record.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> deleteRecord({
    required String userId,
    required String diaryId,
    required String recordId,
  }) async {
    final batch = _firestore.batch();
    final recordRef = _userRecordsRef(userId, diaryId).doc(recordId);
    final privateRef = _recordPrivateDataRef(
      userId: userId,
      diaryId: diaryId,
      recordId: recordId,
    );
    final securePayloadRef = _recordSecurePayloadRef(
      userId: userId,
      diaryId: diaryId,
      recordId: recordId,
    );

    batch.delete(privateRef);
    batch.delete(securePayloadRef);
    batch.delete(recordRef);
    await batch.commit();
  }

  /// Retrieves a record.
  /// If the record contains restricted fields, seamlessly attempts to load and merge
  /// `/private_data/secure_payload` (or `/private_data/details`). If the caller is restricted,
  /// Firestore Security Rules will deny access to the subcollection, leaving sensitive fields securely absent.
  Future<DiaryRecord?> getRecord({
    required String userId,
    required String diaryId,
    required String recordId,
  }) async {
    final doc = await _userRecordsRef(userId, diaryId).doc(recordId).get();
    if (!doc.exists || doc.data() == null) return null;
    var record = DiaryRecord.fromMap(doc.data()!, doc.id);

    if (record.restrictedFields.isNotEmpty || record.hasRestrictedData) {
      try {
        var privateDoc = await _recordSecurePayloadRef(
          userId: userId,
          diaryId: diaryId,
          recordId: recordId,
        ).get();

        if (!privateDoc.exists || privateDoc.data() == null) {
          privateDoc = await _recordPrivateDataRef(
            userId: userId,
            diaryId: diaryId,
            recordId: recordId,
          ).get();
        }

        if (privateDoc.exists && privateDoc.data() != null) {
          final data = privateDoc.data()!;
          final sensitiveFields = Map<String, dynamic>.from(
              data['sensitiveFields'] as Map? ?? {});

          final mergedFields = Map<String, dynamic>.from(record.fields)
            ..addAll(sensitiveFields);

          final restoredAmount = sensitiveFields.containsKey('amount')
              ? (sensitiveFields['amount'] as num?)?.toDouble()
              : record.amount;

          final restoredAmountMinor = sensitiveFields.containsKey('amountMinor')
              ? (sensitiveFields['amountMinor'] as num?)?.toInt()
              : record.amountMinor;

          record = record.copyWith(
            fields: mergedFields,
            amount: restoredAmount,
            amountMinor: restoredAmountMinor,
          );
        }
      } catch (_) {
        // PERMISSION_DENIED: caller is unauthorized to view private_data.
        // The record safely remains in its redacted state at the data layer.
      }
    }

    return record;
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

  /// Checks for potential duplicate records in the same diary to avoid duplicate entries.
  /// Matches records with the same title (case-insensitive, trimmed)
  /// and optionally the same recordDate.
  Future<DiaryRecord?> findPotentialDuplicate({
    required String userId,
    required String diaryId,
    required String title,
    DateTime? recordDate,
    String? excludeRecordId,
  }) async {
    final records = await getRecords(userId: userId, diaryId: diaryId);
    final cleanTitle = title.trim().toLowerCase();
    for (final rec in records) {
      if (excludeRecordId != null && rec.id == excludeRecordId) continue;
      if (rec.title.trim().toLowerCase() == cleanTitle) {
        if (recordDate != null) {
          if (rec.recordDate.year == recordDate.year &&
              rec.recordDate.month == recordDate.month &&
              rec.recordDate.day == recordDate.day) {
            return rec;
          }
        } else {
          return rec;
        }
      }
    }
    return null;
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

  /// Stream a single record with real-time private_data details merged.
  Stream<DiaryRecord?> watchRecordWithPrivateData({
    required String userId,
    required String diaryId,
    required String recordId,
  }) {
    return _userRecordsRef(userId, diaryId).doc(recordId).snapshots().asyncMap((doc) async {
      if (!doc.exists || doc.data() == null) return null;
      var record = DiaryRecord.fromMap(doc.data()!, doc.id);

      if (record.restrictedFields.isNotEmpty) {
        try {
          final privateDoc = await _recordPrivateDataRef(
            userId: userId,
            diaryId: diaryId,
            recordId: recordId,
          ).get();

          if (privateDoc.exists && privateDoc.data() != null) {
            final data = privateDoc.data()!;
            final sensitiveFields = Map<String, dynamic>.from(
                data['sensitiveFields'] as Map? ?? {});

            final mergedFields = Map<String, dynamic>.from(record.fields)
              ..addAll(sensitiveFields);

            final restoredAmount = sensitiveFields.containsKey('amount')
                ? (sensitiveFields['amount'] as num?)?.toDouble()
                : record.amount;

            record = record.copyWith(
              fields: mergedFields,
              amount: restoredAmount,
            );
          }
        } catch (_) {}
      }

      return record;
    });
  }
}
