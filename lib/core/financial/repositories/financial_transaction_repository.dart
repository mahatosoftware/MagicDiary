import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/financial_transaction.dart';

/// Repository managing canonical FinancialTransaction records in Cloud Firestore.
/// Collection path: `users/{userId}/financialTransactions/{transactionId}`
class FinancialTransactionRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  FinancialTransactionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('financialTransactions');
  }

  /// Create or idempotently record a financial transaction.
  /// If transaction ID is empty, assigns a fresh UUID or generates deterministic ID.
  Future<FinancialTransaction> recordTransaction(String userId, FinancialTransaction tx) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');

    final String finalId = tx.id.isNotEmpty
        ? tx.id
        : (tx.sourceRecordId != null
            ? FinancialTransaction.generateDeterministicId(tx.sourceModule, tx.sourceRecordId!)
            : _uuid.v4());

    final now = DateTime.now();
    final updatedTx = tx.copyWith(
      id: finalId,
      userId: userId,
      createdAt: tx.createdAt,
      updatedAt: now,
    );

    await _collection(userId).doc(finalId).set(
          updatedTx.toMap(),
          SetOptions(merge: true),
        );

    return updatedTx;
  }

  /// Batch upsert transactions (useful for safe migration & multi-record commits)
  Future<void> batchUpsert(String userId, List<FinancialTransaction> transactions) async {
    if (userId.isEmpty || transactions.isEmpty) return;

    final batch = _firestore.batch();
    for (final tx in transactions) {
      final docRef = _collection(userId).doc(tx.id);
      batch.set(docRef, tx.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Query transactions within an optional date range and filters
  Future<List<FinancialTransaction>> getTransactions(
    String userId, {
    DateTime? start,
    DateTime? end,
    String? categoryId,
    TransactionType? type,
    String? sourceModule,
    bool includeDeleted = false,
  }) async {
    if (userId.isEmpty) return const [];

    try {
      Query<Map<String, dynamic>> query = _collection(userId);

      if (!includeDeleted) {
        query = query.where('isDeleted', isEqualTo: false);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.toDbString());
      }

      if (sourceModule != null && sourceModule != 'All') {
        query = query.where('sourceModule', isEqualTo: sourceModule);
      }

      final snapshot = await query.get();
      var list = snapshot.docs.map((d) => FinancialTransaction.fromMap(d.data(), d.id)).toList();

      // Apply in-memory filtering for dates and category to avoid complex composite index requirements
      if (start != null) {
        list = list.where((t) => t.transactionDate.isAtSameMomentAs(start) || t.transactionDate.isAfter(start)).toList();
      }
      if (end != null) {
        list = list.where((t) => t.transactionDate.isAtSameMomentAs(end) || t.transactionDate.isBefore(end)).toList();
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        list = list.where((t) => t.categoryId == categoryId).toList();
      }

      list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      return list;
    } catch (e) {
      return const [];
    }
  }

  /// Stream live transactions for reactive UI updates
  Stream<List<FinancialTransaction>> watchTransactions(String userId, {bool includeDeleted = false}) {
    if (userId.isEmpty) return Stream.value(const []);

    Query<Map<String, dynamic>> query = _collection(userId);
    if (!includeDeleted) {
      query = query.where('isDeleted', isEqualTo: false);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((d) => FinancialTransaction.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      return list;
    });
  }

  /// Fetch single transaction by ID
  Future<FinancialTransaction?> getTransactionById(String userId, String transactionId) async {
    if (userId.isEmpty || transactionId.isEmpty) return null;
    try {
      final doc = await _collection(userId).doc(transactionId).get();
      if (!doc.exists || doc.data() == null) return null;
      return FinancialTransaction.fromMap(doc.data()!, doc.id);
    } catch (e) {
      return null;
    }
  }

  /// Find transaction linked to a source diary record
  Future<FinancialTransaction?> getBySourceRecord(String userId, String sourceModule, String sourceRecordId) async {
    if (userId.isEmpty || sourceRecordId.isEmpty) return null;
    final detId = FinancialTransaction.generateDeterministicId(sourceModule, sourceRecordId);
    return getTransactionById(userId, detId);
  }

  /// Delete transaction (soft delete by default to maintain audit trail)
  Future<void> deleteTransaction(String userId, String transactionId, {bool softDelete = true}) async {
    if (userId.isEmpty || transactionId.isEmpty) return;

    if (softDelete) {
      await _collection(userId).doc(transactionId).update({
        'isDeleted': true,
        'updatedAt': Timestamp.now(),
      });
    } else {
      await _collection(userId).doc(transactionId).delete();
    }
  }
}
