import 'package:cloud_firestore/cloud_firestore.dart';

enum CircleCategory {
  family,
  household,
  travel,
  business,
  education,
  seniorCare,
  propertyManagement,
  friends,
  custom,
}

extension CircleCategoryX on CircleCategory {
  String get label {
    switch (this) {
      case CircleCategory.family:
        return 'Family Circle';
      case CircleCategory.household:
        return 'Household Circle';
      case CircleCategory.travel:
        return 'Travel Circle';
      case CircleCategory.business:
        return 'Business Circle';
      case CircleCategory.education:
        return 'Education Circle';
      case CircleCategory.seniorCare:
        return 'Senior Care Circle';
      case CircleCategory.propertyManagement:
        return 'Property Management Circle';
      case CircleCategory.friends:
        return 'Friends Circle';
      case CircleCategory.custom:
        return 'Custom Circle';
    }
  }
}

enum CircleRole {
  owner,
  admin,
  editor,
  contributor,
  viewer,
}

extension CircleRoleX on CircleRole {
  String get label => name.toUpperCase();
  bool get isOwner => this == CircleRole.owner;
  bool get isAdmin => this == CircleRole.owner || this == CircleRole.admin;
  bool get canEdit => this != CircleRole.viewer;
  bool get canManageMembers => isAdmin;
}

class MagicCircleMember {
  final String uid;
  final String email;
  final String displayName;
  final CircleRole role;
  final DateTime joinedAt;
  final String status; // 'active', 'pending', 'invited'

  MagicCircleMember({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = CircleRole.contributor,
    required this.joinedAt,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'joinedAt': Timestamp.fromDate(joinedAt),
        'status': status,
      };

  factory MagicCircleMember.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return MagicCircleMember(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Member',
      role: CircleRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => CircleRole.contributor,
      ),
      joinedAt: parseDate(map['joinedAt']),
      status: map['status'] as String? ?? 'active',
    );
  }

  MagicCircleMember copyWith({
    String? uid,
    String? email,
    String? displayName,
    CircleRole? role,
    DateTime? joinedAt,
    String? status,
  }) {
    return MagicCircleMember(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
    );
  }
}

