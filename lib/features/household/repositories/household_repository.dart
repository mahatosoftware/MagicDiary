import 'package:cloud_firestore/cloud_firestore.dart';
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
  }

  Future<void> updateExpenseStatus(String userId, String expenseId, String status) async {
    if (userId.isEmpty || expenseId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('householdExpenses')
        .doc(expenseId)
        .update({'status': status});
  }

  Future<void> deleteExpense(String userId, String expenseId) async {
    if (userId.isEmpty || expenseId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('householdExpenses')
        .doc(expenseId)
        .delete();
  }
}
