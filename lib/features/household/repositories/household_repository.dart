import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/financial/models/financial_category.dart';
import '../../../core/financial/models/financial_transaction.dart';
import '../../../core/financial/repositories/financial_transaction_repository.dart';
import '../models/household_models.dart';

class HouseholdRepository {
  final FirebaseFirestore? _firestore;
  HouseholdRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<List<HouseholdExpense>> getExpenses(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('householdExpenses')
          .get();
      final list = snapshot.docs.map((doc) => HouseholdExpense.fromJson(doc.data())).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    } catch (e) {
      return const [];
    }
  }

  Future<void> addExpense(String userId, HouseholdExpense expense) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('householdExpenses')
        .doc(expense.id)
        .set(expense.toJson());

    // Record canonical financial transaction if paid
    if (expense.status.toLowerCase() == 'paid') {
      try {
        final txRepo = FinancialTransactionRepository(firestore: firestore);
        await txRepo.recordTransaction(
          userId,
          FinancialTransaction.fromMajorUnits(
            id: FinancialTransaction.generateDeterministicId('household', expense.id),
            userId: userId,
            type: TransactionType.expense,
            amountMajor: expense.amount,
            categoryId: CategoryRegistry.mapLegacyToCategoryId(expense.category, expense.providerName),
            sourceModule: 'household',
            sourceRecordId: expense.id,
            description: '${expense.category} - ${expense.providerName}',
            transactionDate: expense.dueDate,
            notes: expense.period,
          ),
        );
      } catch (_) {}
    }

    // Sync reminder
    try {
      final isPaid = expense.status.toLowerCase() == 'paid';
      final remRef = firestore.collection('users').doc(userId).collection('reminders').doc('reminder_hh_${expense.id}');
      await remRef.set({
        'id': 'reminder_hh_${expense.id}',
        'userId': userId,
        'title': 'Household: ${expense.category} (${expense.providerName})',
        'description': 'Household expense of ₹${expense.amount.toStringAsFixed(0)} for ${expense.period}.',
        'module': 'Household',
        'status': isPaid ? 'completed' : 'pending',
        'dueDate': Timestamp.fromDate(expense.dueDate),
        'relatedId': expense.id,
        'amount': expense.amount,
        'actionRoute': '/household',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'completedAt': isPaid ? Timestamp.fromDate(DateTime.now()) : null,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateExpenseStatus(String userId, String expenseId, String status) async {
    if (userId.isEmpty || expenseId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('householdExpenses')
        .doc(expenseId)
        .update({'status': status});

    final txRepo = FinancialTransactionRepository(firestore: firestore);
    final detId = FinancialTransaction.generateDeterministicId('household', expenseId);

    if (status.toLowerCase() == 'paid') {
      try {
        final doc = await firestore.collection('users').doc(userId).collection('householdExpenses').doc(expenseId).get();
        if (doc.exists && doc.data() != null) {
          final exp = HouseholdExpense.fromJson(doc.data()!);
          await txRepo.recordTransaction(
            userId,
            FinancialTransaction.fromMajorUnits(
              id: detId,
              userId: userId,
              type: TransactionType.expense,
              amountMajor: exp.amount,
              categoryId: CategoryRegistry.mapLegacyToCategoryId(exp.category, exp.providerName),
              sourceModule: 'household',
              sourceRecordId: expenseId,
              description: '${exp.category} - ${exp.providerName}',
              transactionDate: exp.dueDate,
              notes: exp.period,
            ),
          );
        }
      } catch (_) {}

      // Mark reminder completed
      try {
        final remRef = firestore.collection('users').doc(userId).collection('reminders').doc('reminder_hh_$expenseId');
        await remRef.update({
          'status': 'completed',
          'completedAt': Timestamp.fromDate(DateTime.now()),
        });
      } catch (_) {}
    } else {
      try {
        await txRepo.deleteTransaction(userId, detId, softDelete: true);
      } catch (_) {}

      // Reset reminder to pending
      try {
        final remRef = firestore.collection('users').doc(userId).collection('reminders').doc('reminder_hh_$expenseId');
        await remRef.update({
          'status': 'pending',
          'completedAt': null,
        });
      } catch (_) {}
    }
  }

  Future<void> deleteExpense(String userId, String expenseId) async {
    if (userId.isEmpty || expenseId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('householdExpenses')
        .doc(expenseId)
        .delete();

    try {
      final remRef = firestore.collection('users').doc(userId).collection('reminders').doc('reminder_hh_$expenseId');
      await remRef.delete();
    } catch (_) {}

    try {
      final txRepo = FinancialTransactionRepository(firestore: firestore);
      final detId = FinancialTransaction.generateDeterministicId('household', expenseId);
      await txRepo.deleteTransaction(userId, detId, softDelete: false);
    } catch (_) {}
  }
}
