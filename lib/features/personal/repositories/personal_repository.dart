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

    // Sync reminder
    try {
      final remRef = firestore.collection('users').doc(userId).collection('reminders').doc('reminder_evt_${event.id}');
      await remRef.set({
        'id': 'reminder_evt_${event.id}',
        'userId': userId,
        'title': '${event.eventType}: ${event.title}',
        'description': event.giftIdeas != null ? 'Gift Ideas: ${event.giftIdeas}' : '${event.eventType} celebration',
        'module': 'Personal',
        'status': 'pending',
        'dueDate': Timestamp.fromDate(event.date),
        'relatedId': event.id,
        'actionRoute': '/personal',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    } catch (_) {}
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

  Future<void> deleteGoal(String userId, String goalId) async {
    if (userId.isEmpty || goalId.isEmpty) return;
    await firestore.collection('users').doc(userId).collection('goals').doc(goalId).delete();
  }

  Future<void> deleteEvent(String userId, String eventId) async {
    if (userId.isEmpty || eventId.isEmpty) return;
    await firestore.collection('users').doc(userId).collection('events').doc(eventId).delete();

    try {
      final remRef = firestore.collection('users').doc(userId).collection('reminders').doc('reminder_evt_$eventId');
      await remRef.delete();
    } catch (_) {}
  }

  Future<void> deleteJournal(String userId, String journalId) async {
    if (userId.isEmpty || journalId.isEmpty) return;
    await firestore.collection('users').doc(userId).collection('journals').doc(journalId).delete();
  }
}
