import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/date_calculators.dart';
import '../models/reminder.dart';
import '../../../core/notifications/services/notification_manager.dart';

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
          actionType: 'Pay',
          priority: isPaid ? 'low' : 'high',
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
          actionType: 'Pay',
          priority: isPaid ? 'low' : 'high',
          createdAt: _resolveCreatedAt(existingData[docId], now),
          completedAt: isPaid ? _resolveCompletedAt(existingData[docId], now) : null,
        ));
      }

      // Also generate reminders for bill accounts that don't have explicit bill docs yet
      for (final doc in accountsSnap.docs) {
        final d = doc.data();
        final accId = doc.id;
        final hasBill = billsSnap.docs.any((b) => b.data()['billAccountId'] == accId);
        if (!hasBill && (d['autoReminder'] as bool? ?? true)) {
          final dueDay = (d['dueDayOfMonth'] as num?)?.toInt() ?? 1;
          final targetDay = dueDay.clamp(1, 28);
          DateTime targetDueDate;
          if (now.day <= targetDay) {
            targetDueDate = DateTime(now.year, now.month, targetDay, 9, 0);
          } else {
            final nextMonth = now.month == 12 ? 1 : now.month + 1;
            final nextYear = now.month == 12 ? now.year + 1 : now.year;
            targetDueDate = DateTime(nextYear, nextMonth, targetDay, 9, 0);
          }
          final name = d['name'] as String? ?? 'Bill';
          final provider = d['providerName'] as String? ?? '';
          final amount = (d['defaultAmount'] as num?)?.toDouble() ?? 0.0;
          final docId = 'reminder_bill_acc_$accId';
          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'Bill: $name',
            description: '${d['category'] ?? "Utility"} bill from $provider. Amount: ₹${amount.toStringAsFixed(0)}.',
            module: 'Bills',
            status: 'pending',
            dueDate: targetDueDate,
            relatedId: accId,
            amount: amount,
            actionRoute: '/bills',
            actionType: 'Pay',
            priority: 'high',
            createdAt: _resolveCreatedAt(existingData[docId], now),
          ));
        }
      }
    } catch (_) {}

    // 3. VEHICLE: Insurance, PUCC, Routine Servicing & Odometer Milestones
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
          final tenureMonths = (d['insuranceTenureMonths'] as num?)?.toInt() ?? 12;
          final tenureLabel = tenureMonths == 6
              ? '6 Months'
              : (tenureMonths == 36
                  ? '3 Years'
                  : (tenureMonths == 60 ? '5 Years' : '1 Year'));
          final repeatSchedule = tenureMonths == 6
              ? 'semi_annual'
              : (tenureMonths == 36
                  ? 'triennial'
                  : (tenureMonths == 60 ? 'quinquennial' : 'annual'));

          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'Vehicle Insurance ($tenureLabel): $name',
            description: 'Insurance policy ($tenureLabel) for $name ($regNo) expires on ${dateFormat.format(insExpiry)}. Renew to maintain coverage.',
            module: 'Vehicle',
            status: 'pending',
            dueDate: insExpiry,
            relatedId: doc.id,
            actionRoute: '/vehicle',
            actionType: 'Renew',
            priority: 'high',
            repeatSchedule: repeatSchedule,
            createdAt: _resolveCreatedAt(existingData[docId], now),
          ));
        }

        // PUCC Expiry
        if (d['pucExpiry'] != null) {
          final pucExpiry = d['pucExpiry'] is Timestamp
              ? (d['pucExpiry'] as Timestamp).toDate()
              : DateTime.tryParse(d['pucExpiry'].toString()) ?? now;
          final docId = 'reminder_veh_${doc.id}_pucc';
          final tenureMonths = (d['pucTenureMonths'] as num?)?.toInt() ?? 12;
          final tenureLabel = tenureMonths == 6 ? '6 Months' : '1 Year';
          final repeatSchedule = tenureMonths == 6 ? 'semi_annual' : 'annual';

          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'PUC Certificate ($tenureLabel): $name',
            description: 'Pollution Under Control (PUC) certificate ($tenureLabel) for $name ($regNo) expires on ${dateFormat.format(pucExpiry)}. Configured for $tenureLabel renewals.',
            module: 'Vehicle',
            status: 'pending',
            dueDate: pucExpiry,
            relatedId: doc.id,
            actionRoute: '/vehicle',
            actionType: 'Renew',
            priority: 'medium',
            repeatSchedule: repeatSchedule,
            createdAt: _resolveCreatedAt(existingData[docId], now),
          ));
        }

        // Next Scheduled Service (Date based)
        if (d['nextServiceDate'] != null) {
          final serviceDate = d['nextServiceDate'] is Timestamp
              ? (d['nextServiceDate'] as Timestamp).toDate()
              : DateTime.tryParse(d['nextServiceDate'].toString());
          if (serviceDate != null) {
            final docId = 'reminder_veh_${doc.id}_service';
            final intervalMonths = (d['serviceIntervalMonths'] as num?)?.toInt() ?? 6;
            final intervalKm = (d['serviceIntervalKm'] as num?)?.toInt() ?? 10000;
            final intervalLabel = intervalMonths == 12 ? '1 Year' : '$intervalMonths Months';
            final repeatSchedule = intervalMonths == 6
                ? 'semi_annual'
                : (intervalMonths == 12 ? 'annual' : 'every_${intervalMonths}_months');

            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Routine Service ($intervalLabel): $name',
              description: 'Scheduled periodic maintenance ($intervalLabel / $intervalKm km) for $name ($regNo) on ${dateFormat.format(serviceDate)}.',
              module: 'Vehicle',
              status: 'pending',
              dueDate: serviceDate,
              relatedId: doc.id,
              actionRoute: '/vehicle',
              actionType: 'Schedule Service',
              priority: 'medium',
              repeatSchedule: repeatSchedule,
              createdAt: _resolveCreatedAt(existingData[docId], now),
            ));
          }
        }

        // Driving License Expiry
        if (d['drivingLicenseExpiry'] != null) {
          final dlExpiry = d['drivingLicenseExpiry'] is Timestamp
              ? (d['drivingLicenseExpiry'] as Timestamp).toDate()
              : DateTime.tryParse(d['drivingLicenseExpiry'].toString());
          if (dlExpiry != null) {
            final docId = 'reminder_veh_${doc.id}_dl';
            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Driving License Expiry: $name',
              description: 'Driving license linked with $name expires on ${dateFormat.format(dlExpiry)}. Renew promptly.',
              module: 'Vehicle',
              status: 'pending',
              dueDate: dlExpiry,
              relatedId: doc.id,
              actionRoute: '/vehicle',
              actionType: 'Renew',
              priority: 'high',
              createdAt: _resolveCreatedAt(existingData[docId], now),
            ));
          }
        }

        // Dual Service: Odometer-based Service Reminders
        final serviceIntervalKm = (d['serviceIntervalKm'] as num?)?.toInt();
        final lastServiceOdometer = (d['lastServiceOdometer'] as num?)?.toInt() ?? 0;
        final currentOdometer = (d['currentOdometer'] as num?)?.toInt() ?? 0;
        if (serviceIntervalKm != null && serviceIntervalKm > 0) {
          final nextServiceOdo = lastServiceOdometer + serviceIntervalKm;
          final kmUntil = nextServiceOdo - currentOdometer;
          if (kmUntil <= 500) {
            final docId = 'reminder_veh_${doc.id}_odo_service';
            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Odometer Service Due: $name',
              description: kmUntil <= 0
                  ? 'Vehicle $name has exceeded its service milestone at $nextServiceOdo km (current: $currentOdometer km).'
                  : 'Vehicle $name is due for service in $kmUntil km ($currentOdometer / $nextServiceOdo km).',
              module: 'Vehicle',
              status: 'pending',
              dueDate: now.add(const Duration(days: 3)),
              relatedId: doc.id,
              actionRoute: '/vehicle',
              actionType: 'Schedule Service',
              priority: 'high',
              createdAt: _resolveCreatedAt(existingData[docId], now),
            ));
          }
        }

        // Vehicle Loan EMI
        final loanEmiAmount = (d['loanEmiAmount'] as num?)?.toDouble();
        if (loanEmiAmount != null && loanEmiAmount > 0) {
          final docId = 'reminder_veh_${doc.id}_emi_${now.month}';
          final existingStatus = existingData[docId]?['status'] as String? ?? 'pending';
          final emiDueDate = DateTime(now.year, now.month, 10, 9, 0);
          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'Vehicle Loan EMI: $name',
            description: 'Monthly vehicle loan EMI of ₹${loanEmiAmount.toStringAsFixed(0)} for $name ($regNo).',
            module: 'Vehicle',
            status: existingStatus,
            dueDate: emiDueDate,
            relatedId: doc.id,
            amount: loanEmiAmount,
            actionRoute: '/vehicle',
            actionType: 'Pay',
            priority: 'high',
            createdAt: _resolveCreatedAt(existingData[docId], now),
            completedAt: existingStatus == 'completed' ? _resolveCompletedAt(existingData[docId], now) : null,
          ));
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
          actionType: 'Pay',
          priority: isPaid ? 'low' : 'medium',
          createdAt: _resolveCreatedAt(existingData[docId], now),
          completedAt: isPaid ? _resolveCompletedAt(existingData[docId], now) : null,
        ));
      }
    } catch (_) {}

    // 5. PROPERTY: Property Tax, Dues & Lease End
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
          final status = _resolveStatus(existingData[docId], 'pending', taxDueDate);
          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'Property Tax: $title',
            description: '$taxFreq municipal property tax of ₹${taxAmount.toStringAsFixed(0)} for $title.',
            module: 'Property',
            status: status,
            dueDate: taxDueDate,
            relatedId: doc.id,
            amount: taxAmount,
            actionRoute: '/property',
            actionType: 'Pay',
            priority: 'medium',
            createdAt: _resolveCreatedAt(existingData[docId], now),
            completedAt: status == 'completed' ? _resolveCompletedAt(existingData[docId], now) : null,
            snoozedUntil: status == 'snoozed' ? _resolveSnoozedUntil(existingData[docId]) : null,
          ));
        }

        if (d['leaseEndDate'] != null) {
          final leaseEnd = d['leaseEndDate'] is Timestamp
              ? (d['leaseEndDate'] as Timestamp).toDate()
              : DateTime.tryParse(d['leaseEndDate'].toString());
          if (leaseEnd != null) {
            final docId = 'reminder_prop_${doc.id}_lease';
            final tenant = d['tenantName'] as String? ?? 'Tenant';
            final status = _resolveStatus(existingData[docId], 'pending', leaseEnd);
            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Lease Expiry: $title',
              description: 'Lease agreement with $tenant for $title expires on ${dateFormat.format(leaseEnd)}.',
              module: 'Property',
              status: status,
              dueDate: leaseEnd,
              relatedId: doc.id,
              actionRoute: '/property',
              actionType: 'Renew',
              priority: 'medium',
              createdAt: _resolveCreatedAt(existingData[docId], now),
              completedAt: status == 'completed' ? _resolveCompletedAt(existingData[docId], now) : null,
              snoozedUntil: status == 'snoozed' ? _resolveSnoozedUntil(existingData[docId]) : null,
            ));
          }
        }
      }
    } catch (_) {}

    // 6. WARRANTY: Expiring Product Warranties & Return Windows
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
              actionType: 'Renew',
              priority: 'medium',
              createdAt: _resolveCreatedAt(existingData[docId], now),
            ));
          }
        }

        if (d['returnDeadline'] != null) {
          final returnDeadline = d['returnDeadline'] is Timestamp
              ? (d['returnDeadline'] as Timestamp).toDate()
              : DateTime.tryParse(d['returnDeadline'].toString());
          if (returnDeadline != null) {
            final docId = 'reminder_prod_${doc.id}_return';
            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Return Window Closing: $name',
              description: 'Return/replacement window for $brand $name closes on ${dateFormat.format(returnDeadline)}.',
              module: 'Warranty',
              status: 'pending',
              dueDate: returnDeadline,
              relatedId: doc.id,
              actionRoute: '/warranty',
              actionType: 'Review',
              priority: 'high',
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

        final isAnnual = eventType.toLowerCase().contains('birthday') ||
            eventType.toLowerCase().contains('anniversary') ||
            title.toLowerCase().contains('birthday') ||
            title.toLowerCase().contains('anniversary');

        final nextDueDate = isAnnual
            ? DateCalculators.calculateNextOccurrence(eventDate, now)
            : eventDate;

        final targetDay = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
        final today = DateTime(now.year, now.month, now.day);
        final daysUntil = targetDay.difference(today).inDays;
        final docId = 'reminder_evt_${doc.id}';

        // Only include birthdays and anniversaries due in next 30 days
        if (isAnnual && (daysUntil < 0 || daysUntil > 30)) {
          if (existingData.containsKey(docId)) {
            try {
              await reminderCol.doc(docId).delete();
            } catch (_) {}
          }
          continue;
        }

        final milestoneDesc = isAnnual && eventDate.year < now.year
            ? '${DateCalculators.formatMilestoneLabel(eventDate, eventType, nextDueDate)}${giftIdeas != null ? " • Gift Ideas: $giftIdeas" : ""}'
            : (giftIdeas != null ? 'Gift Ideas: $giftIdeas' : '$title scheduled for ${dateFormat.format(nextDueDate)}.');

        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: '$eventType: $title',
          description: milestoneDesc,
          module: 'Personal',
          status: 'pending',
          dueDate: nextDueDate,
          relatedId: doc.id,
          actionRoute: '/personal',
          actionType: 'Review',
          priority: 'medium',
          createdAt: _resolveCreatedAt(existingData[docId], now),
        ));
      }
    } catch (_) {}

    // 7b. FAMILY DIARY: Family Member Birthdays & Anniversaries
    try {
      final familySnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('diaries')
          .doc('family')
          .collection('records')
          .get();

      final today = DateTime(now.year, now.month, now.day);

      for (final doc in familySnap.docs) {
        final d = doc.data();
        final fields = (d['fields'] as Map<String, dynamic>?) ?? {};
        final memberName = fields['member_name'] as String? ?? (d['title'] as String? ?? 'Family Member');
        final relation = fields['relation'] as String?;
        final relationLabel = (relation != null && relation.isNotEmpty) ? ' ($relation)' : '';

        // Date of Birth
        final dobVal = fields['date_of_birth'] ?? fields['dob'];
        if (dobVal != null) {
          final dob = dobVal is Timestamp
              ? dobVal.toDate()
              : DateTime.tryParse(dobVal.toString());
          if (dob != null) {
            final nextDob = DateCalculators.calculateNextOccurrence(dob, now);
            final targetDob = DateTime(nextDob.year, nextDob.month, nextDob.day);
            final daysUntil = targetDob.difference(today).inDays;
            final docId = 'reminder_fam_${doc.id}_dob';

            if (daysUntil >= 0 && daysUntil <= 30) {
              final milestone = DateCalculators.formatMilestoneLabel(dob, 'Birthday', nextDob);
              remindersToSync.add(Reminder(
                id: docId,
                userId: userId,
                title: 'Birthday: $memberName$relationLabel',
                description: '$milestone • Family & Contacts Diary',
                module: 'Personal',
                status: 'pending',
                dueDate: nextDob,
                relatedId: doc.id,
                actionRoute: '/diaries',
                actionType: 'Celebrate',
                priority: 'medium',
                createdAt: _resolveCreatedAt(existingData[docId], now),
              ));
            } else if (existingData.containsKey(docId)) {
              try {
                await reminderCol.doc(docId).delete();
              } catch (_) {}
            }
          }
        }

        // Anniversary
        final annivVal = fields['anniversary'];
        if (annivVal != null) {
          final anniv = annivVal is Timestamp
              ? annivVal.toDate()
              : DateTime.tryParse(annivVal.toString());
          if (anniv != null) {
            final nextAnniv = DateCalculators.calculateNextOccurrence(anniv, now);
            final targetAnniv = DateTime(nextAnniv.year, nextAnniv.month, nextAnniv.day);
            final daysUntil = targetAnniv.difference(today).inDays;
            final docId = 'reminder_fam_${doc.id}_anniv';

            if (daysUntil >= 0 && daysUntil <= 30) {
              final milestone = DateCalculators.formatMilestoneLabel(anniv, 'Anniversary', nextAnniv);
              remindersToSync.add(Reminder(
                id: docId,
                userId: userId,
                title: 'Anniversary: $memberName$relationLabel',
                description: '$milestone • Family & Contacts Diary',
                module: 'Personal',
                status: 'pending',
                dueDate: nextAnniv,
                relatedId: doc.id,
                actionRoute: '/diaries',
                actionType: 'Celebrate',
                priority: 'medium',
                createdAt: _resolveCreatedAt(existingData[docId], now),
              ));
            } else if (existingData.containsKey(docId)) {
              try {
                await reminderCol.doc(docId).delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    // 7c. EVENT DIARY: Celebrations & Weddings
    try {
      final eventDiarySnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('diaries')
          .doc('event')
          .collection('records')
          .get();

      final today = DateTime(now.year, now.month, now.day);

      for (final doc in eventDiarySnap.docs) {
        final d = doc.data();
        final fields = (d['fields'] as Map<String, dynamic>?) ?? {};
        final eventName = fields['event_name'] as String? ?? (d['title'] as String? ?? 'Special Event');
        final dateVal = fields['event_date'] ?? d['recordDate'];
        if (dateVal != null) {
          final evDate = dateVal is Timestamp
              ? dateVal.toDate()
              : DateTime.tryParse(dateVal.toString());
          if (evDate != null) {
            final lowerName = eventName.toLowerCase();
            final isAnnual = lowerName.contains('birthday') || lowerName.contains('anniversary');
            final nextEvDate = isAnnual
                ? DateCalculators.calculateNextOccurrence(evDate, now)
                : evDate;
            final targetEvDate = DateTime(nextEvDate.year, nextEvDate.month, nextEvDate.day);
            final daysUntil = targetEvDate.difference(today).inDays;
            final docId = d['reminderId'] as String? ?? 'reminder_record_${doc.id}';

            // Clean up any legacy duplicate doc created with alternate prefix 'reminder_diary_evt_${doc.id}'
            final legacyDocId = 'reminder_diary_evt_${doc.id}';
            if (docId != legacyDocId && existingData.containsKey(legacyDocId)) {
              try {
                await reminderCol.doc(legacyDocId).delete();
              } catch (_) {}
            }

            if (isAnnual && (daysUntil < 0 || daysUntil > 30)) {
              if (existingData.containsKey(docId)) {
                try {
                  await reminderCol.doc(docId).delete();
                } catch (_) {}
              }
              continue;
            }

            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Event: $eventName',
              description: '$eventName scheduled for ${dateFormat.format(nextEvDate)}.',
              module: 'Personal',
              status: 'pending',
              dueDate: nextEvDate,
              relatedId: doc.id,
              actionRoute: '/diaries',
              actionType: 'Celebrate',
              priority: 'medium',
              createdAt: _resolveCreatedAt(existingData[docId], now),
            ));
          }
        }
      }
    } catch (_) {}

    // 8. DOCUMENTS: Expiring Identity & Vault Records
    try {
      final docsSnap = await _firestore.collection('users').doc(userId).collection('documents').get();
      for (final doc in docsSnap.docs) {
        final d = doc.data();
        final title = d['title'] as String? ?? 'Document';
        final category = d['category'] as String? ?? 'General';
        if (d['expiryDate'] != null) {
          final expDate = d['expiryDate'] is Timestamp
              ? (d['expiryDate'] as Timestamp).toDate()
              : DateTime.tryParse(d['expiryDate'].toString());
          if (expDate != null) {
            final docId = 'reminder_doc_${doc.id}_exp';
            remindersToSync.add(Reminder(
              id: docId,
              userId: userId,
              title: 'Document Expiry: $title',
              description: '$category document ($title) expires on ${dateFormat.format(expDate)}. Renew or update.',
              module: 'General',
              status: 'pending',
              dueDate: expDate,
              relatedId: doc.id,
              actionRoute: '/documents',
              actionType: 'Renew',
              priority: 'high',
              createdAt: _resolveCreatedAt(existingData[docId], now),
            ));
          }
        }
      }
    } catch (_) {}

    // 9. DOMESTIC HELP: Staff Salaries & Recurring Services
    try {
      final workersSnap = await _firestore.collection('users').doc(userId).collection('domesticWorkers').get();
      for (final doc in workersSnap.docs) {
        final d = doc.data();
        final isActive = d['isActive'] as bool? ?? true;
        if (!isActive) continue;

        final name = d['name'] as String? ?? 'Staff';
        final role = d['role'] as String? ?? 'Domestic Help';
        final baseSalary = (d['baseSalary'] as num?)?.toDouble() ?? 0.0;
        final dueDay = (d['paymentDueDay'] as num?)?.toInt() ?? 5;

        final salaryDueDate = DateTime(now.year, now.month, dueDay.clamp(1, 28));
        final docId = 'reminder_staff_${doc.id}_${now.month}';

        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: '$role Salary: $name',
          description: 'Monthly salary of ₹${baseSalary.toStringAsFixed(0)} for $name ($role) is due.',
          module: 'Household',
          status: 'pending',
          dueDate: salaryDueDate,
          relatedId: doc.id,
          amount: baseSalary,
          actionRoute: '/domestic-help',
          actionType: 'Pay',
          priority: 'high',
          createdAt: _resolveCreatedAt(existingData[docId], now),
        ));
      }

      final servicesSnap = await _firestore.collection('users').doc(userId).collection('recurringServices').get();
      for (final doc in servicesSnap.docs) {
        final d = doc.data();
        final isActive = d['isActive'] as bool? ?? true;
        if (!isActive) continue;

        final name = d['name'] as String? ?? 'Service';
        final unitRate = (d['unitRate'] as num?)?.toDouble() ?? 0.0;
        final defaultQty = (d['defaultDailyQuantity'] as num?)?.toDouble() ?? 1.0;
        final estMonthly = defaultQty * unitRate * 30;

        final docId = 'reminder_serv_${doc.id}_${now.month}';
        final serviceDueDate = DateTime(now.year, now.month, 28);

        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: 'Vendor Bill: $name',
          description: 'Estimated monthly delivery bill of ₹${estMonthly.toStringAsFixed(0)} for $name.',
          module: 'Household',
          status: 'pending',
          dueDate: serviceDueDate,
          relatedId: doc.id,
          amount: estMonthly,
          actionRoute: '/domestic-help',
          actionType: 'Pay',
          priority: 'medium',
          createdAt: _resolveCreatedAt(existingData[docId], now),
        ));
      }
    } catch (_) {}

    // 9. GENERIC DIARY RECORDS with Reminder settings
    try {
      final recordsSnap = await _firestore.collection('users').doc(userId).collection('diaryRecords').get();
      for (final doc in recordsSnap.docs) {
        final d = doc.data();
        final remindBeforeDaysRaw = d['remindBeforeDays'] as List<dynamic>?;
        final hasReminder = d['hasReminder'] == true || (remindBeforeDaysRaw != null && remindBeforeDaysRaw.isNotEmpty);
        if (!hasReminder) continue;

        final title = d['title'] as String? ?? 'Diary Record';
        final diaryId = d['sourceDiaryId'] as String? ?? '';
        final subtitle = d['subtitle'] as String?;
        final amount = (d['amount'] as num?)?.toDouble();
        final repeatSchedule = d['repeatSchedule'] as String? ?? 'one_time';
        final remindBeforeDays = remindBeforeDaysRaw != null
            ? remindBeforeDaysRaw.map((e) => (e as num).toInt()).toList()
            : <int>[0];

        DateTime recordDate = now;
        if (d['recordDate'] is Timestamp) {
          recordDate = (d['recordDate'] as Timestamp).toDate();
        } else if (d['recordDate'] != null) {
          recordDate = DateTime.tryParse(d['recordDate'].toString()) ?? now;
        }

        final docId = d['reminderId'] as String? ?? 'reminder_record_${doc.id}';
        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: title,
          description: subtitle ?? 'Diary entry reminder for $title',
          module: 'Personal',
          status: _resolveStatus(existingData[docId], 'pending', recordDate),
          dueDate: recordDate,
          relatedId: doc.id,
          amount: amount,
          actionRoute: diaryId.isNotEmpty ? '/diary-records/$diaryId' : null,
          actionType: 'Review',
          priority: 'medium',
          remindBeforeDays: remindBeforeDays,
          repeatSchedule: repeatSchedule,
          createdAt: _resolveCreatedAt(existingData[docId], now),
          snoozedUntil: _resolveSnoozedUntil(existingData[docId]),
          completedAt: _resolveCompletedAt(existingData[docId], now),
        ));
      }
    } catch (_) {}

    // 10. FINANCE TRANSACTIONS: Pending expenses, EMIs & Scheduled commitments
    try {
      final txSnap = await _firestore.collection('users').doc(userId).collection('transactions').get();
      for (final doc in txSnap.docs) {
        final d = doc.data();
        final isPaid = d['isPaid'] as bool? ?? true;
        final hasReminder = d['hasReminder'] as bool? ?? false;
        final type = d['type'] as String? ?? 'Expense';

        if (type.toLowerCase() == 'expense' && (!isPaid || hasReminder)) {
          final desc = d['description'] as String? ?? 'Financial Transaction';
          final category = d['category'] as String? ?? 'Expense';
          final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
          DateTime txDate = now;
          if (d['date'] != null) {
            txDate = DateTime.tryParse(d['date'].toString()) ?? now;
          }

          final docId = 'reminder_tx_${doc.id}';
          remindersToSync.add(Reminder(
            id: docId,
            userId: userId,
            title: 'Payment Due: $desc',
            description: '$category payment of ₹${amount.toStringAsFixed(0)} due on ${dateFormat.format(txDate)}.',
            module: 'Finance',
            status: isPaid ? 'completed' : 'pending',
            dueDate: txDate,
            relatedId: doc.id,
            amount: amount,
            actionRoute: '/finance',
            actionType: 'Pay',
            priority: isPaid ? 'low' : 'high',
            createdAt: _resolveCreatedAt(existingData[docId], now),
            completedAt: isPaid ? _resolveCompletedAt(existingData[docId], now) : null,
          ));
        }
      }
    } catch (_) {}

    // 11. LOAN & EMI DIARY: Home, Personal, Education & Other Loans
    try {
      final loanSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('diaries')
          .doc('loan_emi')
          .collection('records')
          .get();

      for (final doc in loanSnap.docs) {
        final d = doc.data();
        final fields = (d['fields'] as Map<String, dynamic>?) ?? {};
        final lender = fields['lender'] as String? ?? (d['title'] as String? ?? 'Loan');
        final loanType = fields['loan_type'] as String? ?? 'Loan';
        final emiAmount = (fields['emi_amount'] as num?)?.toDouble() ??
            (fields['principal'] as num?)?.toDouble() ??
            (d['amount'] as num?)?.toDouble() ?? 0.0;

        final dueDay = (fields['due_day'] as num?)?.toInt() ??
            (fields['emi_day'] as num?)?.toInt() ?? 10;
        final targetDay = dueDay.clamp(1, 28);

        final targetDueDate = DateTime(now.year, now.month, targetDay, 9, 0);
        final docId = 'reminder_loan_emi_${doc.id}_${now.month}';
        final existingStatus = existingData[docId]?['status'] as String? ?? 'pending';

        remindersToSync.add(Reminder(
          id: docId,
          userId: userId,
          title: '$loanType EMI: $lender',
          description: 'Monthly $loanType installment of ₹${emiAmount.toStringAsFixed(0)} due to $lender.',
          module: 'Finance',
          status: existingStatus,
          dueDate: targetDueDate,
          relatedId: doc.id,
          amount: emiAmount,
          actionRoute: '/finance',
          actionType: 'Pay',
          priority: 'high',
          createdAt: _resolveCreatedAt(existingData[docId], now),
          completedAt: existingStatus == 'completed' ? _resolveCompletedAt(existingData[docId], now) : null,
        ));
      }
    } catch (_) {}

    // Write all synced reminders into Firestore in batches (max 500 per batch)
    // Deduplicate remindersToSync prior to saving to prevent duplicate documents
    final Map<String, Reminder> uniqueSyncMap = {};
    for (final rem in remindersToSync) {
      final cleanTitle = rem.title.toLowerCase().replaceAll(RegExp(r'^(event|special event|reminder|payment due|bill|birthday|anniversary):\s*'), '').trim();
      final dateKey = '${rem.dueDate.year}-${rem.dueDate.month.toString().padLeft(2, '0')}-${rem.dueDate.day.toString().padLeft(2, '0')}';
      final key = (rem.relatedId != null && rem.relatedId!.isNotEmpty)
          ? 'rel_${rem.relatedId}_$dateKey'
          : 'sig_${rem.module.toLowerCase()}_${cleanTitle}_$dateKey';

      if (!uniqueSyncMap.containsKey(key)) {
        uniqueSyncMap[key] = rem;
      } else {
        final existing = uniqueSyncMap[key]!;
        // Prefer pending over completed, or prefer explicit actionRoute/amount
        if (existing.isCompleted && !rem.isCompleted) {
          uniqueSyncMap[key] = rem;
        } else if ((existing.amount == null && rem.amount != null) ||
                   ((existing.actionRoute == null || existing.actionRoute!.isEmpty) && (rem.actionRoute != null && rem.actionRoute!.isNotEmpty))) {
          uniqueSyncMap[key] = rem;
        }
      }
    }
    final deduplicatedSyncList = uniqueSyncMap.values.toList();

    if (deduplicatedSyncList.isEmpty) return 0;

    int syncedCount = 0;
    const batchLimit = 400;
    for (int i = 0; i < deduplicatedSyncList.length; i += batchLimit) {
      final batch = _firestore.batch();
      final chunk = deduplicatedSyncList.skip(i).take(batchLimit);

      for (final rem in chunk) {
        final docRef = reminderCol.doc(rem.id);
        batch.set(docRef, rem.toMap(), SetOptions(merge: true));
        syncedCount++;
      }
      await batch.commit();
    }

    // Standardize & schedule notifications through Central Notification Framework
    try {
      final notifManager = NotificationManager();
      for (final rem in deduplicatedSyncList) {
        if (rem.isCompleted) {
          await notifManager.onRecordPaidOrCompleted(
            userId: userId,
            recordId: rem.id,
            moduleId: _mapModule(rem.module),
          );
        } else {
          await notifManager.scheduleForRecord(
            userId: userId,
            recordId: rem.id,
            moduleId: _mapModule(rem.module),
            categoryId: _mapCategory(rem.module),
            eventType: _mapEventType(rem.title, rem.module),
            title: rem.title,
            dueDate: rem.dueDate,
            amount: rem.amount,
            currency: rem.currencyCode ?? 'INR',
            actionRoute: rem.actionRoute,
            tokenData: {'description': rem.description},
          );
        }
      }
    } catch (_) {}

    return syncedCount;
  }

  String _mapModule(String module) {
    switch (module.toLowerCase().trim()) {
      case 'schoolfees':
      case 'school_fees':
        return 'school_fees';
      case 'bills':
        return 'bills';
      case 'vehicle':
        return 'vehicle';
      case 'household':
        return 'household';
      case 'property':
        return 'property';
      case 'warranty':
        return 'warranty';
      case 'finance':
        return 'finance';
      case 'domestichelp':
      case 'domestic_help':
        return 'domestic_help';
      case 'personal':
      default:
        return 'personal';
    }
  }

  String _mapCategory(String module) => _mapModule(module);

  String _mapEventType(String title, String module) {
    final t = title.toLowerCase();
    if (t.contains('electricity')) return 'electricity_bill';
    if (t.contains('water')) return 'water_bill';
    if (t.contains('internet') || t.contains('broadband')) return 'internet_bill';
    if (t.contains('mobile') || t.contains('recharge')) return 'mobile_bill';
    if (t.contains('gas')) return 'gas_bill';
    if (t.contains('credit card')) return 'credit_card';
    if (t.contains('loan') || t.contains('emi')) return 'loan_emi';
    if (t.contains('insurance')) {
      return module.toLowerCase() == 'vehicle' ? 'vehicle_insurance' : 'insurance_premium';
    }
    if (t.contains('puc')) return 'vehicle_puc';
    if (t.contains('service') || t.contains('maintenance')) {
      return module.toLowerCase() == 'vehicle' ? 'vehicle_servicing' : 'appliance_servicing';
    }
    if (t.contains('warranty')) return 'product_warranty';
    if (t.contains('rent')) return 'rent';
    if (t.contains('tax')) return 'property_tax';
    if (t.contains('school fee')) return 'school_fees';
    if (t.contains('salary')) return 'monthly_salary';
    if (t.contains('birthday')) return 'birthday';
    if (t.contains('anniversary')) return 'anniversary';
    return 'general';
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

  String _resolveStatus(Map<String, dynamic>? existing, String defaultStatus, DateTime newDueDate) {
    if (existing != null) {
      final existingStatus = existing['status'] as String?;
      if (existingStatus == 'completed' || existingStatus == 'snoozed') {
        final existingDueDate = existing['dueDate'] is Timestamp
            ? (existing['dueDate'] as Timestamp).toDate()
            : (existing['dueDate'] != null ? DateTime.tryParse(existing['dueDate'].toString()) : null);
        if (existingDueDate != null &&
            existingDueDate.year == newDueDate.year &&
            existingDueDate.month == newDueDate.month &&
            existingDueDate.day == newDueDate.day) {
          return existingStatus!;
        }
      }
    }
    return defaultStatus;
  }

  DateTime? _resolveSnoozedUntil(Map<String, dynamic>? existing) {
    if (existing != null && existing['snoozedUntil'] != null) {
      if (existing['snoozedUntil'] is Timestamp) {
        return (existing['snoozedUntil'] as Timestamp).toDate();
      }
      return DateTime.tryParse(existing['snoozedUntil'].toString());
    }
    return null;
  }
}
