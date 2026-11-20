import '../../financial/models/recurring_schedule.dart';

class NotificationRecurrenceEngine {
  static const int defaultHorizonDays = 90; // 3 months horizon

  /// Returns the number of days in the given month of a given year (handling leap years).
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days30 = [4, 6, 9, 11];
    if (days30.contains(month)) {
      return 30;
    }
    return 31;
  }

  /// Calculates next monthly occurrence with clamp preserving original month-end target day.
  /// E.g. If target day is 31st:
  /// Jan 31 -> Feb 28 (or 29 in leap year) -> Mar 31 -> Apr 30 -> May 31.
  static DateTime calculateNextMonthlyOccurrence(
    DateTime current,
    int originalTargetDay, {
    int monthsToAdd = 1,
  }) {
    var newYear = current.year;
    var newMonth = current.month + monthsToAdd;

    while (newMonth > 12) {
      newYear++;
      newMonth -= 12;
    }
    while (newMonth < 1) {
      newYear--;
      newMonth += 12;
    }

    final maxDays = daysInMonth(newYear, newMonth);
    final clampedDay = originalTargetDay.clamp(1, maxDays);

    return DateTime(
      newYear,
      newMonth,
      clampedDay,
      current.hour,
      current.minute,
      current.second,
    );
  }

  /// Calculates the immediate next occurrence after `fromDate`.
  static DateTime calculateNextOccurrence({
    required DateTime fromDate,
    required ScheduleFrequency frequency,
    int? dueDayOfMonth,
    int customInterval = 1,
  }) {
    final targetDay = dueDayOfMonth ?? fromDate.day;

    switch (frequency) {
      case ScheduleFrequency.daily:
        return fromDate.add(Duration(days: customInterval));

      case ScheduleFrequency.weekly:
        return fromDate.add(Duration(days: 7 * customInterval));

      case ScheduleFrequency.biWeekly:
        return fromDate.add(Duration(days: 14 * customInterval));

      case ScheduleFrequency.monthly:
        return calculateNextMonthlyOccurrence(fromDate, targetDay, monthsToAdd: customInterval);

      case ScheduleFrequency.quarterly:
        return calculateNextMonthlyOccurrence(fromDate, targetDay, monthsToAdd: 3 * customInterval);

      case ScheduleFrequency.semiAnnual:
        return calculateNextMonthlyOccurrence(fromDate, targetDay, monthsToAdd: 6 * customInterval);

      case ScheduleFrequency.annual:
        var newYear = fromDate.year + customInterval;
        var month = fromDate.month;
        var day = targetDay;
        // Handle Feb 29 leap year into non-leap year
        final maxDays = daysInMonth(newYear, month);
        day = day.clamp(1, maxDays);
        return DateTime(newYear, month, day, fromDate.hour, fromDate.minute, fromDate.second);

      case ScheduleFrequency.triennial:
        return calculateNextMonthlyOccurrence(fromDate, targetDay, monthsToAdd: 36 * customInterval);

      case ScheduleFrequency.quinquennial:
        return calculateNextMonthlyOccurrence(fromDate, targetDay, monthsToAdd: 60 * customInterval);

      case ScheduleFrequency.oneTime:
        return fromDate;
    }
  }

  /// Calculates the next occurrence directly from a repeatSchedule string, supporting
  /// both standard enum frequencies and custom interval formats (e.g. 'every_10_months').
  static DateTime calculateNextOccurrenceFromSchedule({
    required DateTime fromDate,
    required String? repeatSchedule,
    int? dueDayOfMonth,
  }) {
    if (repeatSchedule == null || repeatSchedule.isEmpty) return fromDate;
    final freq = ScheduleFrequency.fromString(repeatSchedule);
    final targetDay = dueDayOfMonth ?? fromDate.day;

    final intervalMonths = ScheduleFrequency.parseIntervalMonths(repeatSchedule);
    if (intervalMonths > 1 &&
        freq != ScheduleFrequency.semiAnnual &&
        freq != ScheduleFrequency.annual &&
        freq != ScheduleFrequency.triennial &&
        freq != ScheduleFrequency.quinquennial &&
        freq != ScheduleFrequency.quarterly) {
      return calculateNextMonthlyOccurrence(fromDate, targetDay, monthsToAdd: intervalMonths);
    }

    return calculateNextOccurrence(
      fromDate: fromDate,
      frequency: freq,
      dueDayOfMonth: targetDay,
    );
  }

  /// Generates a list of all occurrences from `startDate` up to `horizonEndDate` or `maxOccurrences`.
  static List<DateTime> generateOccurrences({
    required DateTime startDate,
    required ScheduleFrequency frequency,
    DateTime? endDate,
    int? maxOccurrences,
    int? dueDayOfMonth,
    int horizonDays = defaultHorizonDays,
    bool isPaused = false,
  }) {
    if (isPaused || frequency == ScheduleFrequency.oneTime) {
      return [startDate];
    }

    final occurrences = <DateTime>[startDate];
    final cutoffDate = endDate ?? startDate.add(Duration(days: horizonDays));
    final targetDay = dueDayOfMonth ?? startDate.day;
    final limit = maxOccurrences ?? 100;

    var current = startDate;
    while (occurrences.length < limit) {
      final next = calculateNextOccurrence(
        fromDate: current,
        frequency: frequency,
        dueDayOfMonth: targetDay,
      );

      if (next.isAfter(cutoffDate)) {
        break;
      }
      occurrences.add(next);
      current = next;
    }

    return occurrences;
  }

  /// Helper to advance a recurring commitment on completion:
  /// marks current occurrence complete and returns the date of the next occurrence.
  static DateTime advanceOccurrenceOnCompletion({
    required DateTime currentOccurrenceDueDate,
    required ScheduleFrequency frequency,
    int? dueDayOfMonth,
  }) {
    return calculateNextOccurrence(
      fromDate: currentOccurrenceDueDate,
      frequency: frequency,
      dueDayOfMonth: dueDayOfMonth,
    );
  }
}
