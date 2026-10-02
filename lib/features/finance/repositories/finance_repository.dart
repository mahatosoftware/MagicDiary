import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/finance_models.dart';

class FinanceRepository {
  final FirebaseFirestore? _firestore;
  FinanceRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  final List<FinancialTransaction> _mockTransactions = [
    FinancialTransaction(
      id: 'tx_1',
      type: 'Income',
      category: 'Salary',
      amount: 145000.0,
      date: DateTime.now().subtract(const Duration(days: 2)),
      description: 'Monthly Salary Credit',
      paymentMethod: 'Bank Transfer',
    ),
    FinancialTransaction(
      id: 'tx_2',
      type: 'Expense',
      category: 'EMI',
      amount: 28500.0,
      date: DateTime.now().subtract(const Duration(days: 5)),
      description: 'Home Loan Auto-Debit EMI',
      paymentMethod: 'Bank Transfer',
    ),
    FinancialTransaction(
      id: 'tx_3',
      type: 'Expense',
      category: 'Credit Card',
      amount: 14200.0,
      date: DateTime.now().subtract(const Duration(days: 10)),
      description: 'HDFC Regalia Credit Card Statement',
      paymentMethod: 'UPI',
    ),
  ];

  final List<InvestmentRecord> _mockInvestments = [
    InvestmentRecord(
      id: 'inv_1',
      title: 'HDFC Tax Saver FD',
      type: 'FD',
      investedAmount: 150000.0,
      currentAmount: 172000.0,
      maturityDate: DateTime.now().add(const Duration(days: 180)),
      accountNumber: 'FD-9920112',
    ),
    InvestmentRecord(
      id: 'inv_2',
      title: 'Nifty 50 Index Fund SIP',
      type: 'SIP',
      investedAmount: 240000.0,
      currentAmount: 310500.0,
      maturityDate: DateTime.now().add(const Duration(days: 730)),
      accountNumber: 'MF-8831920',
    ),
  ];

  Future<List<FinancialTransaction>> getTransactions(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockTransactions);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('financialTransactions')
        .get();
    return snapshot.docs.map((doc) => FinancialTransaction.fromJson(doc.data())).toList();
  }

  Future<List<InvestmentRecord>> getInvestments(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockInvestments);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('investments')
        .get();
    return snapshot.docs.map((doc) => InvestmentRecord.fromJson(doc.data())).toList();
  }

  Future<void> addTransaction(String userId, FinancialTransaction tx, {bool isDemo = true}) async {
    if (isDemo) {
      _mockTransactions.add(tx);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('financialTransactions')
        .doc(tx.id)
        .set(tx.toJson());
  }

  Future<void> addInvestment(String userId, InvestmentRecord inv, {bool isDemo = true}) async {
    if (isDemo) {
      _mockInvestments.add(inv);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('investments')
        .doc(inv.id)
        .set(inv.toJson());
  }
}
