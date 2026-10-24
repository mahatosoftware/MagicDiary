import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/personal_models.dart';

class PersonalRepository {
  final FirebaseFirestore? _firestore;
  PersonalRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<List<JournalEntry>> getJournals(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('journals')
          .get();
      final list = snapshot.docs.map((doc) => JournalEntry.fromJson(doc.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      return const [];
    }
  }

  Future<List<PersonalGoal>> getGoals(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('goals')
          .get();
      return snapshot.docs.map((doc) => PersonalGoal.fromJson(doc.data())).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<List<SpecialEvent>> getEvents(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('events')
          .get();
      final list = snapshot.docs.map((doc) => SpecialEvent.fromJson(doc.data())).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (e) {
      return const [];
    }
  }

  Future<void> addJournal(String userId, JournalEntry journal) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('journals')
        .doc(journal.id)
        .set(journal.toJson());
  }

  Future<void> addGoal(String userId, PersonalGoal goal) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goal.id)
        .set(goal.toJson());
  }

  Future<void> addEvent(String userId, SpecialEvent event) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('events')
        .doc(event.id)
        .set(event.toJson());
  }

  Future<void> updateGoalProgress(String userId, String goalId, double progress, bool isCompleted) async {
    if (userId.isEmpty || goalId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goalId)
        .update({
          'progressPercentage': progress,
          'isCompleted': isCompleted,
        });
  }
}
