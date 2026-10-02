import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/mock_data.dart';
import '../models/bills_models.dart';

class BillsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final List<BillAccount> _mockAccounts = List.from(MockData.initialBillAccounts);
  final List<Bill> _mockBills = List.from(MockData.initialBills);
  final List<BillPayment> _mockPayments = [];

  Future<List<BillAccount>> getBillAccounts(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.unmodifiable(_mockAccounts);
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('billAccounts').get();
      return snapshot.docs.map((d) => BillAccount.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return List.unmodifiable(_mockAccounts);
    }
  }

  Future<BillAccount> addBillAccount(String userId, BillAccount account, {bool isDemo = true}) async {
    final newId = account.id.isEmpty ? _uuid.v4() : account.id;
    final newAccount = BillAccount(
      id: newId,
      userId: userId,
      name: account.name,
      category: account.category,
      providerName: account.providerName,
      accountNumber: account.accountNumber,
      billingCycle: account.billingCycle,
      dueDayOfMonth: account.dueDayOfMonth,
      defaultAmount: account.defaultAmount,
      autoReminder: account.autoReminder,
      createdAt: DateTime.now(),
    );

    if (isDemo) {
      _mockAccounts.add(newAccount);
      return newAccount;
    }

    await _firestore.collection('users').doc(userId).collection('billAccounts').doc(newId).set(newAccount.toMap());
    return newAccount;
  }

  Future<List<Bill>> getBills(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.unmodifiable(_mockBills);
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('bills').get();
      return snapshot.docs.map((d) => Bill.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return List.unmodifiable(_mockBills);
    }
  }

  Future<Bill> addBill(String userId, Bill bill, {bool isDemo = true}) async {
    final newId = bill.id.isEmpty ? _uuid.v4() : bill.id;
    final newBill = Bill(
      id: newId,
      billAccountId: bill.billAccountId,
      userId: userId,
      billPeriod: bill.billPeriod,
      billDate: bill.billDate,
      dueDate: bill.dueDate,
      amount: bill.amount,
      minimumDue: bill.minimumDue,
      status: bill.status,
      invoiceDocumentId: bill.invoiceDocumentId,
      notes: bill.notes,
    );

    if (isDemo) {
      _mockBills.add(newBill);
      return newBill;
    }

    await _firestore.collection('users').doc(userId).collection('bills').doc(newId).set(newBill.toMap());
    return newBill;
  }

  Future<BillPayment> recordBillPayment(String userId, BillPayment payment, {bool isDemo = true}) async {
    final newId = payment.id.isEmpty ? _uuid.v4() : payment.id;
    final newPayment = BillPayment(
      id: newId,
      billId: payment.billId,
      billAccountId: payment.billAccountId,
      amountPaid: payment.amountPaid,
      paymentDate: payment.paymentDate,
      paymentMethod: payment.paymentMethod,
      transactionRef: payment.transactionRef,
      receiptDocumentId: payment.receiptDocumentId,
      notes: payment.notes,
    );

    if (isDemo) {
      _mockPayments.add(newPayment);
      final billIndex = _mockBills.indexWhere((b) => b.id == payment.billId);
      if (billIndex != -1) {
        final b = _mockBills[billIndex];
        _mockBills[billIndex] = Bill(
          id: b.id,
          billAccountId: b.billAccountId,
          userId: b.userId,
          billPeriod: b.billPeriod,
          billDate: b.billDate,
          dueDate: b.dueDate,
          amount: b.amount,
          minimumDue: b.minimumDue,
          status: 'paid',
          invoiceDocumentId: b.invoiceDocumentId,
          notes: b.notes,
        );
      }
      return newPayment;
    }

    await _firestore.collection('users').doc(userId).collection('billPayments').doc(newId).set(newPayment.toMap());
    await _firestore.collection('users').doc(userId).collection('bills').doc(payment.billId).update({'status': 'paid'});

    return newPayment;
  }
}
