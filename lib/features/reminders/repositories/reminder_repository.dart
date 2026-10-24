import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/date_calculators.dart';
import '../models/reminder.dart';

class ReminderRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  ReminderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Reminder>> getReminders(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .orderBy('dueDate', descending: false)
          .get();
      return snapshot.docs.map((d) => Reminder.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      try {
        final snapshot = await _firestore.collection('users').doc(userId).collection('reminders').get();
        final list = snapshot.docs.map((d) => Reminder.fromMap(d.data(), d.id)).toList();
        list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return list;
      } catch (inner) {
        return const [];
      }
    }
  }

  Future<Reminder> addReminder(String userId, Reminder reminder) async {
    final newId = reminder.id.isEmpty ? _uuid.v4() : reminder.id;
    final newRem = Reminder(
      id: newId,
      userId: userId,
      title: reminder.title,
      description: reminder.description,
      module: reminder.module,
      status: reminder.status,
      dueDate: reminder.dueDate,
      relatedId: reminder.relatedId,
      snoozedUntil: reminder.snoozedUntil,
      completedAt: reminder.completedAt,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(userId).collection('reminders').doc(newId).set(newRem.toMap());
    return newRem;
  }

  Future<void> deferReminder(String userId, String reminderId, DeferOption option, {int customDays = 0}) async {
    if (userId.isEmpty || reminderId.isEmpty) return;
    final DateTime newDueDate = DateCalculators.calculateDeferredDate(DateTime.now(), option, customDays: customDays);

    await _firestore.collection('users').doc(userId).collection('reminders').doc(reminderId).update({
      'status': 'snoozed',
      'snoozedUntil': Timestamp.fromDate(newDueDate),
      'dueDate': Timestamp.fromDate(newDueDate),
    });
  }

  Future<void> completeReminder(String userId, String reminderId) async {
    if (userId.isEmpty || reminderId.isEmpty) return;
    await _firestore.collection('users').doc(userId).collection('reminders').doc(reminderId).update({
      'status': 'completed',
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> completeReminderByRelatedId(String userId, String relatedId, {DateTime? completedAt}) async {
    if (userId.isEmpty || relatedId.isEmpty) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .where('relatedId', isEqualTo: relatedId)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({
          'status': 'completed',
          'completedAt': Timestamp.fromDate(completedAt ?? DateTime.now()),
        });
      }
    } catch (_) {}
  }

  Future<void> deleteReminder(String userId, String reminderId) async {
    if (userId.isEmpty || reminderId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('reminders')
        .doc(reminderId)
        .delete();
  }

  Future<void> syncReminder(String userId, Reminder reminder) async {
    if (userId.isEmpty) return;
    final docRef = _firestore.collection('users').doc(userId).collection('reminders').doc(reminder.id);
    final snap = await docRef.get();
    final createdAt = snap.exists && snap.data()?['createdAt'] is Timestamp
        ? (snap.data()!['createdAt'] as Timestamp)
        : Timestamp.fromDate(DateTime.now());

    final map = reminder.toMap();
    map['createdAt'] = createdAt;
    await docRef.set(map, SetOptions(merge: true));
  }
}
