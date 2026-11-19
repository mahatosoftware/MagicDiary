import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/financial/models/recurring_schedule.dart';
import '../../../core/notifications/services/notification_manager.dart';
import '../../../core/notifications/services/notification_recurrence_engine.dart';
import '../../../core/security/diary_access_control_service.dart';
import '../../../core/utils/date_calculators.dart';
import '../../../features/shared_diaries/models/shared_diary_models.dart';
import '../models/reminder.dart';
import '../services/reminder_action_resolver.dart';
import '../widgets/completion_details_dialog.dart';

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
    final newRem = reminder.copyWith(
      id: newId,
      userId: userId,
      createdAt: reminder.createdAt,
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

  /// Marks a financial reminder as Paid with full transaction audit & occurrence management.
  Future<void> markAsPaid({
    required String userId,
    required String reminderId,
    required ReminderPaymentDetails paymentDetails,
    String? completedBy,
    SharedDiaryAccess? shareAccess,
    String? diaryOwnerId,
  }) async {
    if (userId.isEmpty || reminderId.isEmpty) return;

    // 1. Permission check for shared diaries
    if (diaryOwnerId != null && diaryOwnerId.isNotEmpty && diaryOwnerId != userId) {
      final canPay = DiaryAccessControlService.canCompleteOrPayReminder(
        currentUserId: userId,
        diaryOwnerId: diaryOwnerId,
        shareAccess: shareAccess,
      );
      if (!canPay) {
        throw Exception('Viewer role does not have permission to record payments on this diary.');
      }
    }

    final targetUserId = (diaryOwnerId != null && diaryOwnerId.isNotEmpty) ? diaryOwnerId : userId;
    final docRef = firestore.collection('users').doc(targetUserId).collection('reminders').doc(reminderId);
    final snap = await docRef.get();

    if (!snap.exists) return;
    final data = snap.data() ?? {};

    // 2. Idempotency / Duplicate payment protection
    final currentStatus = data['status'] as String? ?? 'pending';
    if (currentStatus == 'paid' || currentStatus == 'completed') {
      return; // Already resolved, prevent duplicate writes
    }

    final existing = Reminder.fromMap(data, reminderId);
    final isRecurring = existing.repeatSchedule != null &&
        existing.repeatSchedule!.isNotEmpty &&
        existing.repeatSchedule != 'one_time';

    final effectiveCompletedBy = completedBy ?? userId;
    final occurrenceId = existing.occurrenceId ??
        'occ_${existing.dueDate.year}_${existing.dueDate.month.toString().padLeft(2, '0')}_${existing.dueDate.day.toString().padLeft(2, '0')}';

    final batch = firestore.batch();

    // 3. Save historical occurrence record
    final occurrenceRef = docRef.collection('occurrences').doc(occurrenceId);
    batch.set(occurrenceRef, {
      'occurrenceId': occurrenceId,
      'reminderId': reminderId,
      'status': 'paid',
      'actionType': 'mark_paid',
      'dueDate': Timestamp.fromDate(existing.dueDate),
      'completedAt': Timestamp.fromDate(paymentDetails.paidAt),
      'completedBy': effectiveCompletedBy,
      'payment': paymentDetails.toMap(),
      'recordedAt': Timestamp.fromDate(DateTime.now()),
    });

    if (isRecurring) {
      // 4. Recurring reminder: Close ONLY this occurrence, advance parent schedule to next occurrence
      final freq = ScheduleFrequency.fromString(existing.repeatSchedule);
      final nextDueDate = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: existing.dueDate,
        frequency: freq,
      );
      final nextOccId = 'occ_${nextDueDate.year}_${nextDueDate.month.toString().padLeft(2, '0')}_${nextDueDate.day.toString().padLeft(2, '0')}';

      batch.update(docRef, {
        'status': 'pending',
        'dueDate': Timestamp.fromDate(nextDueDate),
        'occurrenceId': nextOccId,
        'snoozedUntil': null,
        'completedAt': null,
        'lastCompletedOccurrence': {
          'occurrenceId': occurrenceId,
          'status': 'paid',
          'paidAt': Timestamp.fromDate(paymentDetails.paidAt),
          'amount': paymentDetails.amount,
          'paymentMethod': paymentDetails.paymentMethod,
          'completedBy': effectiveCompletedBy,
        },
      });
    } else {
      // 5. One-time reminder: Mark reminder document as paid
      batch.update(docRef, {
        'status': 'paid',
        'completedAt': Timestamp.fromDate(paymentDetails.paidAt),
        'completedBy': effectiveCompletedBy,
        'payment': paymentDetails.toMap(),
      });
    }

    // 6. Linked Financial Record Update (if transaction or record is linked)
    final relId = existing.effectiveLinkedRecordId;
    if (relId.isNotEmpty) {
      try {
        final txRef = firestore.collection('users').doc(targetUserId).collection('transactions').doc(relId);
        batch.set(
          txRef,
          {
            'isPaid': true,
            'paidAt': Timestamp.fromDate(paymentDetails.paidAt),
            'paymentMethod': paymentDetails.paymentMethod,
            if (paymentDetails.transactionReference != null)
              'reference': paymentDetails.transactionReference,
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    }

    await batch.commit();

    // 7. Cancel pending notifications for this occurrence
    try {
      await NotificationManager().onRecordPaidOrCompleted(userId: targetUserId, recordId: reminderId);
    } catch (_) {}
  }

  /// Marks a non-financial reminder as Complete, Resolved, or Acknowledged.
  Future<void> markAsComplete({
    required String userId,
    required String reminderId,
    ReminderCompletionDetails? completionDetails,
    String? completedBy,
    SharedDiaryAccess? shareAccess,
    String? diaryOwnerId,
    ReminderActionType actionType = ReminderActionType.markComplete,
  }) async {
    if (userId.isEmpty || reminderId.isEmpty) return;

    // 1. Permission check for shared diaries
    if (diaryOwnerId != null && diaryOwnerId.isNotEmpty && diaryOwnerId != userId) {
      final canComplete = DiaryAccessControlService.canCompleteOrPayReminder(
        currentUserId: userId,
        diaryOwnerId: diaryOwnerId,
        shareAccess: shareAccess,
      );
      if (!canComplete) {
        throw Exception('Viewer role does not have permission to resolve reminders on this diary.');
      }
    }

    final targetUserId = (diaryOwnerId != null && diaryOwnerId.isNotEmpty) ? diaryOwnerId : userId;
    final docRef = firestore.collection('users').doc(targetUserId).collection('reminders').doc(reminderId);
    final snap = await docRef.get();

    if (!snap.exists) return;
    final data = snap.data() ?? {};

    // 2. Idempotency guard
    final currentStatus = data['status'] as String? ?? 'pending';
    if (currentStatus == 'completed' || currentStatus == 'resolved' || currentStatus == 'acknowledged' || currentStatus == 'paid') {
      return;
    }

    final existing = Reminder.fromMap(data, reminderId);
    final isRecurring = existing.repeatSchedule != null &&
        existing.repeatSchedule!.isNotEmpty &&
        existing.repeatSchedule != 'one_time';

    final effectiveCompletedBy = completedBy ?? userId;
    final completedDate = completionDetails?.completedDate ?? DateTime.now();
    final occurrenceId = existing.occurrenceId ??
        'occ_${existing.dueDate.year}_${existing.dueDate.month.toString().padLeft(2, '0')}_${existing.dueDate.day.toString().padLeft(2, '0')}';

    final targetStatus = actionType == ReminderActionType.markResolved
        ? 'resolved'
        : (actionType == ReminderActionType.markAcknowledged ? 'acknowledged' : 'completed');

    final batch = firestore.batch();

    // 3. Save historical occurrence record
    final occurrenceRef = docRef.collection('occurrences').doc(occurrenceId);
    batch.set(occurrenceRef, {
      'occurrenceId': occurrenceId,
      'reminderId': reminderId,
      'status': targetStatus,
      'actionType': actionType.toDbString(),
      'dueDate': Timestamp.fromDate(existing.dueDate),
      'completedAt': Timestamp.fromDate(completedDate),
      'completedBy': effectiveCompletedBy,
      if (completionDetails?.notes != null) 'completionNotes': completionDetails!.notes,
      if (completionDetails?.serviceProvider != null) 'serviceProvider': completionDetails!.serviceProvider,
      if (completionDetails?.actualCost != null) 'actualCost': completionDetails!.actualCost,
      'recordedAt': Timestamp.fromDate(DateTime.now()),
    });

    if (isRecurring) {
      // 4. Recurring: advance to next occurrence
      final freq = ScheduleFrequency.fromString(existing.repeatSchedule);
      final nextDueDate = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: existing.dueDate,
        frequency: freq,
      );
      final nextOccId = 'occ_${nextDueDate.year}_${nextDueDate.month.toString().padLeft(2, '0')}_${nextDueDate.day.toString().padLeft(2, '0')}';

      batch.update(docRef, {
        'status': 'pending',
        'dueDate': Timestamp.fromDate(nextDueDate),
        'occurrenceId': nextOccId,
        'snoozedUntil': null,
        'completedAt': null,
        'lastCompletedOccurrence': {
          'occurrenceId': occurrenceId,
          'status': targetStatus,
          'completedAt': Timestamp.fromDate(completedDate),
          'completedBy': effectiveCompletedBy,
          if (completionDetails?.notes != null) 'notes': completionDetails!.notes,
        },
      });
    } else {
      // 5. One-time reminder
      batch.update(docRef, {
        'status': targetStatus,
        'completedAt': Timestamp.fromDate(completedDate),
        'completedBy': effectiveCompletedBy,
        if (completionDetails?.notes != null) 'completionNotes': completionDetails!.notes,
        if (completionDetails?.serviceProvider != null) 'serviceProvider': completionDetails!.serviceProvider,
        if (completionDetails?.actualCost != null) 'actualCost': completionDetails!.actualCost,
      });
    }

    await batch.commit();

    // 6. Cancel pending notifications for this occurrence
    try {
      await NotificationManager().onRecordPaidOrCompleted(userId: targetUserId, recordId: reminderId);
    } catch (_) {}
  }

  /// Backward-compatible wrapper delegating to context-aware completion.
  Future<void> completeReminder(String userId, String reminderId, {DateTime? completedAt}) async {
    await markAsComplete(
      userId: userId,
      reminderId: reminderId,
      completionDetails: completedAt != null ? ReminderCompletionDetails(completedDate: completedAt) : null,
    );
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
        await completeReminder(userId, doc.id, completedAt: completedAt);
      }
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

      if (reminder.status == 'pending' && (existingStatus == 'completed' || existingStatus == 'paid')) {
        if (!isDueDateChanged) {
          status = existingStatus;
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
