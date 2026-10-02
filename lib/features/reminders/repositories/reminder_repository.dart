import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/mock_data.dart';
import '../../../core/utils/date_calculators.dart';
import '../models/reminder.dart';

class ReminderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final List<Reminder> _mockReminders = List.from(MockData.initialReminders);

  Future<List<Reminder>> getReminders(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.unmodifiable(_mockReminders);
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('reminders').get();
      return snapshot.docs.map((d) => Reminder.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return List.unmodifiable(_mockReminders);
    }
  }

  Future<Reminder> addReminder(String userId, Reminder reminder, {bool isDemo = true}) async {
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

    if (isDemo) {
      _mockReminders.add(newRem);
      return newRem;
    }

    await _firestore.collection('users').doc(userId).collection('reminders').doc(newId).set(newRem.toMap());
    return newRem;
  }

  Future<void> deferReminder(String userId, String reminderId, DeferOption option, {int customDays = 0, bool isDemo = true}) async {
    final DateTime newDueDate = DateCalculators.calculateDeferredDate(DateTime.now(), option, customDays: customDays);
    
    if (isDemo) {
      final index = _mockReminders.indexWhere((r) => r.id == reminderId);
      if (index != -1) {
        _mockReminders[index] = _mockReminders[index].copyWith(
          status: 'snoozed',
          snoozedUntil: newDueDate,
          dueDate: newDueDate,
        );
      }
      return;
    }

    await _firestore.collection('users').doc(userId).collection('reminders').doc(reminderId).update({
      'status': 'snoozed',
      'snoozedUntil': Timestamp.fromDate(newDueDate),
      'dueDate': Timestamp.fromDate(newDueDate),
    });
  }

  Future<void> completeReminder(String userId, String reminderId, {bool isDemo = true}) async {
    if (isDemo) {
      final index = _mockReminders.indexWhere((r) => r.id == reminderId);
      if (index != -1) {
        _mockReminders[index] = _mockReminders[index].copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
        );
      }
      return;
    }

    await _firestore.collection('users').doc(userId).collection('reminders').doc(reminderId).update({
      'status': 'completed',
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
