import 'package:intl/intl.dart';
import '../diary_engine/models/diary_record.dart';

enum DeferOption { plus1Day, plus1Week, plus1Month, customDays }

class WarrantyCalculation {
  final String status; // 'active', 'expiring_soon', 'expired', 'unknown'
  final int? daysRemaining;
  final String? effectiveEndDate;

  WarrantyCalculation({
    required this.status,
    this.daysRemaining,
    this.effectiveEndDate,
  });
}

class DateCalculators {
  static String getWarrantyStatus(DateTime endDate) {
    final diffDays = endDate.difference(DateTime.now()).inDays;
    if (diffDays < 0) return 'expired';
    if (diffDays <= 30) return 'expiring_soon';
    return 'active';
  }

  /// Calculates the next upcoming occurrence for an annual recurring event (e.g. Birthday, Anniversary).
  ///
  /// - If the event is in the future (e.g. upcoming milestone or wedding in a future year),
  ///   the original future date is returned.
  /// - If the event date is historical (e.g. birth year 1990 or anniversary 2015),
  ///   the next occurrence for the current or upcoming year is returned.
  /// - Handles leap year (Feb 29) gracefully on non-leap years.
  static DateTime calculateNextOccurrence(DateTime originalDate, [DateTime? fromDate]) {
    final now = fromDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If the original date is already in the future (including future years), return it directly.
    if (originalDate.isAfter(today) && originalDate.year >= now.year) {
      return originalDate;
    }

    // Resolve day safely for Feb 29 leap year birthdays on non-leap years
    int targetDay = originalDate.day;
    if (originalDate.month == 2 && originalDate.day == 29) {
      final isLeapYear = (now.year % 4 == 0 && (now.year % 100 != 0 || now.year % 400 == 0));
      if (!isLeapYear) {
        targetDay = 28;
      }
    }

    final thisYearDateOnly = DateTime(now.year, originalDate.month, targetDay);
    final hour = originalDate.hour == 0 && originalDate.minute == 0 ? 9 : originalDate.hour;
    final minute = originalDate.minute;

    // If this year's date is today or upcoming this year:
    if (!thisYearDateOnly.isBefore(today)) {
      return DateTime(now.year, originalDate.month, targetDay, hour, minute);
    }

    // Has already passed this year; schedule for next year
    final nextYear = now.year + 1;
    int nextYearTargetDay = originalDate.day;
    if (originalDate.month == 2 && originalDate.day == 29) {
      final isNextYearLeap = (nextYear % 4 == 0 && (nextYear % 100 != 0 || nextYear % 400 == 0));
      if (!isNextYearLeap) {
        nextYearTargetDay = 28;
      }
    }

    return DateTime(nextYear, originalDate.month, nextYearTargetDay, hour, minute);
  }

  /// Calculates the milestone year count (e.g. 30th birthday, 10th anniversary).
  static int calculateMilestoneYears(DateTime originalDate, DateTime targetOccurrence) {
    return targetOccurrence.year - originalDate.year;
  }

  /// Formats milestone label e.g., "30th Birthday (Born 1996)" or "10th Anniversary (Est. 2016)".
  /// When [isShared] is true (viewed by others via individual share or circle),
  /// the birth/milestone year is strictly suppressed to preserve user privacy,
  /// exposing only the generic occasion type and recurrence date.
  static String formatMilestoneLabel(
    DateTime originalDate,
    String eventType,
    DateTime targetOccurrence, {
    bool isShared = false,
  }) {
    final lower = eventType.toLowerCase();
    if (isShared) {
      if (lower.contains('birthday') || lower.contains('birth')) {
        return 'Birthday';
      } else if (lower.contains('anniversary')) {
        return 'Anniversary';
      }
      return eventType;
    }

    final years = targetOccurrence.year - originalDate.year;
    if (years <= 0) return eventType;

    final suffix = _ordinalSuffix(years);
    if (lower.contains('birthday') || lower.contains('birth')) {
      return '$years$suffix Birthday (Born ${originalDate.year})';
    } else if (lower.contains('anniversary')) {
      return '$years$suffix Anniversary (Est. ${originalDate.year})';
    }
    return '$years$suffix Year Milestone';
  }

  /// Checks if a field key or diary represents a birthday or anniversary.
  static bool isBirthdayOrAnniversaryField(String key, {String? diaryId}) {
    final k = key.toLowerCase().trim();
    if (k.contains('birth') ||
        k.contains('dob') ||
        k.contains('anniversary') ||
        k.contains('anniv')) {
      return true;
    }
    if (diaryId == 'family' && (k == 'date_of_birth' || k == 'anniversary')) {
      return true;
    }
    if (diaryId == 'marriage' &&
        (k == 'date' || k == 'wedding_date' || k == 'anniversary')) {
      return true;
    }
    return false;
  }

