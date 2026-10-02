import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String module; // 'Warranty', 'SchoolFees', 'Bills', 'General'
  final String status; // 'pending', 'snoozed', 'completed'
  final DateTime dueDate;
  final String? relatedId;
  final DateTime? snoozedUntil;
  final DateTime? completedAt;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.module,
    this.status = 'pending',
    required this.dueDate,
    this.relatedId,
    this.snoozedUntil,
    this.completedAt,
    required this.createdAt,
  });

  factory Reminder.fromMap(Map<String, dynamic> map, String id) {
    return Reminder(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      module: map['module'] ?? 'General',
      status: map['status'] ?? 'pending',
      dueDate: map['dueDate'] is Timestamp
          ? (map['dueDate'] as Timestamp).toDate()
          : DateTime.tryParse(map['dueDate'].toString()) ?? DateTime.now(),
      relatedId: map['relatedId'],
      snoozedUntil: map['snoozedUntil'] is Timestamp
          ? (map['snoozedUntil'] as Timestamp).toDate()
          : (map['snoozedUntil'] != null ? DateTime.tryParse(map['snoozedUntil'].toString()) : null),
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : (map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'module': module,
      'status': status,
      'dueDate': Timestamp.fromDate(dueDate),
      'relatedId': relatedId,
      'snoozedUntil': snoozedUntil != null ? Timestamp.fromDate(snoozedUntil!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Reminder copyWith({
    String? title,
    String? description,
    String? status,
    DateTime? dueDate,
    DateTime? snoozedUntil,
    DateTime? completedAt,
  }) {
    return Reminder(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      module: module,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      relatedId: relatedId,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }
}
