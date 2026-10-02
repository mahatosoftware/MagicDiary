import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/personal_models.dart';

class PersonalRepository {
  final FirebaseFirestore? _firestore;
  PersonalRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  final List<JournalEntry> _mockJournals = [
    JournalEntry(
      id: 'jrn_1',
      title: 'A Productive Day & Morning Walk',
      content: 'Woke up at 6 AM and went for a 5km jog around the lake. Spent the afternoon readingFlutter architecture docs.',
      date: DateTime.now().subtract(const Duration(hours: 4)),
      mood: '😌 Calm',
      gratitudeNote: 'Grateful for good health, clear mind, and family time.',
      tags: ['Health', 'Reflection'],
    ),
    JournalEntry(
      id: 'jrn_2',
      title: 'Magic Diary Release Milestone',
      content: 'Successfully configured Firebase integration and launched 8 diary modules. Really excited about the progress!',
      date: DateTime.now().subtract(const Duration(days: 1)),
      mood: '🤩 Excited',
      gratitudeNote: 'Grateful for coding inspiration and fast problem solving.',
      tags: ['Coding', 'Milestone'],
    ),
  ];

  final List<PersonalGoal> _mockGoals = [
    PersonalGoal(
      id: 'goal_1',
      title: 'Read 12 Books This Year',
      category: 'Personal Growth',
      targetDate: DateTime(2026, 12, 31),
      progressPercentage: 0.65,
      isCompleted: false,
    ),
    PersonalGoal(
      id: 'goal_2',
      title: 'Run a Half Marathon (21km)',
      category: 'Health',
      targetDate: DateTime(2026, 11, 15),
      progressPercentage: 0.40,
      isCompleted: false,
    ),
  ];

  final List<SpecialEvent> _mockEvents = [
    SpecialEvent(
      id: 'evt_1',
      title: 'Mom\'s 60th Birthday',
      eventType: 'Birthday',
      date: DateTime.now().add(const Duration(days: 18)),
      giftIdeas: 'Customized photo album & Kindle Paperwhite',
    ),
    SpecialEvent(
      id: 'evt_2',
      title: 'Wedding Anniversary',
      eventType: 'Anniversary',
      date: DateTime.now().add(const Duration(days: 42)),
      giftIdeas: 'Weekend getaway trip to Coorg',
    ),
  ];

  Future<List<JournalEntry>> getJournals(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockJournals);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .get();
    return snapshot.docs.map((doc) => JournalEntry.fromJson(doc.data())).toList();
  }

  Future<List<PersonalGoal>> getGoals(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockGoals);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('personalGoals')
        .get();
    return snapshot.docs.map((doc) => PersonalGoal.fromJson(doc.data())).toList();
  }

  Future<List<SpecialEvent>> getEvents(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockEvents);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('specialEvents')
        .get();
    return snapshot.docs.map((doc) => SpecialEvent.fromJson(doc.data())).toList();
  }

  Future<void> addJournal(String userId, JournalEntry entry, {bool isDemo = true}) async {
    if (isDemo) {
      _mockJournals.insert(0, entry);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('journalEntries')
        .doc(entry.id)
        .set(entry.toJson());
  }

  Future<void> addGoal(String userId, PersonalGoal goal, {bool isDemo = true}) async {
    if (isDemo) {
      _mockGoals.add(goal);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('personalGoals')
        .doc(goal.id)
        .set(goal.toJson());
  }
}
