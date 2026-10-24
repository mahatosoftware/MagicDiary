import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/financial_obligation.dart';

/// Repository managing FinancialObligation records in Cloud Firestore.
/// Collection path: `users/{userId}/financialObligations/{obligationId}`
class FinancialObligationRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  FinancialObligationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('financialObligations');
  }

  /// Record or update an obligation idempotently
  Future<FinancialObligation> recordObligation(String userId, FinancialObligation obligation) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');

    final String finalId = obligation.id.isNotEmpty
        ? obligation.id
        : (obligation.sourceRecordId != null
            ? FinancialObligation.generateDeterministicId(obligation.sourceModule, obligation.sourceRecordId!)
            : _uuid.v4());

    final now = DateTime.now();
    final updated = obligation.copyWith(
      id: finalId,
      userId: userId,
      createdAt: obligation.createdAt,
      updatedAt: now,
    );

    await _collection(userId).doc(finalId).set(
          updated.toMap(),
          SetOptions(merge: true),
        );

    return updated;
  }

  /// Batch upsert obligations
  Future<void> batchUpsert(String userId, List<FinancialObligation> obligations) async {
    if (userId.isEmpty || obligations.isEmpty) return;

    final batch = _firestore.batch();
    for (final ob in obligations) {
      final docRef = _collection(userId).doc(ob.id);
      batch.set(docRef, ob.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Query obligations
  Future<List<FinancialObligation>> getObligations(
    String userId, {
    DateTime? dueBefore,
    ObligationStatus? status,
    String? sourceModule,
  }) async {
    if (userId.isEmpty) return const [];

    try {
      Query<Map<String, dynamic>> query = _collection(userId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.toDbString());
      }
      if (sourceModule != null && sourceModule != 'All') {
        query = query.where('sourceModule', isEqualTo: sourceModule);
      }

      final snapshot = await query.get();
      var list = snapshot.docs.map((d) => FinancialObligation.fromMap(d.data(), d.id)).toList();

      if (dueBefore != null) {
        list = list.where((o) => o.dueDate.isBefore(dueBefore) || o.dueDate.isAtSameMomentAs(dueBefore)).toList();
      }

      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    } catch (e) {
      return const [];
    }
  }

  /// Stream live obligations
  Stream<List<FinancialObligation>> watchObligations(String userId) {
    if (userId.isEmpty) return Stream.value(const []);

    return _collection(userId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((d) => FinancialObligation.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  /// Record payment fulfillment against an obligation
  Future<void> fulfillObligation(
    String userId,
    String obligationId,
    int paymentAmountMinorUnits, {
    String? transactionId,
  }) async {
    if (userId.isEmpty || obligationId.isEmpty) return;

    final docRef = _collection(userId).doc(obligationId);
    final doc = await docRef.get();
    if (!doc.exists || doc.data() == null) return;

    final current = FinancialObligation.fromMap(doc.data()!, doc.id);
    final newPaidMinor = current.paidAmountMinorUnits + paymentAmountMinorUnits;
    final isFullyPaid = newPaidMinor >= current.expectedAmountMinorUnits;

    await docRef.update({
      'paidAmountMinorUnits': newPaidMinor,
      'status': isFullyPaid ? ObligationStatus.paid.toDbString() : ObligationStatus.partiallyPaid.toDbString(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteObligation(String userId, String obligationId) async {
    if (userId.isEmpty || obligationId.isEmpty) return;
    await _collection(userId).doc(obligationId).delete();
  }
}