  /// Checks if a diary record represents an anniversary or birthday.
  static bool isBirthdayOrAnniversaryRecord(DiaryRecord record, {String? diaryId}) {
    final dId = (diaryId ?? record.sourceDiaryId).toLowerCase();
    if (dId == 'marriage') return true;
    final lowerTitle = record.title.toLowerCase();
    final lowerSub = (record.subtitle ?? '').toLowerCase();
    if (lowerTitle.contains('birthday') ||
        lowerTitle.contains('anniversary') ||
        lowerTitle.contains('wedding')) {
      return true;
    }
    if (lowerSub.contains('birthday') || lowerSub.contains('anniversary')) {
      return true;
    }
    for (final key in record.fields.keys) {
      if (isBirthdayOrAnniversaryField(key, diaryId: dId)) {
        return true;
      }
    }
    return false;
  }

  /// Formats a date value (DateTime or String) to show ONLY date and month (e.g. "24 October").
  static String formatDateAndMonth(dynamic dateValue, {String pattern = 'd MMMM'}) {
    if (dateValue == null) return '';
    DateTime? dt;
    if (dateValue is DateTime) {
      dt = dateValue;
    } else if (dateValue is String) {
      dt = DateTime.tryParse(dateValue);
    }
    if (dt != null) {
      return DateFormat(pattern).format(dt);
    }
    return dateValue.toString();
  }

  /// Formats a date based on viewer relationship:
  /// If the event is an annual birthday/anniversary and the viewer is NOT the owner
  /// (individual share or circle), returns date and month only (no year).
  static String formatDateForViewer(
    DateTime date, {
    required bool isAnnual,
    required bool isOwner,
    String ownerPattern = 'd MMM yyyy',
    String othersPattern = 'd MMM',
  }) {
    if (!isOwner && isAnnual) {
      return DateFormat(othersPattern).format(date);
    }
    return DateFormat(ownerPattern).format(date);
  }

  static String _ordinalSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  static DateTime calculateDeferredDate(DateTime base, DeferOption option, {int customDays = 0}) {
    switch (option) {
      case DeferOption.plus1Day:
        return base.add(const Duration(days: 1));
      case DeferOption.plus1Week:
        return base.add(const Duration(days: 7));
      case DeferOption.plus1Month:
        return DateTime(base.year, base.month + 1, base.day);
      case DeferOption.customDays:
        return base.add(Duration(days: customDays));
    }
  }

  static WarrantyCalculation calculateWarrantyStatus({
    required bool hasWarranty,
    String? warrantyStartDate,
    String? warrantyEndDate,
    int? warrantyDurationMonths,
    String? extendedWarrantyEndDate,
    DateTime? referenceDate,
  }) {
    if (!hasWarranty) {
      return WarrantyCalculation(status: 'unknown', daysRemaining: null, effectiveEndDate: null);
    }

    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String? effectiveEnd = extendedWarrantyEndDate;

    if (effectiveEnd == null || effectiveEnd.isEmpty) {
      if (warrantyEndDate != null && warrantyEndDate.isNotEmpty) {
        effectiveEnd = warrantyEndDate;
      } else if (warrantyStartDate != null &&
          warrantyStartDate.isNotEmpty &&
          warrantyDurationMonths != null &&
          warrantyDurationMonths > 0) {
        final start = DateTime.tryParse(warrantyStartDate);
        if (start != null) {
          final end = DateTime(start.year, start.month + warrantyDurationMonths, start.day);
          effectiveEnd = end.toIso8601String().split('T')[0];
        }
      }
    }

    if (effectiveEnd == null || effectiveEnd.isEmpty) {
      return WarrantyCalculation(status: 'unknown', daysRemaining: null, effectiveEndDate: null);
    }

    final endDate = DateTime.tryParse(effectiveEnd);
    if (endDate == null) {
      return WarrantyCalculation(status: 'unknown', daysRemaining: null, effectiveEndDate: null);
    }

    final targetDate = DateTime(endDate.year, endDate.month, endDate.day);
    final diffDays = targetDate.difference(today).inDays;

    String status;
    if (diffDays < 0) {
      status = 'expired';
    } else if (diffDays <= 30) {
      status = 'expiring_soon';
    } else {
      status = 'active';
    }

    return WarrantyCalculation(
      status: status,
      daysRemaining: diffDays,
      effectiveEndDate: effectiveEnd,
    );
  }

  static List<Map<String, dynamic>> generateSchoolFeeSchedule({
    required String feeStructureId,
    required String childId,
    required double totalAmount,
    required String frequency,
    required int numberOfInstallments,
    required DateTime firstDueDate,
  }) {
    final List<Map<String, dynamic>> schedule = [];
    final amountPerInstallment = totalAmount / (numberOfInstallments > 0 ? numberOfInstallments : 1);

    int monthIncrement = 3;
    if (frequency == 'Monthly') monthIncrement = 1;
    if (frequency == 'Quarterly') monthIncrement = 3;
    if (frequency == 'Semi-Annually') monthIncrement = 6;
    if (frequency == 'Annually') monthIncrement = 12;

    for (int i = 0; i < numberOfInstallments; i++) {
      final dueDate = DateTime(firstDueDate.year, firstDueDate.month + (i * monthIncrement), firstDueDate.day);
      schedule.add({
        'installmentNumber': i + 1,
        'title': 'Installment ${i + 1} ($frequency)',
        'amount': amountPerInstallment,
        'dueDate': dueDate,
      });
    }

    return schedule;
  }
}
