import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/household_models.dart';

class HouseholdRepository {
  final FirebaseFirestore? _firestore;
  HouseholdRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  final List<HouseholdExpense> _mockExpenses = [
    HouseholdExpense(
      id: 'hh_1',
      category: 'Electricity',
      providerName: 'BESCOM Power Utility',
      amount: 2450.0,
      dueDate: DateTime.now().add(const Duration(days: 4)),
      status: 'unpaid',
      period: 'Monthly - Sep 2026',
    ),
    HouseholdExpense(
      id: 'hh_2',
      category: 'Gas',
      providerName: 'Indane Gas Refill',
      amount: 920.0,
      dueDate: DateTime.now().add(const Duration(days: 8)),
      status: 'unpaid',
      period: 'Bi-monthly',
    ),
    HouseholdExpense(
      id: 'hh_3',
      category: 'Internet',
      providerName: 'Airtel Xstream Fiber',
      amount: 1179.0,
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
      status: 'paid',
      period: 'Monthly - Sep 2026',
    ),
    HouseholdExpense(
      id: 'hh_4',
      category: 'Domestic Help',
      providerName: 'Cook & Maid Salary',
      amount: 8500.0,
      dueDate: DateTime.now().add(const Duration(days: 6)),
      status: 'unpaid',
      period: 'Monthly - Oct 2026',
    ),
  ];

  Future<List<HouseholdExpense>> getExpenses(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockExpenses);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('householdExpenses')
        .get();
    return snapshot.docs.map((doc) => HouseholdExpense.fromJson(doc.data())).toList();
  }

  Future<void> addExpense(String userId, HouseholdExpense expense, {bool isDemo = true}) async {
    if (isDemo) {
      _mockExpenses.add(expense);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('householdExpenses')
        .doc(expense.id)
        .set(expense.toJson());
  }
}
