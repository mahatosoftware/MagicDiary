import 'package:cloud_firestore/cloud_firestore.dart';

enum ScheduleFrequency {
  daily,
  weekly,
  biWeekly,
  monthly,
  quarterly,
  semiAnnual,
  annual,
  triennial,
  quinquennial,
  oneTime;

  String toDbString() {
    switch (this) {
      case ScheduleFrequency.biWeekly:
        return 'bi_weekly';
      case ScheduleFrequency.semiAnnual:
        return 'semi_annual';
      case ScheduleFrequency.triennial:
        return 'triennial';
      case ScheduleFrequency.quinquennial:
        return 'quinquennial';
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
      case 'half_yearly':
      case 'halfyearly':
      case '6_months':
      case '6m':
        return ScheduleFrequency.semiAnnual;
      case 'annual':
      case 'annually':
      case 'yearly':
      case '1_year':
      case '1year':
      case '12_months':
        return ScheduleFrequency.annual;
      case 'triennial':
      case 'every_3_years':
      case '3_years':
      case '3years':
      case '36_months':
        return ScheduleFrequency.triennial;
      case 'quinquennial':
      case 'every_5_years':
      case '5_years':
      case '5years':
      case '60_months':
        return ScheduleFrequency.quinquennial;
      case 'one_time':
      case 'onetime':
        return ScheduleFrequency.oneTime;
      case 'monthly':
      default:
        return ScheduleFrequency.monthly;
    }
  }

  /// Parses the exact interval in months from any standard frequency or custom format
  /// like 'every_10_months', '10_months', '10m', '6_months', 'annual', etc.
  static int parseIntervalMonths(String? val) {
    if (val == null || val.isEmpty) return 1;
    final lower = val.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_').trim();
    if (lower == 'semi_annual' ||
        lower == 'semi_annually' ||
        lower == 'semiannual' ||
        lower == 'half_yearly' ||
        lower == 'halfyearly' ||
        lower == '6_months' ||
        lower == '6m') {
      return 6;
    }
    if (lower == 'annual' ||
        lower == 'annually' ||
        lower == 'yearly' ||
        lower == '1_year' ||
        lower == '1year' ||
        lower == '12_months' ||
        lower == '12m') {
      return 12;
    }
    if (lower == 'triennial' ||
        lower == 'every_3_years' ||
        lower == '3_years' ||
        lower == '3years' ||
        lower == '36_months' ||
        lower == '36m') {
      return 36;
    }
    if (lower == 'quinquennial' ||
        lower == 'every_5_years' ||
        lower == '5_years' ||
        lower == '5years' ||
        lower == '60_months' ||
        lower == '60m') {
      return 60;
    }
    if (lower == 'quarterly' || lower == '3_months' || lower == '3m') {
      return 3;
    }
    if (lower == 'monthly' || lower == '1_month' || lower == '1m') {
      return 1;
    }
    final match = RegExp(r'(\d+)[_\s]*(?:month|m)').firstMatch(lower);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 1;
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
