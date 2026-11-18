import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryRecord {
  final String id;
  final String ownerId;
  final String sourceDiaryId;
  final String? circleId;
  final String title;
  final String? subtitle;
  final DateTime recordDate;
  final double? amount;
  final String currency;
  final String status; // 'active', 'completed', 'archived', 'pending'
  final List<String> tags;
  final Map<String, dynamic> fields;
  final List<String> restrictedFields;
  final bool isPrivate;
  final List<String> attachmentIds;
  final String? reminderId;
  final List<int> remindBeforeDays; // e.g. [30, 15, 7, 1, 0] where 0 is 'on the day'
  final String repeatSchedule; // 'one_time', 'monthly', 'quarterly', 'yearly'
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  DiaryRecord({
    required this.id,
    required this.ownerId,
    required this.sourceDiaryId,
    this.circleId,
    required this.title,
    this.subtitle,
    required this.recordDate,
    this.amount,
    this.currency = 'INR',
    this.status = 'active',
    this.tags = const [],
    this.fields = const {},
    this.restrictedFields = const [],
    this.isPrivate = false,
    this.attachmentIds = const [],
    this.reminderId,
    this.remindBeforeDays = const [],
    this.repeatSchedule = 'one_time',
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  bool get hasReminder => remindBeforeDays.isNotEmpty;

  bool isFieldRestricted(String fieldKey) => restrictedFields.contains(fieldKey);

  DiaryRecord copyWith({
    String? id,
    String? ownerId,
    String? sourceDiaryId,
    String? circleId,
    String? title,
    String? subtitle,
    DateTime? recordDate,
    double? amount,
    bool clearAmount = false,
    String? currency,
    String? status,
    List<String>? tags,
    Map<String, dynamic>? fields,
    List<String>? restrictedFields,
    bool? isPrivate,
    List<String>? attachmentIds,
    String? reminderId,
    List<int>? remindBeforeDays,
    String? repeatSchedule,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return DiaryRecord(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      sourceDiaryId: sourceDiaryId ?? this.sourceDiaryId,
      circleId: circleId ?? this.circleId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      recordDate: recordDate ?? this.recordDate,
      amount: clearAmount ? null : (amount ?? this.amount),
      currency: currency ?? this.currency,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      fields: fields ?? this.fields,
      restrictedFields: restrictedFields ?? this.restrictedFields,
      isPrivate: isPrivate ?? this.isPrivate,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      reminderId: reminderId ?? this.reminderId,
      remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
      repeatSchedule: repeatSchedule ?? this.repeatSchedule,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'sourceDiaryId': sourceDiaryId,
        'circleId': circleId,
        'title': title,
        'subtitle': subtitle,
        'recordDate': Timestamp.fromDate(recordDate),
        'amount': amount,
        'currency': currency,
        'status': status,
        'tags': tags,
        'fields': fields,
        'restrictedFields': restrictedFields,
        'isPrivate': isPrivate,
        'attachmentIds': attachmentIds,
        'reminderId': reminderId,
        'hasReminder': hasReminder,
        'remindBeforeDays': remindBeforeDays,
        'repeatSchedule': repeatSchedule,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'schemaVersion': schemaVersion,
      };

  factory DiaryRecord.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return DiaryRecord(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      sourceDiaryId: map['sourceDiaryId'] as String? ?? '',
      circleId: map['circleId'] as String?,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      recordDate: parseDate(map['recordDate']),
      amount: (map['amount'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? 'INR',
      status: map['status'] as String? ?? 'active',
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      fields: map['fields'] != null ? Map<String, dynamic>.from(map['fields'] as Map) : const {},
      restrictedFields: (map['restrictedFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isPrivate: map['isPrivate'] as bool? ?? false,
      attachmentIds: (map['attachmentIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      reminderId: map['reminderId'] as String?,
      remindBeforeDays: (map['remindBeforeDays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      repeatSchedule: map['repeatSchedule'] as String? ?? 'one_time',
      createdBy: map['createdBy'] as String? ?? '',
      updatedBy: map['updatedBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