class MagicCircle {
  final String id;
  final String name;
  final String description;
  final CircleCategory category;
  final String ownerId;
  final List<MagicCircleMember> members;
  final List<String> memberUids;
  final List<String> memberEmails;
  final List<String> sharedDiaryIds;
  final String? coverImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  MagicCircle({
    required this.id,
    required this.name,
    this.description = '',
    this.category = CircleCategory.family,
    required this.ownerId,
    required this.members,
    List<String>? memberUids,
    List<String>? memberEmails,
    this.sharedDiaryIds = const [],
    this.coverImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  })  : memberUids = memberUids ??
            {
              ownerId,
              ...members
                  .map((m) => m.uid)
                  .where((uid) => uid.isNotEmpty && !uid.startsWith('pending_')),
            }.toList(),
        memberEmails = memberEmails ??
            members
                .map((m) => m.email.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList();

  bool isMember(String uid, [String? email]) {
    if (members.any((m) => m.uid == uid) || memberUids.contains(uid)) return true;
    if (email != null && email.isNotEmpty) {
      final clean = email.trim().toLowerCase();
      return memberEmails.contains(clean) ||
          members.any((m) => m.email.trim().toLowerCase() == clean);
    }
    return false;
  }
  MagicCircleMember? getMember(String uid) {
    try {
      return members.firstWhere((m) => m.uid == uid);
    } catch (_) {
      return null;
    }
  }

  MagicCircle copyWith({
    String? id,
    String? name,
    String? description,
    CircleCategory? category,
    String? ownerId,
    List<MagicCircleMember>? members,
    List<String>? memberUids,
    List<String>? memberEmails,
    List<String>? sharedDiaryIds,
    String? coverImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return MagicCircle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      memberUids: memberUids ?? this.memberUids,
      memberEmails: memberEmails ?? this.memberEmails,
      sharedDiaryIds: sharedDiaryIds ?? this.sharedDiaryIds,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category.name,
        'ownerId': ownerId,
        'members': members.map((m) => m.toMap()).toList(),
        'memberUids': memberUids,
        'memberEmails': memberEmails,
        'sharedDiaryIds': sharedDiaryIds,
        'coverImageUrl': coverImageUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'schemaVersion': schemaVersion,
      };

  factory MagicCircle.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final parsedMembers = (map['members'] as List<dynamic>?)
            ?.map((m) => MagicCircleMember.fromMap(m as Map<String, dynamic>))
            .toList() ??
        const [];

    final ownerId = map['ownerId'] as String? ?? '';

    final parsedMemberUids = (map['memberUids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        {
          ownerId,
          ...parsedMembers
              .map((m) => m.uid)
              .where((uid) => uid.isNotEmpty && !uid.startsWith('pending_')),
        }.toList();

    final parsedMemberEmails = (map['memberEmails'] as List<dynamic>?)
            ?.map((e) => e.toString().trim().toLowerCase())
            .toList() ??
        parsedMembers
            .map((m) => m.email.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

    return MagicCircle(
      id: id,
      name: map['name'] as String? ?? 'Magic Circle',
      description: map['description'] as String? ?? '',
      category: CircleCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => CircleCategory.family,
      ),
      ownerId: ownerId,
      members: parsedMembers,
      memberUids: parsedMemberUids,
      memberEmails: parsedMemberEmails,
      sharedDiaryIds: (map['sharedDiaryIds'] as List<dynamic>?)
              ?.map((d) => d.toString())
              .toList() ??
          const [],
      coverImageUrl: map['coverImageUrl'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

class CircleResponsibilityTask {
  final String id;
  final String circleId;
  final String title;
  final String description;
  final String? sourceDiaryId;
  final String? sourceRecordId;
  final String? assignedToUid;
  final String? assignedToName;
  final String createdByUid;
  final DateTime dueDate;
  final String priority; // 'high', 'medium', 'low'
  final String status; // 'open', 'assigned', 'in_progress', 'completed', 'overdue', 'cancelled'
  final DateTime createdAt;
  final DateTime? completedAt;
  final int schemaVersion;

  CircleResponsibilityTask({
    required this.id,
    required this.circleId,
    required this.title,
    this.description = '',
    this.sourceDiaryId,
    this.sourceRecordId,
    this.assignedToUid,
    this.assignedToName,
    required this.createdByUid,
    required this.dueDate,
    this.priority = 'medium',
    this.status = 'open',
    required this.createdAt,
    this.completedAt,
    this.schemaVersion = 1,
  });

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toMap() => {
        'id': id,
        'circleId': circleId,
        'title': title,
        'description': description,
        'sourceDiaryId': sourceDiaryId,
        'sourceRecordId': sourceRecordId,
        'assignedToUid': assignedToUid,
        'assignedToName': assignedToName,
        'createdByUid': createdByUid,
        'dueDate': Timestamp.fromDate(dueDate),
        'priority': priority,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
        'schemaVersion': schemaVersion,
      };

  factory CircleResponsibilityTask.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return CircleResponsibilityTask(
      id: id,
      circleId: map['circleId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      sourceDiaryId: map['sourceDiaryId'] as String?,
      sourceRecordId: map['sourceRecordId'] as String?,
      assignedToUid: map['assignedToUid'] as String?,
      assignedToName: map['assignedToName'] as String?,
      createdByUid: map['createdByUid'] as String? ?? '',
      dueDate: parseDate(map['dueDate']),
      priority: map['priority'] as String? ?? 'medium',
      status: map['status'] as String? ?? 'open',
      createdAt: parseDate(map['createdAt']),
      completedAt: map['completedAt'] != null ? parseDate(map['completedAt']) : null,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

class CircleExpense {
  final String id;
  final String circleId;
  final String title;
  final double amount;
  final String currency;
  final String paidByUid;
  final String paidByName;
  final List<String> participantUids;
  final String splitType; // 'equal', 'custom', 'percentage'
  final Map<String, double> splitMatrix; // uid -> amount
  final DateTime expenseDate;
  final bool isSettled;
  final DateTime createdAt;
  final int schemaVersion;

  CircleExpense({
    required this.id,
    required this.circleId,
    required this.title,
    required this.amount,
    this.currency = 'INR',
    required this.paidByUid,
    required this.paidByName,
    required this.participantUids,
    this.splitType = 'equal',
    required this.splitMatrix,
    required this.expenseDate,
    this.isSettled = false,
    DateTime? createdAt,
    this.schemaVersion = 1,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'circleId': circleId,
        'title': title,
        'amount': amount,
        'currency': currency,
        'paidByUid': paidByUid,
        'paidByName': paidByName,
        'participantUids': participantUids,
        'splitType': splitType,
        'splitMatrix': splitMatrix,
        'expenseDate': Timestamp.fromDate(expenseDate),
        'isSettled': isSettled,
        'createdAt': Timestamp.fromDate(createdAt),
        'schemaVersion': schemaVersion,
      };

  factory CircleExpense.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final rawMatrix = map['splitMatrix'] as Map<String, dynamic>? ?? {};
    final splitMatrix = rawMatrix.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return CircleExpense(
      id: id,
      circleId: map['circleId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'INR',
      paidByUid: map['paidByUid'] as String? ?? '',
      paidByName: map['paidByName'] as String? ?? '',
      participantUids: (map['participantUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      splitType: map['splitType'] as String? ?? 'equal',
      splitMatrix: splitMatrix,
      expenseDate: parseDate(map['expenseDate']),
      isSettled: map['isSettled'] as bool? ?? false,
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt']) : DateTime.now(),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
