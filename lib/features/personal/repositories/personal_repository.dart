import 'package:cloud_firestore/cloud_firestore.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/repositories/reminder_repository.dart';
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

    final goalRemId = 'reminder_goal_${goal.id}';
    final remRepo = ReminderRepository(firestore: firestore);
    try {
      await remRepo.syncReminder(
        userId,
        Reminder(
          id: goalRemId,
          userId: userId,
          title: 'Goal Target: ${goal.title}',
          description: 'Target date reached for personal goal "${goal.title}". Current progress: ${(goal.progressPercentage * 100).toStringAsFixed(0)}%.',
          module: 'Personal',
          status: goal.isCompleted ? 'completed' : 'pending',
          dueDate: goal.targetDate,
          relatedId: goal.id,
          actionRoute: '/personal',
          actionType: 'Review',
          priority: 'medium',
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {}
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
      final remRepo = ReminderRepository(firestore: firestore);
      await remRepo.syncReminder(
        userId,
        Reminder(
          id: 'reminder_evt_${event.id}',
          userId: userId,
          title: '${event.eventType}: ${event.title}',
          description: event.giftIdeas != null ? 'Gift Ideas: ${event.giftIdeas}' : '${event.eventType} celebration',
          module: 'Personal',
          status: 'pending',
          dueDate: event.date,
          relatedId: event.id,
          actionRoute: '/personal',
          actionType: 'Review',
          priority: 'medium',
          createdAt: DateTime.now(),
        ),
      );
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

    if (isCompleted) {
      try {
        final remRepo = ReminderRepository(firestore: firestore);
        await remRepo.completeReminder(userId, 'reminder_goal_$goalId');
      } catch (_) {}
    }
  }

  Future<void> deleteGoal(String userId, String goalId) async {
    if (userId.isEmpty || goalId.isEmpty) return;
    await firestore.collection('users').doc(userId).collection('goals').doc(goalId).delete();
    try {
      final remRepo = ReminderRepository(firestore: firestore);
      await remRepo.deleteReminder(userId, 'reminder_goal_$goalId');
    } catch (_) {}
  }

  Future<void> deleteEvent(String userId, String eventId) async {
    if (userId.isEmpty || eventId.isEmpty) return;
    await firestore.collection('users').doc(userId).collection('events').doc(eventId).delete();

    try {
      final remRepo = ReminderRepository(firestore: firestore);
      await remRepo.deleteReminder(userId, 'reminder_evt_$eventId');
    } catch (_) {}
  }

  Future<void> deleteJournal(String userId, String journalId) async {
    if (userId.isEmpty || journalId.isEmpty) return;
    await firestore.collection('users').doc(userId).collection('journals').doc(journalId).delete();
  }

  // --- Habit Tracking ---
  Future<List<Habit>> getHabits(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('habits')
          .get();
      return snapshot.docs.map((doc) => Habit.fromJson(doc.data())).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<void> addHabit(String userId, Habit habit) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habit.id)
        .set(habit.toJson());
  }

  Future<void> toggleHabitDay(String userId, String habitId, DateTime date) async {
    if (userId.isEmpty || habitId.isEmpty) return;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final docRef = firestore.collection('users').doc(userId).collection('habits').doc(habitId);
    final doc = await docRef.get();
    if (!doc.exists || doc.data() == null) return;
    final habit = Habit.fromJson(doc.data()!);
    final updatedDays = List<String>.from(habit.completedDates);
    if (updatedDays.contains(dateStr)) {
      updatedDays.remove(dateStr);
    } else {
      updatedDays.add(dateStr);
    }
    await docRef.update({'completedDates': updatedDays});
  }

  Future<void> deleteHabit(String userId, String habitId) async {
    if (userId.isEmpty || habitId.isEmpty) return;
    await firestore.collection('users').doc(userId).collection('habits').doc(habitId).delete();
  }
}
