import 'package:flutter/material.dart';

enum CalendarSourceType {
  personalDiary,
  sharedDiary,
  circleDiary,
  systemReminder,
}

class CalendarEventItem {
  final String id;
  final String title;
  final String? subtitle;
  final DateTime startTime;
  final DateTime? endTime;
  final CalendarSourceType sourceType;
  final String sourceDiaryId;
  final String? circleId;
  final String? circleName;
  final String? assignedToMember;
  final String categoryId;
  final Color color;
  final String route;
  final dynamic extra;

  const CalendarEventItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.startTime,
    this.endTime,
    required this.sourceType,
    required this.sourceDiaryId,
    this.circleId,
    this.circleName,
    this.assignedToMember,
    required this.categoryId,
    required this.color,
    required this.route,
    this.extra,
  });

  bool isSameDay(DateTime other) {
    return startTime.year == other.year &&
        startTime.month == other.month &&
        startTime.day == other.day;
  }
}
