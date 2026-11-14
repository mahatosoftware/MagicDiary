import 'notification_enums.dart';
import 'time_of_day_dto.dart';

class ReminderInterval {
  final int value;
  final ReminderUnit unit;
  final TimeOfDayDto? customTime;

  const ReminderInterval({
    required this.value,
    required this.unit,
    this.customTime,
  });

  // Common Convenience Factories
  static const ReminderInterval onDueDate = ReminderInterval(value: 0, unit: ReminderUnit.onDate);
  static const ReminderInterval oneDayBefore = ReminderInterval(value: 1, unit: ReminderUnit.days);
  static const ReminderInterval threeDaysBefore = ReminderInterval(value: 3, unit: ReminderUnit.days);
  static const ReminderInterval fiveDaysBefore = ReminderInterval(value: 5, unit: ReminderUnit.days);
  static const ReminderInterval sevenDaysBefore = ReminderInterval(value: 7, unit: ReminderUnit.days);
  static const ReminderInterval fifteenDaysBefore = ReminderInterval(value: 15, unit: ReminderUnit.days);
  static const ReminderInterval thirtyDaysBefore = ReminderInterval(value: 30, unit: ReminderUnit.days);

  Duration toDuration() {
    switch (unit) {
      case ReminderUnit.minutes:
        return Duration(minutes: value);
      case ReminderUnit.hours:
        return Duration(hours: value);
      case ReminderUnit.days:
        return Duration(days: value);
      case ReminderUnit.weeks:
        return Duration(days: value * 7);
      case ReminderUnit.onDate:
        return Duration.zero;
    }
  }

  DateTime calculateTriggerTime(DateTime dueDateTime, TimeOfDayDto fallbackTime) {
    final effectiveTime = customTime ?? fallbackTime;

    // Normalize base due date to just the calendar day (or retain time if specific)
    DateTime targetDate;
    if (unit == ReminderUnit.onDate) {
      targetDate = DateTime(
        dueDateTime.year,
        dueDateTime.month,
        dueDateTime.day,
        effectiveTime.hour,
        effectiveTime.minute,
      );
    } else if (unit == ReminderUnit.days || unit == ReminderUnit.weeks) {
      final daysBefore = unit == ReminderUnit.weeks ? value * 7 : value;
      final rawDate = dueDateTime.subtract(Duration(days: daysBefore));
      targetDate = DateTime(
        rawDate.year,
        rawDate.month,
        rawDate.day,
        effectiveTime.hour,
        effectiveTime.minute,
      );
    } else {
      // Minutes or hours before exact dueDateTime
      final baseDate = (dueDateTime.hour == 0 && dueDateTime.minute == 0)
          ? DateTime(dueDateTime.year, dueDateTime.month, dueDateTime.day, fallbackTime.hour, fallbackTime.minute)
          : dueDateTime;
      targetDate = baseDate.subtract(toDuration());
    }

    return targetDate;
  }

  String get displayText {
    if (unit == ReminderUnit.onDate || value == 0) {
      final timeStr = customTime != null ? ' at ${customTime!.format12Hour()}' : '';
      return 'On event date$timeStr';
    }
    final unitStr = value == 1
        ? (unit == ReminderUnit.days ? 'day' : unit == ReminderUnit.hours ? 'hour' : unit == ReminderUnit.weeks ? 'week' : 'minute')
        : (unit == ReminderUnit.days ? 'days' : unit == ReminderUnit.hours ? 'hours' : unit == ReminderUnit.weeks ? 'weeks' : 'minutes');
    final timeStr = customTime != null ? ' at ${customTime!.format12Hour()}' : '';
    return '$value $unitStr before$timeStr';
  }

  String toOffsetKey() {
    if (unit == ReminderUnit.onDate || value == 0) return '0d';
    switch (unit) {
      case ReminderUnit.minutes:
        return '-${value}m';
      case ReminderUnit.hours:
        return '-${value}h';
      case ReminderUnit.days:
        return '-${value}d';
      case ReminderUnit.weeks:
        return '-${value}w';
      case ReminderUnit.onDate:
        return '0d';
    }
  }

  Map<String, dynamic> toMap() => {
        'value': value,
        'unit': unit.name,
        if (customTime != null) 'customTime': customTime!.toMap(),
      };

  factory ReminderInterval.fromMap(Map<String, dynamic> map) {
    return ReminderInterval(
      value: (map['value'] as num?)?.toInt() ?? 0,
      unit: ReminderUnit.fromString(map['unit'] as String?),
      customTime: map['customTime'] != null
          ? TimeOfDayDto.fromMap(map['customTime'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderInterval &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          unit == other.unit &&
          customTime == other.customTime;

  @override
  int get hashCode => value.hashCode ^ unit.hashCode ^ (customTime?.hashCode ?? 0);

  @override
  String toString() => displayText;
}
