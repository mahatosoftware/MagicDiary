import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/financial/models/financial_transaction.dart';
import '../../../core/financial/repositories/financial_transaction_repository.dart';
import '../../../core/notifications/services/notification_manager.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/repositories/reminder_repository.dart';
import '../models/bills_models.dart';

class BillsRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  BillsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<BillAccount>> getBillAccounts(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('billAccounts')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((d) => BillAccount.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      try {
        final snapshot = await _firestore.collection('users').doc(userId).collection('billAccounts').get();
        return snapshot.docs.map((d) => BillAccount.fromMap(d.data(), d.id)).toList();
      } catch (inner) {
        return const [];
      }
    }
  }

  Future<BillAccount> addBillAccount(String userId, BillAccount account) async {
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

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('billAccounts')
        .doc(newId)
        .set(newAccount.toMap());

    // Auto-generate the active/upcoming Bill for this account so it shows in Bills, Reminders, and triggers notifications!
    if (newAccount.autoReminder) {
      try {
        final now = DateTime.now();
        int targetDay = newAccount.dueDayOfMonth.clamp(1, 28);
        DateTime targetDueDate;
        if (now.day <= targetDay) {
          targetDueDate = DateTime(now.year, now.month, targetDay, 9, 0);
        } else {
          final nextMonth = now.month == 12 ? 1 : now.month + 1;
          final nextYear = now.month == 12 ? now.year + 1 : now.year;
          targetDueDate = DateTime(nextYear, nextMonth, targetDay, 9, 0);
        }

        final monthName = DateFormat('MMMM yyyy').format(targetDueDate);
        final initialBill = Bill(
          id: '',
          billAccountId: newId,
          userId: userId,
          billPeriod: monthName,
          billDate: now,
          dueDate: targetDueDate,
          amount: newAccount.defaultAmount,
          minimumDue: newAccount.defaultAmount,
          status: 'unpaid',
          notes: 'Auto-generated bill for ${newAccount.name}',
        );

        await addBill(userId, initialBill);
      } catch (e) {
        // Ignored
      }
    }

    return newAccount;
  }

  Future<List<Bill>> getBills(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .orderBy('dueDate', descending: false)
          .get();
      final bills = snapshot.docs.map((d) => Bill.fromMap(d.data(), d.id)).toList();

      // Backfill: Auto-generate active bill for any BillAccount missing an active bill
      try {
        final accounts = await getBillAccounts(userId);
        for (final acc in accounts) {
          final hasBill = bills.any((b) => b.billAccountId == acc.id);
          if (!hasBill && acc.autoReminder) {
            final now = DateTime.now();
            int targetDay = acc.dueDayOfMonth.clamp(1, 28);
            DateTime targetDueDate;
            if (now.day <= targetDay) {
              targetDueDate = DateTime(now.year, now.month, targetDay, 9, 0);
            } else {
              final nextMonth = now.month == 12 ? 1 : now.month + 1;
              final nextYear = now.month == 12 ? now.year + 1 : now.year;
              targetDueDate = DateTime(nextYear, nextMonth, targetDay, 9, 0);
            }

            final autoBill = Bill(
              id: '',
              billAccountId: acc.id,
              userId: userId,
              billPeriod: DateFormat('MMMM yyyy').format(targetDueDate),
              billDate: now,
              dueDate: targetDueDate,
              amount: acc.defaultAmount,
              minimumDue: acc.defaultAmount,
              status: 'unpaid',
              notes: 'Auto-generated bill for ${acc.name}',
            );
            final savedBill = await addBill(userId, autoBill);
            bills.add(savedBill);
          }
        }
      } catch (_) {}

      return bills;
    } catch (e) {
      try {
        final snapshot = await _firestore.collection('users').doc(userId).collection('bills').get();
        return snapshot.docs.map((d) => Bill.fromMap(d.data(), d.id)).toList();
      } catch (inner) {
        return const [];
      }
    }
  }

  Future<Bill> addBill(String userId, Bill bill) async {
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

    await _firestore.collection('users').doc(userId).collection('bills').doc(newId).set(newBill.toMap());

    // Sync reminder
    try {
      final remRepo = ReminderRepository(firestore: _firestore);
      await remRepo.syncReminder(
        userId,
        Reminder(
          id: 'reminder_bill_$newId',
          userId: userId,
          title: 'Bill Due: ${newBill.billPeriod}',
          description: 'Bill payment of ₹${newBill.amount.toStringAsFixed(0)} due.',
          module: 'Bills',
          status: newBill.status == 'paid' ? 'completed' : 'pending',
          dueDate: newBill.dueDate,
          relatedId: newId,
          amount: newBill.amount,
          actionRoute: '/bills',
          actionType: 'Pay',
          priority: newBill.status == 'paid' ? 'low' : 'high',
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}

    // Schedule notifications in Central Notification Framework
    try {
      await NotificationManager().scheduleForRecord(
        userId: userId,
        recordId: 'reminder_bill_$newId',
        moduleId: 'bills',
        categoryId: 'bills',
        eventType: 'Bill Payment',
        title: 'Bill Due: ${newBill.billPeriod}',
        dueDate: newBill.dueDate,
        amount: newBill.amount,
        actionRoute: '/bills',
      );
    } catch (_) {}

    return newBill;
  }

  Future<void> deleteBill(String userId, String billId) async {
    if (userId.isEmpty || billId.isEmpty) return;
    await _firestore.collection('users').doc(userId).collection('bills').doc(billId).delete();
    try {
      final remRepo = ReminderRepository(firestore: _firestore);
      await remRepo.deleteReminder(userId, 'reminder_bill_$billId');
    } catch (_) {}
  }

  Future<BillPayment> recordBillPayment(String userId, BillPayment payment) async {
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

    await _firestore.collection('users').doc(userId).collection('billPayments').doc(newId).set(newPayment.toMap());
    await _firestore.collection('users').doc(userId).collection('bills').doc(payment.billId).update({'status': 'paid'});

    // Mark reminder completed
    try {
      final remRef = _firestore.collection('users').doc(userId).collection('reminders').doc('reminder_bill_${payment.billId}');
      await remRef.update({
        'status': 'completed',
        'completedAt': Timestamp.fromDate(payment.paymentDate),
      });
    } catch (_) {}

    // Record canonical financial transaction idempotently
    try {
      final txRepo = FinancialTransactionRepository(firestore: _firestore);
      await txRepo.recordTransaction(
        userId,
        FinancialTransaction.fromMajorUnits(
          id: FinancialTransaction.generateDeterministicId('bills', newId),
          userId: userId,
          type: TransactionType.expense,
          amountMajor: payment.amountPaid,
          categoryId: 'household_other',
          sourceModule: 'bills',
          sourceRecordId: newId,
          description: 'Bill Payment (Ref: ${payment.transactionRef.isNotEmpty ? payment.transactionRef : newId})',
          transactionDate: payment.paymentDate,
          paymentMethod: payment.paymentMethod,
          notes: payment.notes,
        ),
      );
    } catch (_) {}

    return newPayment;
  }
}
