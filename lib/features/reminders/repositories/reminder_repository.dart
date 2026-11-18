import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/notifications/services/notification_manager.dart';
import '../../../core/utils/date_calculators.dart';
import '../models/reminder.dart';

class ReminderRepository {
  final FirebaseFirestore? _firestore;
  final Uuid _uuid = const Uuid();

  ReminderRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<List<Reminder>> getReminders(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .orderBy('dueDate', descending: false)
          .get();
      return snapshot.docs.map((d) => Reminder.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      try {
        final snapshot = await firestore.collection('users').doc(userId).collection('reminders').get();
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

    await firestore.collection('users').doc(userId).collection('reminders').doc(newId).set(newRem.toMap());
    return newRem;
  }

  Future<void> deferReminder(String userId, String reminderId, DeferOption option, {int customDays = 0}) async {
    if (userId.isEmpty || reminderId.isEmpty) return;
    final DateTime newDueDate = DateCalculators.calculateDeferredDate(DateTime.now(), option, customDays: customDays);

    await firestore.collection('users').doc(userId).collection('reminders').doc(reminderId).update({
      'status': 'snoozed',
      'snoozedUntil': Timestamp.fromDate(newDueDate),
      'dueDate': Timestamp.fromDate(newDueDate),
    });
  }

  Future<void> completeReminder(String userId, String reminderId) async {
    if (userId.isEmpty || reminderId.isEmpty) return;
    await firestore.collection('users').doc(userId).collection('reminders').doc(reminderId).update({
      'status': 'completed',
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
    try {
      await NotificationManager().onRecordPaidOrCompleted(userId: userId, recordId: reminderId);
    } catch (_) {}
  }

  Future<void> completeReminderByRelatedId(String userId, String relatedId, {DateTime? completedAt}) async {
    if (userId.isEmpty || relatedId.isEmpty) return;
    try {
      final snap = await firestore
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
        try {
          await NotificationManager().onRecordPaidOrCompleted(userId: userId, recordId: doc.id);
        } catch (_) {}
      }
      try {
        await NotificationManager().onRecordPaidOrCompleted(userId: userId, recordId: relatedId);
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> deleteReminder(String userId, String reminderId) async {
    if (userId.isEmpty || reminderId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('reminders')
        .doc(reminderId)
        .delete();
    try {
      await NotificationManager().cancelForRecord(userId: userId, recordId: reminderId);
    } catch (_) {}
  }

  Future<void> syncReminder(String userId, Reminder reminder) async {
    if (userId.isEmpty) return;
    final docRef = firestore.collection('users').doc(userId).collection('reminders').doc(reminder.id);
    final snap = await docRef.get();
    final createdAt = snap.exists && snap.data()?['createdAt'] is Timestamp
        ? (snap.data()!['createdAt'] as Timestamp)
        : Timestamp.fromDate(reminder.createdAt);

    String status = reminder.status;
    DateTime? completedAt = reminder.completedAt;
    DateTime? snoozedUntil = reminder.snoozedUntil;

    if (snap.exists) {
      final existingData = snap.data();
      final existingStatus = existingData?['status'] as String? ?? 'pending';
      final existingDueDate = existingData?['dueDate'] is Timestamp
          ? (existingData!['dueDate'] as Timestamp).toDate()
          : (existingData?['dueDate'] != null ? DateTime.tryParse(existingData!['dueDate'].toString()) : null);

      final isDueDateChanged = existingDueDate != null &&
          (existingDueDate.year != reminder.dueDate.year ||
              existingDueDate.month != reminder.dueDate.month ||
              existingDueDate.day != reminder.dueDate.day);

      // If user had marked it completed or snoozed:
      // If caller passed 'pending' (default) but user completed it, and due date hasn't changed, keep completed.
      // But if due date changed to a new date, reset to 'pending'.
      if (reminder.status == 'pending' && existingStatus == 'completed') {
        if (!isDueDateChanged) {
          status = 'completed';
          if (existingData?['completedAt'] is Timestamp) {
            completedAt = (existingData!['completedAt'] as Timestamp).toDate();
          }
        }
      } else if (reminder.status == 'pending' && existingStatus == 'snoozed') {
        if (!isDueDateChanged) {
          status = 'snoozed';
          if (existingData?['snoozedUntil'] is Timestamp) {
            snoozedUntil = (existingData!['snoozedUntil'] as Timestamp).toDate();
          }
        }
      }
    }

    final map = reminder.toMap();
    map['userId'] = userId;
    map['status'] = status;
    map['completedAt'] = completedAt != null ? Timestamp.fromDate(completedAt) : null;
    map['snoozedUntil'] = snoozedUntil != null ? Timestamp.fromDate(snoozedUntil) : null;
    map['createdAt'] = createdAt;

    await docRef.set(map, SetOptions(merge: true));
  }
}
