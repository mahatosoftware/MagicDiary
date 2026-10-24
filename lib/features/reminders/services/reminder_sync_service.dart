import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';

/// Centralized service to standardize and synchronize reminders across all Magic Diary modules:
/// - School Fees (Installments)
/// - Bills & Subscriptions (Accounts & Invoices)
/// - Vehicle & Maintenance (Insurance, PUCC, Routine Servicing)
/// - Household (Utility Bills, Rent, Domestic Help)
/// - Property (Property Tax & Municipal Dues)
/// - Warranty (Product Warranty Expirations)
/// - Personal (Life Events, Birthdays, Anniversaries)
class ReminderSyncService {
  final FirebaseFirestore _firestore;

  ReminderSyncService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<int> syncAllDiaries(String userId) async {
    if (userId.isEmpty) return 0;

    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM yyyy');
    final reminderCol = _firestore.collection('users').doc(userId).collection('reminders');

    // Fetch existing reminders map to preserve createdAt timestamps and user statuses
    final existingSnap = await reminderCol.get();
    final existingData = <String, Map<String, dynamic>>{};
    for (final doc in existingSnap.docs) {
      existingData[doc.id] = doc.data();
    }

    final remindersToSync = <Reminder>[];

    // 1. SCHOOL FEES: Fee Installments
    try {
      final childrenSnap = await _firestore.collection('users').doc(userId).collection('children').get();
      final childrenNames = <String, String>{};
      for (final doc in childrenSnap.docs) {
        childrenNames[doc.id] = doc.data()['name'] as String? ?? 'Child';
      }

      final instSnap = await _firestore.collection('users').doc(userId).collection('feeInstallments').get();
      for (final doc in instSnap.docs) {
        final d = doc.data();
        final childId = d['childId'] as String? ?? '';
        final childName = childrenNames[childId] ?? 'Child';
        final title = d['title'] as String? ?? 'School Fee';
        final instNo = d['installmentNumber'] ?? 1;
        final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
        final paidAmount = (d['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final status = d['status'] as String? ?? 'pending';
        final isPaid = status == 'paid' || paidAmount >= amount;

        DateTime dueDate = now;
        if (d['dueDate'] is Timestamp) {
          dueDate = (d['dueDate'] as Timestamp).toDate();
        } else if (d['dueDate'] != null) {
          dueDate = DateTime.tryParse(d['dueDate'].toString()) ?? now;
        }

        final docId = 'reminder_school_${doc.id}';
        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: 'School Fee: $childName - $title',
          description: 'Fee installment #$instNo of ₹${amount.toStringAsFixed(0)} for $childName.',
          module: 'SchoolFees',
          status: isPaid ? 'completed' : 'pending',
          dueDate: dueDate,
          relatedId: doc.id,
          amount: amount,
          actionRoute: '/school-fees',
          createdAt: _resolveCreatedAt(existingData[docId], now),
          completedAt: isPaid ? _resolveCompletedAt(existingData[docId], now) : null,
        ));
      }
    } catch (_) {}

    // 2. BILLS & UTILITIES
    try {
      final accountsSnap = await _firestore.collection('users').doc(userId).collection('billAccounts').get();
      final accountInfo = <String, Map<String, String>>{};
      for (final doc in accountsSnap.docs) {
        final d = doc.data();
        accountInfo[doc.id] = {
          'name': d['name'] as String? ?? 'Bill',
          'provider': d['providerName'] as String? ?? '',
          'category': d['category'] as String? ?? 'Utility',
        };
      }

      final billsSnap = await _firestore.collection('users').doc(userId).collection('bills').get();
      for (final doc in billsSnap.docs) {
        final d = doc.data();
        final accId = d['billAccountId'] as String? ?? '';
        final info = accountInfo[accId] ?? {'name': 'Bill', 'provider': '', 'category': 'Utility'};
        final period = d['billPeriod'] as String? ?? 'Current Period';
        final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
        final status = d['status'] as String? ?? 'pending';
        final isPaid = status.toLowerCase() == 'paid';

        DateTime dueDate = now;
        if (d['dueDate'] is Timestamp) {
          dueDate = (d['dueDate'] as Timestamp).toDate();
        } else if (d['dueDate'] != null) {
          dueDate = DateTime.tryParse(d['dueDate'].toString()) ?? now;
        }

        final docId = 'reminder_bill_${doc.id}';
        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: 'Bill: ${info['name']} ($period)',
          description: '${info['category']} bill from ${info['provider']}. Amount: ₹${amount.toStringAsFixed(0)}.',
          module: 'Bills',
          status: isPaid ? 'completed' : 'pending',
          dueDate: dueDate,
          relatedId: doc.id,
          amount: amount,
          actionRoute: '/bills',
          createdAt: _resolveCreatedAt(existingData[docId], now),
          completedAt: isPaid ? _resolveCompletedAt(existingData[docId], now) : null,
        ));
      }
    } catch (_) {}

    // 3. VEHICLE: Insurance, PUCC, and Routine Servicing
    try {
      final vehiclesSnap = await _firestore.collection('users').doc(userId).collection('vehicles').get();
      for (final doc in vehiclesSnap.docs) {
        final d = doc.data();
        final name = d['name'] as String? ?? 'Vehicle';
        final regNo = d['registrationNumber'] as String? ?? '';

        // Insurance Expiry
        if (d['insuranceExpiry'] != null) {
          final insExpiry = d['insuranceExpiry'] is Timestamp
              ? (d['insuranceExpiry'] as Timestamp).toDate()
              : DateTime.tryParse(d['insuranceExpiry'].toString()) ?? now;
          final docId = 'reminder_veh_${doc.id}_insurance';
          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'Vehicle Insurance: $name',
            description: 'Insurance policy for $name ($regNo) expires on ${dateFormat.format(insExpiry)}. Renew to maintain coverage.',
            module: 'Vehicle',
            status: 'pending',
            dueDate: insExpiry,
            relatedId: doc.id,
            actionRoute: '/vehicle',
            createdAt: _resolveCreatedAt(existingData[docId], now),
          ));
        }

        // PUCC Expiry
        if (d['pucExpiry'] != null) {
          final pucExpiry = d['pucExpiry'] is Timestamp
              ? (d['pucExpiry'] as Timestamp).toDate()
              : DateTime.tryParse(d['pucExpiry'].toString()) ?? now;
          final docId = 'reminder_veh_${doc.id}_pucc';
          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'PUC Certificate: $name',
            description: 'Pollution Under Control (PUC) certificate for $name ($regNo) expires on ${dateFormat.format(pucExpiry)}.',
            module: 'Vehicle',
            status: 'pending',
            dueDate: pucExpiry,
            relatedId: doc.id,
            actionRoute: '/vehicle',
            createdAt: _resolveCreatedAt(existingData[docId], now),
          ));
        }

        // Next Scheduled Service
        if (d['nextServiceDate'] != null) {
          final serviceDate = d['nextServiceDate'] is Timestamp
              ? (d['nextServiceDate'] as Timestamp).toDate()
              : DateTime.tryParse(d['nextServiceDate'].toString());
          if (serviceDate != null) {
            final docId = 'reminder_veh_${doc.id}_service';
            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Routine Service: $name',
              description: 'Scheduled periodic maintenance for $name ($regNo) on ${dateFormat.format(serviceDate)}.',
              module: 'Vehicle',
              status: 'pending',
              dueDate: serviceDate,
              relatedId: doc.id,
              actionRoute: '/vehicle',
              createdAt: _resolveCreatedAt(existingData[docId], now),
            ));
          }
        }
      }
    } catch (_) {}

    // 4. HOUSEHOLD: Recurring Expenses & Utilities
    try {
      final hhSnap = await _firestore.collection('users').doc(userId).collection('householdExpenses').get();
      for (final doc in hhSnap.docs) {
        final d = doc.data();
        final category = d['category'] as String? ?? 'Expense';
        final provider = d['providerName'] as String? ?? '';
        final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
        final period = d['period'] as String? ?? '';
        final status = d['status'] as String? ?? 'pending';
        final isPaid = status.toLowerCase() == 'paid';

        DateTime dueDate = now;
        if (d['dueDate'] is Timestamp) {
          dueDate = (d['dueDate'] as Timestamp).toDate();
        } else if (d['dueDate'] != null) {
          dueDate = DateTime.tryParse(d['dueDate'].toString()) ?? now;
        }

        final docId = 'reminder_hh_${doc.id}';
        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: 'Household: $category ($provider)',
          description: 'Household expense of ₹${amount.toStringAsFixed(0)} for $period ($provider).',
          module: 'Household',
          status: isPaid ? 'completed' : 'pending',
          dueDate: dueDate,
          relatedId: doc.id,
          amount: amount,
          actionRoute: '/household',
          createdAt: _resolveCreatedAt(existingData[docId], now),
          completedAt: isPaid ? _resolveCompletedAt(existingData[docId], now) : null,
        ));
      }
    } catch (_) {}

    // 5. PROPERTY: Property Tax & Dues
    try {
      final propSnap = await _firestore.collection('users').doc(userId).collection('properties').get();
      for (final doc in propSnap.docs) {
        final d = doc.data();
        final title = d['title'] as String? ?? 'Property';
        final taxAmount = (d['propertyTaxAmount'] as num?)?.toDouble() ?? 0.0;
        final taxFreq = d['propertyTaxFrequency'] as String? ?? 'Annual';

        if (d['taxDueDate'] != null) {
          final taxDueDate = d['taxDueDate'] is Timestamp
              ? (d['taxDueDate'] as Timestamp).toDate()
              : DateTime.tryParse(d['taxDueDate'].toString()) ?? now;
          final docId = 'reminder_prop_${doc.id}_tax';
          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'Property Tax: $title',
            description: '$taxFreq municipal property tax of ₹${taxAmount.toStringAsFixed(0)} for $title.',
            module: 'Property',
            status: 'pending',
            dueDate: taxDueDate,
            relatedId: doc.id,
            amount: taxAmount,
            actionRoute: '/property',
            createdAt: _resolveCreatedAt(existingData[docId], now),
          ));
        }
      }
    } catch (_) {}

    // 6. WARRANTY: Expiring Product Warranties
    try {
      final prodSnap = await _firestore.collection('users').doc(userId).collection('products').get();
      for (final doc in prodSnap.docs) {
        final d = doc.data();
        final hasWarranty = d['hasWarranty'] as bool? ?? false;
        final name = d['name'] as String? ?? 'Product';
        final brand = d['brand'] as String? ?? '';

        if (hasWarranty && d['warrantyEndDate'] != null) {
          final warrantyEnd = d['warrantyEndDate'] is Timestamp
              ? (d['warrantyEndDate'] as Timestamp).toDate()
              : DateTime.tryParse(d['warrantyEndDate'].toString());
          if (warrantyEnd != null) {
            final docId = 'reminder_prod_${doc.id}_warranty';
            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Warranty Ending: $name',
              description: 'Manufacturer warranty for $brand $name expires on ${dateFormat.format(warrantyEnd)}.',
              module: 'Warranty',
              status: 'pending',
              dueDate: warrantyEnd,
              relatedId: doc.id,
              actionRoute: '/warranty',
              createdAt: _resolveCreatedAt(existingData[docId], now),
            ));
          }
        }
      }
    } catch (_) {}

    // 7. PERSONAL: Life Events & Anniversaries
    try {
      final eventsSnap = await _firestore.collection('users').doc(userId).collection('events').get();
      for (final doc in eventsSnap.docs) {
        final d = doc.data();
        final title = d['title'] as String? ?? 'Special Event';
        final eventType = d['eventType'] as String? ?? (d['category'] as String? ?? 'Life Event');
        final giftIdeas = d['giftIdeas'] as String?;

        DateTime? eventDate;
        if (d['date'] != null) {
          eventDate = d['date'] is Timestamp
              ? (d['date'] as Timestamp).toDate()
              : DateTime.tryParse(d['date'].toString());
        } else if (d['eventDate'] != null) {
          eventDate = d['eventDate'] is Timestamp
              ? (d['eventDate'] as Timestamp).toDate()
              : DateTime.tryParse(d['eventDate'].toString());
        }
        eventDate ??= now;

        final docId = 'reminder_evt_${doc.id}';
        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: '$eventType: $title',
          description: giftIdeas != null ? 'Gift Ideas: $giftIdeas' : '$title scheduled for ${dateFormat.format(eventDate)}.',
          module: 'Personal',
          status: 'pending',
          dueDate: eventDate,
          relatedId: doc.id,
          actionRoute: '/personal',
          createdAt: _resolveCreatedAt(existingData[docId], now),
        ));
      }
    } catch (_) {}

    // Write all synced reminders into Firestore in batches (max 500 per batch)
    if (remindersToSync.isEmpty) return 0;

    int syncedCount = 0;
    const batchLimit = 400;
    for (int i = 0; i < remindersToSync.length; i += batchLimit) {
      final batch = _firestore.batch();
      final chunk = remindersToSync.skip(i).take(batchLimit);

      for (final rem in chunk) {
        final docRef = reminderCol.doc(rem.id);
        batch.set(docRef, rem.toMap(), SetOptions(merge: true));
        syncedCount++;
      }
      await batch.commit();
    }

    return syncedCount;
  }

  DateTime _resolveCreatedAt(Map<String, dynamic>? existing, DateTime now) {
    if (existing != null && existing['createdAt'] != null) {
      if (existing['createdAt'] is Timestamp) {
        return (existing['createdAt'] as Timestamp).toDate();
      }
      return DateTime.tryParse(existing['createdAt'].toString()) ?? now;
    }
    return now;
  }

  DateTime? _resolveCompletedAt(Map<String, dynamic>? existing, DateTime now) {
    if (existing != null && existing['completedAt'] != null) {
      if (existing['completedAt'] is Timestamp) {
        return (existing['completedAt'] as Timestamp).toDate();
      }
      return DateTime.tryParse(existing['completedAt'].toString()) ?? now;
    }
    return now;
  }
}
