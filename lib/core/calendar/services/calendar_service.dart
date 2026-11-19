import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../../../features/reminders/models/reminder.dart';
import '../../../features/bills/models/bills_models.dart';
import '../../../features/school_fees/models/school_fees_models.dart';
import '../../../features/vehicle/models/vehicle_models.dart';
import '../../../features/property/models/property_models.dart';
import '../../../features/warranty/models/product.dart';
import '../../../features/personal/models/personal_models.dart';
import '../../../features/household/models/household_management_models.dart';
import '../../diary_engine/models/diary_record.dart';
import '../../utils/date_calculators.dart';

class CalendarService {
  static List<CalendarEventItem> aggregateEvents({
    List<Reminder> reminders = const [],
    List<Bill> bills = const [],
    List<FeeInstallment> feeInstallments = const [],
    List<Vehicle> vehicles = const [],
    List<Property> properties = const [],
    List<Product> products = const [],
    List<SpecialEvent> specialEvents = const [],
    List<PersonalGoal> personalGoals = const [],
    List<HouseholdTask> circleTasks = const [],
    List<DiaryRecord> diaryRecords = const [],
  }) {
    final events = <CalendarEventItem>[];

    // 1. Reminders
    for (final r in reminders) {
      events.add(CalendarEventItem(
        id: 'reminder_${r.id}',
        title: r.title,
        subtitle: r.description,
        startTime: r.dueDate,
        sourceType: r.assignedTo != null ? CalendarSourceType.circleDiary : CalendarSourceType.personalDiary,
        sourceDiaryId: r.module.toLowerCase(),
        assignedToMember: r.assignedTo,
        categoryId: 'reminders',
        color: Colors.redAccent,
        route: r.actionRoute ?? '/reminders',
      ));
    }

    // 2. Bills
    for (final b in bills) {
      events.add(CalendarEventItem(
        id: 'bill_${b.id}',
        title: 'Bill: ${b.billPeriod}',
        subtitle: 'Amount: ₹${b.amount.toStringAsFixed(0)} • ${b.status}',
        startTime: b.dueDate,
        sourceType: CalendarSourceType.personalDiary,
        sourceDiaryId: 'bill_payment',
        categoryId: 'financial',
        color: Colors.teal,
        route: '/bills',
      ));
    }

    // 3. School Fees
    for (final f in feeInstallments) {
      events.add(CalendarEventItem(
        id: 'fee_${f.id}',
        title: 'School Fee: ${f.title}',
        subtitle: 'Amount: ₹${f.amount.toStringAsFixed(0)} • ${f.status}',
        startTime: f.dueDate,
        sourceType: CalendarSourceType.personalDiary,
        sourceDiaryId: 'school_education',
        categoryId: 'family_education',
        color: Colors.deepOrange,
        route: '/school-fees',
      ));
    }

    // 4. Vehicles
    for (final v in vehicles) {
      events.add(CalendarEventItem(
        id: 'veh_ins_${v.id}',
        title: 'Insurance Renewal: ${v.name}',
        subtitle: 'Reg: ${v.registrationNumber}',
        startTime: v.insuranceExpiry,
        sourceType: CalendarSourceType.personalDiary,
        sourceDiaryId: 'vehicle',
        categoryId: 'vehicle_travel',
        color: Colors.red,
        route: '/vehicle',
      ));
      events.add(CalendarEventItem(
        id: 'veh_puc_${v.id}',
        title: 'PUC Expiry: ${v.name}',
        subtitle: 'Reg: ${v.registrationNumber}',
        startTime: v.pucExpiry,
        sourceType: CalendarSourceType.personalDiary,
        sourceDiaryId: 'vehicle',
        categoryId: 'vehicle_travel',
        color: Colors.amber.shade900,
        route: '/vehicle',
      ));
    }

    // 5. Properties
    for (final p in properties) {
      events.add(CalendarEventItem(
        id: 'prop_tax_${p.id}',
        title: 'Property Tax Due: ${p.title}',
        subtitle: 'Address: ${p.address}',
        startTime: p.taxDueDate,
        sourceType: CalendarSourceType.personalDiary,
        sourceDiaryId: 'property',
        categoryId: 'home_property',
        color: Colors.indigo,
        route: '/property',
      ));
    }

    // 6. Warranties
    for (final prod in products) {
      if (prod.warrantyEndDate != null) {
        events.add(CalendarEventItem(
          id: 'warr_${prod.id}',
          title: 'Warranty Expiry: ${prod.name}',
          subtitle: 'Brand: ${prod.brand}',
          startTime: prod.warrantyEndDate!,
          sourceType: CalendarSourceType.personalDiary,
          sourceDiaryId: 'warranty_amc',
          categoryId: 'assets_protection',
          color: Colors.blue,
          route: '/warranty',
        ));
      }
    }

    // 7. Special Events & Goals
    final existingEventReminderRelatedIds = reminders
        .where((r) => r.relatedId != null)
        .map((r) => r.relatedId!)
        .toSet();

    for (final ev in specialEvents) {
      if (existingEventReminderRelatedIds.contains(ev.id)) continue;

      final isAnnual = ev.eventType.toLowerCase().contains('birthday') ||
          ev.eventType.toLowerCase().contains('anniversary') ||
          ev.title.toLowerCase().contains('birthday') ||
          ev.title.toLowerCase().contains('anniversary');

      final startTime = isAnnual
          ? DateCalculators.calculateNextOccurrence(ev.date)
          : ev.date;

      events.add(CalendarEventItem(
        id: 'event_${ev.id}',
        title: ev.title,
        subtitle: isAnnual && ev.date.year < DateTime.now().year
            ? DateCalculators.formatMilestoneLabel(ev.date, ev.eventType, startTime)
            : ev.eventType,
        startTime: startTime,
        sourceType: CalendarSourceType.personalDiary,
        sourceDiaryId: 'event',
        categoryId: 'lifestyle_organization',
        color: Colors.purple,
        route: '/personal',
      ));
    }

    for (final g in personalGoals) {
      events.add(CalendarEventItem(
        id: 'goal_${g.id}',
        title: 'Goal Target: ${g.title}',
        subtitle: 'Progress: ${(g.progressPercentage * 100).toInt()}%',
        startTime: g.targetDate,
        sourceType: CalendarSourceType.personalDiary,
        sourceDiaryId: 'savings_goals',
        categoryId: 'lifestyle_organization',
        color: Colors.green,
        route: '/personal',
      ));
    }

    // 8. Circle Tasks
    for (final t in circleTasks) {
      events.add(CalendarEventItem(
        id: 'task_${t.id}',
        title: 'Task: ${t.title}',
        subtitle: 'Assigned: ${t.assignedToName ?? "Unassigned"} • ${t.isCompleted ? "Done" : "Pending"}',
        startTime: t.dueDate,
        sourceType: CalendarSourceType.circleDiary,
        sourceDiaryId: 'circle_tasks',
        circleId: t.householdId,
        assignedToMember: t.assignedToName,
        categoryId: 'circle',
        color: Colors.deepPurple,
        route: '/circles',
      ));
    }

    // 9. Generic Diary Engine Records
    for (final rec in diaryRecords) {
      final isCircleOrShared = rec.circleId != null;
      final isAnnivOrBday = DateCalculators.isBirthdayOrAnniversaryRecord(rec);
      String? cleanSubtitle = rec.subtitle;
      if (isCircleOrShared && isAnnivOrBday) {
        cleanSubtitle = 'Annual • ${DateCalculators.formatDateAndMonth(rec.recordDate, pattern: 'd MMMM')}';
      }

      events.add(CalendarEventItem(
        id: 'rec_${rec.id}',
        title: rec.title,
        subtitle: cleanSubtitle,
        startTime: rec.recordDate,
        sourceType: rec.circleId != null ? CalendarSourceType.circleDiary : CalendarSourceType.personalDiary,
        sourceDiaryId: rec.sourceDiaryId,
        circleId: rec.circleId,
        categoryId: 'diary_records',
        color: Colors.blueGrey,
        route: '/diary-records/${rec.sourceDiaryId}/${rec.id}',
      ));
    }

    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    return events;
  }
}
