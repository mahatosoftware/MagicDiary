import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_action_record.dart';
import '../models/notification_device.dart';
import '../models/notification_enums.dart';
import '../models/notification_history_entry.dart';
import '../models/notification_preference.dart';
import '../models/notification_schedule.dart';

class NotificationRepository {
  final FirebaseFirestore? _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);

  // In-memory cache for fast access & offline test safety
  final Map<String, NotificationPreference> _cachedPreferences = {};
  final Map<String, NotificationSchedule> _cachedSchedules = {};
  final List<NotificationActionRecord> _cachedActions = [];
  final List<NotificationHistoryEntry> _cachedHistory = [];
  final Map<String, NotificationDevice> _cachedDevices = {};

  // =========================================================================
  // 1. PREFERENCES (Global, Module, Category, Record Overrides)
  // =========================================================================

  Future<NotificationPreference?> getGlobalPreference(String userId) async {
    if (userId.isEmpty) return null;
    final cacheKey = 'pref_global_$userId';
    if (_cachedPreferences.containsKey(cacheKey)) {
      return _cachedPreferences[cacheKey];
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_preferences')
            .doc('global')
            .get();
        if (doc.exists && doc.data() != null) {
          final pref = NotificationPreference.fromMap(doc.data()!, 'global');
          _cachedPreferences[cacheKey] = pref;
          return pref;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveGlobalPreference(NotificationPreference pref) async {
    if (pref.userId.isEmpty) return;
    final cacheKey = 'pref_global_${pref.userId}';
    _cachedPreferences[cacheKey] = pref;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(pref.userId)
            .collection('notification_preferences')
            .doc('global')
            .set(pref.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<NotificationPreference?> getModulePreference(String userId, String moduleId) async {
    if (userId.isEmpty || moduleId.isEmpty) return null;
    final cleanModule = moduleId.toLowerCase().trim();
    final cacheKey = 'pref_mod_${userId}_$cleanModule';
    if (_cachedPreferences.containsKey(cacheKey)) {
      return _cachedPreferences[cacheKey];
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_preferences')
            .doc('modules')
            .collection('items')
            .doc(cleanModule)
            .get();
        if (doc.exists && doc.data() != null) {
          final pref = NotificationPreference.fromMap(doc.data()!, cleanModule);
          _cachedPreferences[cacheKey] = pref;
          return pref;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveModulePreference(NotificationPreference pref) async {
    if (pref.userId.isEmpty || (pref.targetId?.isEmpty ?? true)) return;
    final cleanModule = pref.targetId!.toLowerCase().trim();
    final cacheKey = 'pref_mod_${pref.userId}_$cleanModule';
    _cachedPreferences[cacheKey] = pref;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(pref.userId)
            .collection('notification_preferences')
            .doc('modules')
            .collection('items')
            .doc(cleanModule)
            .set(pref.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> deleteModulePreference(String userId, String moduleId) async {
    final cleanModule = moduleId.toLowerCase().trim();
    final cacheKey = 'pref_mod_${userId}_$cleanModule';
    _cachedPreferences.remove(cacheKey);

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_preferences')
            .doc('modules')
            .collection('items')
            .doc(cleanModule)
            .delete();
      } catch (_) {}
    }
  }

  Future<NotificationPreference?> getCategoryPreference(String userId, String categoryId) async {
    if (userId.isEmpty || categoryId.isEmpty) return null;
    final cleanCat = categoryId.toLowerCase().trim();
    final cacheKey = 'pref_cat_${userId}_$cleanCat';
    if (_cachedPreferences.containsKey(cacheKey)) {
      return _cachedPreferences[cacheKey];
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_preferences')
            .doc('categories')
            .collection('items')
            .doc(cleanCat)
            .get();
        if (doc.exists && doc.data() != null) {
          final pref = NotificationPreference.fromMap(doc.data()!, cleanCat);
          _cachedPreferences[cacheKey] = pref;
          return pref;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveCategoryPreference(NotificationPreference pref) async {
    if (pref.userId.isEmpty || (pref.targetId?.isEmpty ?? true)) return;
    final cleanCat = pref.targetId!.toLowerCase().trim();
    final cacheKey = 'pref_cat_${pref.userId}_$cleanCat';
    _cachedPreferences[cacheKey] = pref;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(pref.userId)
            .collection('notification_preferences')
            .doc('categories')
            .collection('items')
            .doc(cleanCat)
            .set(pref.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> deleteCategoryPreference(String userId, String categoryId) async {
    final cleanCat = categoryId.toLowerCase().trim();
    final cacheKey = 'pref_cat_${userId}_$cleanCat';
    _cachedPreferences.remove(cacheKey);

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_preferences')
            .doc('categories')
            .collection('items')
            .doc(cleanCat)
            .delete();
      } catch (_) {}
    }
  }

  Future<NotificationPreference?> getRecordOverride(String userId, String recordId) async {
    if (userId.isEmpty || recordId.isEmpty) return null;
    final cacheKey = 'pref_override_${userId}_$recordId';
    if (_cachedPreferences.containsKey(cacheKey)) {
      return _cachedPreferences[cacheKey];
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_overrides')
            .doc(recordId)
            .get();
        if (doc.exists && doc.data() != null) {
          final pref = NotificationPreference.fromMap(doc.data()!, recordId);
          _cachedPreferences[cacheKey] = pref;
          return pref;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveRecordOverride(NotificationPreference pref) async {
    if (pref.userId.isEmpty || (pref.targetId?.isEmpty ?? true)) return;
    final recordId = pref.targetId!;
    final cacheKey = 'pref_override_${pref.userId}_$recordId';
    _cachedPreferences[cacheKey] = pref;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(pref.userId)
            .collection('notification_overrides')
            .doc(recordId)
            .set(pref.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> deleteRecordOverride(String userId, String recordId) async {
    final cacheKey = 'pref_override_${userId}_$recordId';
    _cachedPreferences.remove(cacheKey);

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_overrides')
            .doc(recordId)
            .delete();
      } catch (_) {}
    }
  }

  // =========================================================================
  // 2. SCHEDULES (notification_schedules)
  // =========================================================================

  Future<void> saveSchedule(String userId, NotificationSchedule schedule) async {
    _cachedSchedules[schedule.id] = schedule;
    if (userId.isEmpty) return;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_schedules')
            .doc(schedule.id)
            .set(schedule.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> saveSchedulesBatch(String userId, List<NotificationSchedule> schedules) async {
    for (final s in schedules) {
      _cachedSchedules[s.id] = s;
    }
    if (userId.isEmpty || schedules.isEmpty) return;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final batch = firestore.batch();
        for (final s in schedules) {
          final ref = firestore
              .collection('users')
              .doc(userId)
              .collection('notification_schedules')
              .doc(s.id);
          batch.set(ref, s.toMap(), SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  Future<List<NotificationSchedule>> getSchedulesForRecord(String userId, String recordId) async {
    final cached = _cachedSchedules.values
        .where((s) => s.userId == userId && s.recordId == recordId)
        .toList();

    final firestore = _firestore;
    if (firestore != null && userId.isNotEmpty) {
      try {
        final snap = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_schedules')
            .where('recordId', isEqualTo: recordId)
            .get();
        final list = snap.docs.map((d) => NotificationSchedule.fromMap(d.data(), d.id)).toList();
        for (final s in list) {
          _cachedSchedules[s.id] = s;
        }
        return list.isNotEmpty ? list : cached;
      } catch (_) {
        return cached;
      }
    }
    return cached;
  }

  Future<List<NotificationSchedule>> getActiveSchedules(String userId) async {
    final cached = _cachedSchedules.values
        .where((s) => s.userId == userId && s.isActive)
        .toList();

    final firestore = _firestore;
    if (firestore != null && userId.isNotEmpty) {
      try {
        final snap = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_schedules')
            .where('status', whereIn: ['scheduled', 'snoozed', 'deferred'])
            .get();
        final list = snap.docs.map((d) => NotificationSchedule.fromMap(d.data(), d.id)).toList();
        for (final s in list) {
          _cachedSchedules[s.id] = s;
        }
        return list.isNotEmpty ? list : cached;
      } catch (_) {
        return cached;
      }
    }
    return cached;
  }

  Future<void> updateScheduleStatus(
    String userId,
    String scheduleId,
    NotificationScheduleStatus status, {
    DateTime? newScheduledAt,
    bool? isSnoozed,
    bool? isDeferred,
    int? snoozeCount,
    int? attemptCount,
    DateTime? lastAttemptAt,
    DateTime? sentAt,
    DateTime? claimLeaseExpiresAt,
    String? claimedByWorker,
    String? errorMessage,
  }) async {
    if (_cachedSchedules.containsKey(scheduleId)) {
      final current = _cachedSchedules[scheduleId]!;
      _cachedSchedules[scheduleId] = current.copyWith(
        status: status,
        scheduledAt: newScheduledAt ?? current.scheduledAt,
        isSnoozed: isSnoozed ?? current.isSnoozed,
        isDeferred: isDeferred ?? current.isDeferred,
        snoozeCount: snoozeCount ?? current.snoozeCount,
        attemptCount: attemptCount ?? current.attemptCount,
        lastAttemptAt: lastAttemptAt ?? current.lastAttemptAt,
        sentAt: sentAt ?? current.sentAt,
        claimLeaseExpiresAt: claimLeaseExpiresAt ?? current.claimLeaseExpiresAt,
        claimedByWorker: claimedByWorker ?? current.claimedByWorker,
        errorMessage: errorMessage ?? current.errorMessage,
        updatedAt: DateTime.now(),
      );
    }

    if (userId.isEmpty) return;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final data = <String, dynamic>{
          'status': status.name,
          'updatedAt': Timestamp.now(),
        };
        if (newScheduledAt != null) {
          data['scheduledAt'] = Timestamp.fromDate(newScheduledAt);
        }
        if (isSnoozed != null) data['isSnoozed'] = isSnoozed;
        if (isDeferred != null) data['isDeferred'] = isDeferred;
        if (snoozeCount != null) data['snoozeCount'] = snoozeCount;
        if (attemptCount != null) data['attemptCount'] = attemptCount;
        if (lastAttemptAt != null) {
          data['lastAttemptAt'] = Timestamp.fromDate(lastAttemptAt);
        }
        if (sentAt != null) {
          data['sentAt'] = Timestamp.fromDate(sentAt);
        }
        if (claimLeaseExpiresAt != null) {
          data['claimLeaseExpiresAt'] = Timestamp.fromDate(claimLeaseExpiresAt);
        }
        if (claimedByWorker != null) data['claimedByWorker'] = claimedByWorker;
        if (errorMessage != null) data['errorMessage'] = errorMessage;

        await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_schedules')
            .doc(scheduleId)
            .update(data);
      } catch (_) {}
    }
  }

  Future<void> cancelSchedulesForRecord(String userId, String recordId) async {
    // Update memory cache
    for (final key in _cachedSchedules.keys) {
      if (_cachedSchedules[key]?.recordId == recordId) {
        _cachedSchedules[key] = _cachedSchedules[key]!.copyWith(
          status: NotificationScheduleStatus.cancelled,
          updatedAt: DateTime.now(),
        );
      }
    }

    if (userId.isEmpty) return;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_schedules')
            .where('recordId', isEqualTo: recordId)
            .where('status', whereIn: ['scheduled', 'snoozed', 'deferred'])
            .get();

        final batch = firestore.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {
            'status': NotificationScheduleStatus.cancelled.name,
            'updatedAt': Timestamp.now(),
          });
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  // =========================================================================
  // 3. ACTION AUDIT RECORDS (notification_actions)
  // =========================================================================

  Future<void> recordAction(String userId, NotificationActionRecord action) async {
    _cachedActions.add(action);
    if (userId.isEmpty) return;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_actions')
            .doc(action.id)
            .set(action.toMap());
      } catch (_) {}
    }
  }

  Future<List<NotificationActionRecord>> getActionsForRecord(String userId, String recordId) async {
    final cached = _cachedActions.where((a) => a.recordId == recordId).toList();
    if (userId.isEmpty) return cached;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_actions')
            .where('recordId', isEqualTo: recordId)
            .orderBy('performedAt', descending: true)
            .get();
        final list = snap.docs.map((d) => NotificationActionRecord.fromMap(d.data(), d.id)).toList();
        return list.isNotEmpty ? list : cached;
      } catch (_) {
        return cached;
      }
    }
    return cached;
  }

  // =========================================================================
  // 4. NOTIFICATION HISTORY (notification_history)
  // =========================================================================

  Future<void> addHistoryEntry(String userId, NotificationHistoryEntry entry) async {
    _cachedHistory.add(entry);
    if (userId.isEmpty) return;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_history')
            .doc(entry.id)
            .set(entry.toMap());
      } catch (_) {}
    }
  }

  Future<List<NotificationHistoryEntry>> getHistoryEntries(String userId, {int limit = 100}) async {
    final cached = List<NotificationHistoryEntry>.from(_cachedHistory);
    cached.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (userId.isEmpty) return cached.take(limit).toList();

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore
            .collection('users')
            .doc(userId)
            .collection('notification_history')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        final list = snap.docs.map((d) => NotificationHistoryEntry.fromMap(d.data(), d.id)).toList();
        return list.isNotEmpty ? list : cached.take(limit).toList();
      } catch (_) {
        return cached.take(limit).toList();
      }
    }
    return cached.take(limit).toList();
  }

  // =========================================================================
  // 5. REGISTERED DEVICES (devices)
  // =========================================================================

  Future<void> registerDevice(String userId, NotificationDevice device) async {
    _cachedDevices[device.id] = device;
    if (userId.isEmpty || device.id.isEmpty) return;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final docRef = firestore
            .collection('users')
            .doc(userId)
            .collection('devices')
            .doc(device.id);

        final docSnap = await docRef.get();
        final data = device.toMap();
        if (docSnap.exists) {
          // Keep immutable createdAt field unchanged when updating existing device
          data.remove('createdAt');
          data['lastActiveAt'] = FieldValue.serverTimestamp();
          await docRef.update(data);
        } else {
          await docRef.set(data);
        }
      } catch (e) {
        debugPrint('Error registering device ${device.id} in Firestore: $e');
      }
    }
  }

  Future<void> deleteDevice(String userId, String deviceId) async {
    _cachedDevices.remove(deviceId);
    if (userId.isEmpty || deviceId.isEmpty) return;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('devices')
            .doc(deviceId)
            .delete();
      } catch (_) {}
    }
  }

  Future<List<NotificationDevice>> getDevices(String userId) async {
    final cached = _cachedDevices.values.toList();
    if (userId.isEmpty) return cached;

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore
            .collection('users')
            .doc(userId)
            .collection('devices')
            .get();
        final list = snap.docs.map((d) => NotificationDevice.fromMap(d.data(), d.id)).toList();
        return list.isNotEmpty ? list : cached;
      } catch (_) {
        return cached;
      }
    }
    return cached;
  }
}
