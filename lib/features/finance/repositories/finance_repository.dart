import 'package:cloud_firestore/cloud_firestore.dart';
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
