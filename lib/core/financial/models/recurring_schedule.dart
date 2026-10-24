import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleFrequency {
  daily,
  weekly,
  biWeekly,
  monthly,
  quarterly,
  semiAnnual,
  annual,
  oneTime;

  String toDbString() {
    switch (this) {
      case ScheduleFrequency.biWeekly:
        return 'bi_weekly';
      case ScheduleFrequency.semiAnnual:
        return 'semi_annual';
      case ScheduleFrequency.oneTime:
        return 'one_time';
      default:
        return name;
    }
  }

  static ScheduleFrequency fromString(String? val) {
    if (val == null) return ScheduleFrequency.monthly;
    final lower = val.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_').trim();
    switch (lower) {
      case 'daily':
        return ScheduleFrequency.daily;
      case 'weekly':
        return ScheduleFrequency.weekly;
      case 'bi_weekly':
      case 'biweekly':
        return ScheduleFrequency.biWeekly;
      case 'quarterly':
        return ScheduleFrequency.quarterly;
      case 'semi_annual':
      case 'semi_annually':
      case 'semiannual':
        return ScheduleFrequency.semiAnnual;
      case 'annual':
      case 'annually':
      case 'yearly':
        return ScheduleFrequency.annual;
      case 'one_time':
      case 'onetime':
        return ScheduleFrequency.oneTime;
      case 'monthly':
      default:
        return ScheduleFrequency.monthly;
    }
  }
}

/// Defines recurring income, bills, or payment expectations, including frequency,
/// start date, optional end date, and next due date.
class RecurringSchedule {
  final String id;
  final String userId;
  final String title;
  final String categoryId;
  final String? subcategoryId;

  final String sourceModule; // e.g., "household", "bills", "finance"
  final String? sourceRecordId;

  final int expectedAmountMinorUnits;
  final String currencyCode;

  final ScheduleFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDueDate;
  final int dueDayOfMonth; // 1-31

  final bool isActive;
  final bool autoReminder;

  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringSchedule({
    required this.id,
    required this.userId,
    required this.title,
    required this.categoryId,
    this.subcategoryId,
    required this.sourceModule,
    this.sourceRecordId,
    required this.expectedAmountMinorUnits,
    this.currencyCode = 'INR',
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.nextDueDate,
    this.dueDayOfMonth = 1,
    this.isActive = true,
    this.autoReminder = true,
    required this.createdAt,
    required this.updatedAt,
  });

  double get expectedAmount => expectedAmountMinorUnits / 100.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'sourceModule': sourceModule,
        'sourceRecordId': sourceRecordId,
        'expectedAmountMinorUnits': expectedAmountMinorUnits,
        'currencyCode': currencyCode,
        'frequency': frequency.toDbString(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'nextDueDate': Timestamp.fromDate(nextDueDate),
        'dueDayOfMonth': dueDayOfMonth,
        'isActive': isActive,
        'autoReminder': autoReminder,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Map<String, dynamic> toJson() => toMap();

  factory RecurringSchedule.fromMap(Map<String, dynamic> map, [String? docId]) {
    final id = docId ?? map['id'] as String? ?? '';

    int expectedMinor = 0;
    if (map['expectedAmountMinorUnits'] != null) {
      expectedMinor = (map['expectedAmountMinorUnits'] as num).toInt();
    } else if (map['expectedAmount'] != null) {
      expectedMinor = ((map['expectedAmount'] as num).toDouble() * 100).round();
    } else if (map['defaultAmount'] != null) {
      expectedMinor = ((map['defaultAmount'] as num).toDouble() * 100).round();
    }

    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback ?? DateTime.now();
    }

    final start = parseDate(map['startDate']);
    final nextDue = parseDate(map['nextDueDate'], start);
    final created = parseDate(map['createdAt'], start);
    final updated = parseDate(map['updatedAt'], created);

    return RecurringSchedule(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? map['name'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? map['category'] as String? ?? 'Other',
      subcategoryId: map['subcategoryId'] as String?,
      sourceModule: map['sourceModule'] as String? ?? 'bills',
      sourceRecordId: map['sourceRecordId'] as String?,
      expectedAmountMinorUnits: expectedMinor,
      currencyCode: map['currencyCode'] as String? ?? 'INR',
      frequency: ScheduleFrequency.fromString(map['frequency'] as String? ?? map['billingCycle'] as String?),
      startDate: start,
      endDate: map['endDate'] != null ? parseDate(map['endDate']) : null,
      nextDueDate: nextDue,
      dueDayOfMonth: (map['dueDayOfMonth'] as num?)?.toInt() ?? 1,
      isActive: map['isActive'] as bool? ?? true,
      autoReminder: map['autoReminder'] as bool? ?? true,
      createdAt: created,
      updatedAt: updated,
    );
  }

  factory RecurringSchedule.fromJson(Map<String, dynamic> json) =>
      RecurringSchedule.fromMap(json);
}
