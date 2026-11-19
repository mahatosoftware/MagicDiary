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
      isAutopay: account.isAutopay,
      paymentMethod: account.paymentMethod,
      isSubscription: account.isSubscription,
      isUnusedFlagged: account.isUnusedFlagged,
      createdAt: DateTime.now(),
      subscriptionType: account.subscriptionType,
      trialEndsAt: account.trialEndsAt,
      renewalDate: account.renewalDate,
      reminderDaysBefore: account.reminderDaysBefore,
      cancelUrl: account.cancelUrl,
      planTier: account.planTier,
      isActive: account.isActive,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('billAccounts')
        .doc(newId)
        .set(newAccount.toMap());

    // Sync subscription & free trial reminder if applicable
    if (newAccount.isSubscription) {
      try {
        await syncSubscriptionReminder(userId, newAccount);
      } catch (_) {}
    }

    // Auto-generate the active/upcoming Bill for this account so it shows in Bills, Reminders, and triggers notifications!
    if (newAccount.autoReminder && !newAccount.isSubscription) {
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
          title: newAccount.name,
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

  Future<void> updateBillAccount(String userId, BillAccount account) async {
    if (userId.isEmpty || account.id.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('billAccounts')
        .doc(account.id)
        .set(account.toMap(), SetOptions(merge: true));

    if (account.isSubscription) {
      try {
        await syncSubscriptionReminder(userId, account);
      } catch (_) {}
    }
  }

  Future<void> syncSubscriptionReminder(String userId, BillAccount account) async {
    if (userId.isEmpty || account.id.isEmpty) return;
    final remId = 'reminder_sub_${account.id}';
    final remRepo = ReminderRepository(firestore: _firestore);

    if (!account.isActive || !account.autoReminder) {
      try {
        await remRepo.deleteReminder(userId, remId);
        final notifManager = NotificationManager();
        await notifManager.onRecordPaidOrCompleted(userId: userId, recordId: remId);
      } catch (_) {}
      return;
    }

    DateTime? targetAlertDate;
    String title = '';
    String description = '';

    if (account.subscriptionType == 'free_trial' && account.trialEndsAt != null) {
      final daysBefore = account.reminderDaysBefore.clamp(1, 14);
      targetAlertDate = account.trialEndsAt!.subtract(Duration(days: daysBefore));
      if (targetAlertDate.isBefore(DateTime.now())) {
        targetAlertDate = account.trialEndsAt;
      }
      title = 'Free Trial Ending Soon: ${account.name}';
      final formattedExpiry = DateFormat('dd MMM yyyy').format(account.trialEndsAt!);
      final chargeNote = account.defaultAmount > 0
          ? ' Cancel before renewal to avoid ₹${account.defaultAmount.toStringAsFixed(0)} charge.'
          : ' Cancel before $formattedExpiry if you do not wish to continue.';
      description = 'Free trial ends on $formattedExpiry.$chargeNote';
    } else if (account.renewalDate != null) {
      final daysBefore = account.reminderDaysBefore.clamp(1, 14);
      targetAlertDate = account.renewalDate!.subtract(Duration(days: daysBefore));
      if (targetAlertDate.isBefore(DateTime.now())) {
        targetAlertDate = account.renewalDate;
      }
      title = 'Subscription Renewal: ${account.name}';
      final formattedRenewal = DateFormat('dd MMM yyyy').format(account.renewalDate!);
      final costNote = account.defaultAmount > 0
          ? ' for ₹${account.defaultAmount.toStringAsFixed(0)} (${account.billingCycle})'
          : '';
      description = 'Renews on $formattedRenewal$costNote. Review plan or cancel to avoid renewal.';
    }

    if (targetAlertDate != null) {
      final reminder = Reminder(
        id: remId,
        userId: userId,
        title: title,
        description: description,
        module: 'Bills',
        status: 'pending',
        dueDate: targetAlertDate,
        relatedId: account.id,
        amount: account.defaultAmount,
        actionRoute: '/bills',
        actionType: account.subscriptionType == 'free_trial' ? 'Cancel / Review' : 'Manage Subscription',
        priority: 'high',
        createdAt: DateTime.now(),
      );

      await remRepo.syncReminder(userId, reminder);

      try {
        await NotificationManager().scheduleForRecord(
          userId: userId,
          recordId: remId,
          moduleId: 'bills',
          categoryId: 'subscriptions',
          eventType: account.subscriptionType == 'free_trial' ? 'Free Trial Expiry' : 'Subscription Renewal',
          title: title,
          dueDate: targetAlertDate,
          amount: account.defaultAmount,
          actionRoute: '/bills',
        );
      } catch (_) {}
    }
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
              title: acc.name,
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
      title: bill.title,
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

  Future<BillPayment> recordBillPayment(String userId, BillPayment payment, {bool autoRollover = true}) async {
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

    // Mark reminder completed & cancel scheduled notifications
    try {
      final remId = 'reminder_bill_${payment.billId}';
      final remRef = _firestore.collection('users').doc(userId).collection('reminders').doc(remId);
      await remRef.update({
        'status': 'completed',
        'completedAt': Timestamp.fromDate(payment.paymentDate),
      });
      final notifManager = NotificationManager();
      await notifManager.onRecordPaidOrCompleted(userId: userId, recordId: payment.billId);
      await notifManager.onRecordPaidOrCompleted(userId: userId, recordId: remId);
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

    // Auto-Rollover: Generate next period's bill and schedule next reminder
    if (autoRollover && payment.billAccountId.isNotEmpty) {
      try {
        await rolloverNextBill(userId, payment);
      } catch (_) {}
    }

    return newPayment;
  }

  /// Automatically rolls over recurring bills (e.g. Broadband, Electricity, Rent)
  /// to the next cycle and schedules reminders and notifications.
  Future<Bill?> rolloverNextBill(String userId, BillPayment payment) async {
    if (userId.isEmpty || payment.billAccountId.isEmpty) return null;
    try {
      // 1. Fetch current bill
      Bill? currentBill;
      if (payment.billId.isNotEmpty) {
        final currentBillDoc = await _firestore.collection('users').doc(userId).collection('bills').doc(payment.billId).get();
        if (currentBillDoc.exists && currentBillDoc.data() != null) {
          currentBill = Bill.fromMap(currentBillDoc.data()!, currentBillDoc.id);
        }
      }

      // 2. Fetch bill account
      final accDoc = await _firestore.collection('users').doc(userId).collection('billAccounts').doc(payment.billAccountId).get();
      if (!accDoc.exists || accDoc.data() == null) return null;
      final account = BillAccount.fromMap(accDoc.data()!, accDoc.id);

      // Do not auto-rollover if disabled, inactive, or one-time
      if (!account.autoReminder || !account.isActive) return null;

      // 3. Compute next due date
      final baseDate = currentBill?.dueDate ?? payment.paymentDate;
      final cycle = account.billingCycle.toLowerCase();

      int monthsToAdd = 1;
      if (cycle.contains('quarter')) {
        monthsToAdd = 3;
      } else if (cycle.contains('year')) {
        monthsToAdd = 12;
      }

      int nextYear = baseDate.year;
      int nextMonth = baseDate.month + monthsToAdd;
      while (nextMonth > 12) {
        nextMonth -= 12;
        nextYear += 1;
      }

      final maxDaysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      final targetDay = account.dueDayOfMonth.clamp(1, maxDaysInNextMonth);
      final nextDueDate = DateTime(nextYear, nextMonth, targetDay, 9, 0);
      final nextPeriodName = DateFormat('MMMM yyyy').format(nextDueDate);

      // 4. Idempotency check: Don't duplicate if next period bill already exists
      final existingBillsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bills')
          .where('billAccountId', isEqualTo: account.id)
          .get();

      final alreadyExists = existingBillsSnapshot.docs.any((d) {
        final data = d.data();
        final period = data['billPeriod']?.toString() ?? '';
        final status = data['status']?.toString() ?? '';
        return period == nextPeriodName && status == 'unpaid';
      });

      if (alreadyExists) return null;

      // 5. Estimated amount for next cycle
      final estimatedAmount = account.defaultAmount > 0
          ? account.defaultAmount
          : (payment.amountPaid > 0 ? payment.amountPaid : (currentBill?.amount ?? 0.0));

      final nextBill = Bill(
        id: '',
        billAccountId: account.id,
        userId: userId,
        title: account.name,
        billPeriod: nextPeriodName,
        billDate: DateTime.now(),
        dueDate: nextDueDate,
        amount: estimatedAmount,
        expectedAmount: estimatedAmount,
        previousAmount: payment.amountPaid > 0 ? payment.amountPaid : currentBill?.amount,
        minimumDue: estimatedAmount,
        status: 'unpaid',
        notes: 'Auto-rolled over for ${account.name} (${account.billingCycle})',
      );

      return await addBill(userId, nextBill);
    } catch (_) {
      return null;
    }
  }
}
