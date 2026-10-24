import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/financial/models/financial_category.dart';
import '../../../core/financial/models/financial_transaction.dart' as canonical;
import '../../../core/financial/repositories/financial_transaction_repository.dart';
import '../models/finance_models.dart';

class FinanceRepository {
  final FirebaseFirestore? _firestore;
  FinanceRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<List<FinancialTransaction>> getTransactions(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .get();
      final list = snapshot.docs.map((doc) => FinancialTransaction.fromJson(doc.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      return const [];
    }
  }

  Future<List<InvestmentRecord>> getInvestments(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('investments')
          .get();
      return snapshot.docs.map((doc) => InvestmentRecord.fromJson(doc.data())).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<void> addTransaction(String userId, FinancialTransaction tx) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(tx.id)
        .set(tx.toJson());

    // Sync to canonical financial transaction collection
    try {
      final txRepo = FinancialTransactionRepository(firestore: firestore);
      final isIncome = tx.type.toLowerCase() == 'income';
      final isTransfer = tx.type.toLowerCase() == 'transfer' ||
          tx.category.toLowerCase().contains('sip') ||
          tx.category.toLowerCase().contains('investment');

      canonical.TransactionType type = canonical.TransactionType.expense;
      if (isTransfer) {
        type = canonical.TransactionType.transfer;
      } else if (isIncome) {
        type = canonical.TransactionType.income;
      }

      await txRepo.recordTransaction(
        userId,
        canonical.FinancialTransaction.fromMajorUnits(
          id: canonical.FinancialTransaction.generateDeterministicId('finance', tx.id),
          userId: userId,
          type: type,
          amountMajor: tx.amount,
          categoryId: CategoryRegistry.mapLegacyToCategoryId(tx.category, tx.description),
          sourceModule: 'finance',
          sourceRecordId: tx.id,
          description: tx.description.isNotEmpty ? tx.description : tx.category,
          transactionDate: tx.date,
          paymentMethod: tx.paymentMethod,
        ),
      );
    } catch (_) {}
  }

  Future<void> addInvestment(String userId, InvestmentRecord inv) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('investments')
        .doc(inv.id)
        .set(inv.toJson());
  }

  Future<void> deleteTransaction(String userId, String transactionId) async {
    if (userId.isEmpty || transactionId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(transactionId)
        .delete();

    try {
      final txRepo = FinancialTransactionRepository(firestore: firestore);
      final detId = canonical.FinancialTransaction.generateDeterministicId('finance', transactionId);
      await txRepo.deleteTransaction(userId, detId, softDelete: true);
    } catch (_) {}
  }

  Future<void> deleteInvestment(String userId, String investmentId) async {
    if (userId.isEmpty || investmentId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('investments')
        .doc(investmentId)
        .delete();
  }
}
