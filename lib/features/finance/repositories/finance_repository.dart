import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/financial/models/financial_category.dart';
import '../../../core/financial/models/financial_transaction.dart' as canonical;
import '../../../core/financial/repositories/financial_transaction_repository.dart';
import '../../../core/notifications/services/notification_manager.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/repositories/reminder_repository.dart';
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

    // If transaction is pending and has a reminder configured, register into reminders collection
    if (!tx.isPaid && tx.hasReminder) {
      try {
        final remRepo = ReminderRepository(firestore: firestore);
        final reminder = Reminder(
          id: 'reminder_tx_${tx.id}',
          userId: userId,
          title: 'Payment Due: ${tx.description}',
          description: '${tx.category} payment of ₹${tx.amount.toStringAsFixed(0)} is due on ${DateFormat('dd MMM yyyy').format(tx.date)}.',
          module: 'Finance',
          status: 'pending',
          dueDate: tx.date,
          relatedId: tx.id,
          amount: tx.amount,
          actionRoute: '/finance',
          actionType: 'Pay',
          priority: 'high',
          createdAt: DateTime.now(),
        );
        await remRepo.addReminder(userId, reminder);
      } catch (_) {}
    }

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

      final status = tx.isPaid
          ? canonical.TransactionStatus.completed
          : canonical.TransactionStatus.pending;

      await txRepo.recordTransaction(
        userId,
        canonical.FinancialTransaction.fromMajorUnits(
          id: canonical.FinancialTransaction.generateDeterministicId('finance', tx.id),
          userId: userId,
          type: type,
          status: status,
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

  /// Marks a financial transaction as settled/paid, updates paidAt timestamp,
  /// and automatically completes and clears any active reminder for this transaction.
  Future<void> markTransactionAsPaid(
    String userId,
    String transactionId, {
    DateTime? paidAt,
    String? paymentMethod,
  }) async {
    if (userId.isEmpty || transactionId.isEmpty) return;
    final now = paidAt ?? DateTime.now();

    // 1. Update financial transaction in users/{userId}/transactions/{transactionId}
    final docRef = firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(transactionId);

    final updateData = <String, dynamic>{
      'isPaid': true,
      'paidAt': now.toIso8601String(),
    };
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      updateData['paymentMethod'] = paymentMethod;
    }

    try {
      await docRef.update(updateData);
    } catch (_) {}

    // 2. Complete and remove active reminder from My Day & Reminders collection
    try {
      final remRepo = ReminderRepository(firestore: firestore);
      final remDocId = 'reminder_tx_$transactionId';
      final remDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .doc(remDocId)
          .get();

      if (remDoc.exists) {
        await remRepo.completeReminder(userId, remDocId, completedAt: now);
      } else {
        await remRepo.completeReminderByRelatedId(userId, transactionId, completedAt: now);
      }

      await NotificationManager().onRecordPaidOrCompleted(userId: userId, recordId: remDocId);
    } catch (_) {}

    // 3. Update canonical transaction status to completed
    try {
      final txRepo = FinancialTransactionRepository(firestore: firestore);
      final detId = canonical.FinancialTransaction.generateDeterministicId('finance', transactionId);
      final existingCanonical = await txRepo.getTransactionById(userId, detId);
      if (existingCanonical != null) {
        await txRepo.recordTransaction(
          userId,
          existingCanonical.copyWith(
            status: canonical.TransactionStatus.completed,
            updatedAt: now,
          ),
        );
      }
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

    // Remove any linked reminder
    try {
      final remRepo = ReminderRepository(firestore: firestore);
      await remRepo.deleteReminder(userId, 'reminder_tx_$transactionId');
    } catch (_) {}

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
