import 'package:flutter/material.dart';

class TimeOfDayDto {
  final int hour;
  final int minute;

  const TimeOfDayDto({required this.hour, required this.minute})
      : assert(hour >= 0 && hour <= 23, 'Hour must be between 0 and 23'),
        assert(minute >= 0 && minute <= 59, 'Minute must be between 0 and 59');

  static const TimeOfDayDto defaultPreferred = TimeOfDayDto(hour: 9, minute: 0); // 9:00 AM
  static const TimeOfDayDto defaultQuietStart = TimeOfDayDto(hour: 22, minute: 0); // 10:00 PM
  static const TimeOfDayDto defaultQuietEnd = TimeOfDayDto(hour: 7, minute: 0); // 7:00 AM

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  factory TimeOfDayDto.fromTimeOfDay(TimeOfDay time) {
    return TimeOfDayDto(hour: time.hour, minute: time.minute);
  }

  factory TimeOfDayDto.fromString(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return TimeOfDayDto(hour: h, minute: m);
      }
    } catch (_) {}
    return defaultPreferred;
  }

  String format24Hour() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String format12Hour() {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  Map<String, dynamic> toMap() => {
        'hour': hour,
        'minute': minute,
      };

  factory TimeOfDayDto.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaultPreferred;
    return TimeOfDayDto(
      hour: (map['hour'] as num?)?.toInt() ?? 9,
      minute: (map['minute'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDayDto &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;

  @override
  String toString() => format12Hour();
}
