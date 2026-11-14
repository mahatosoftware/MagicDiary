class HouseholdMember {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'owner', 'admin', 'member', 'viewer'
  final DateTime joinedAt;
  final bool _canRecordAttendance;
  final bool _canApproveSalary;
  final bool _canViewFinancials;
  final bool _canManageTasks;

  HouseholdMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    bool? canRecordAttendance,
    bool? canApproveSalary,
    bool? canViewFinancials,
    bool? canManageTasks,
  })  : _canRecordAttendance = canRecordAttendance ?? (role != 'viewer'),
        _canApproveSalary = canApproveSalary ?? (role == 'owner' || role == 'admin'),
        _canViewFinancials = canViewFinancials ?? (role == 'owner' || role == 'admin'),
        _canManageTasks = canManageTasks ?? (role != 'viewer');

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get canEdit => role != 'viewer';
  bool get canRecordAttendance => isOwner || _canRecordAttendance;
  bool get canApproveSalary => isOwner || _canApproveSalary;
  bool get canViewFinancials => isOwner || _canViewFinancials;
  bool get canManageTasks => isOwner || _canManageTasks;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role,
        'joinedAt': joinedAt.toIso8601String(),
        'canRecordAttendance': canRecordAttendance,
        'canApproveSalary': canApproveSalary,
        'canViewFinancials': canViewFinancials,
        'canManageTasks': canManageTasks,
      };

  factory HouseholdMember.fromJson(Map<String, dynamic> json) => HouseholdMember(
        uid: json['uid'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String? ?? 'Family Member',
        role: json['role'] as String? ?? 'member',
        joinedAt: json['joinedAt'] != null
            ? DateTime.parse(json['joinedAt'] as String)
            : DateTime.now(),
        canRecordAttendance: json['canRecordAttendance'] as bool?,
        canApproveSalary: json['canApproveSalary'] as bool?,
        canViewFinancials: json['canViewFinancials'] as bool?,
        canManageTasks: json['canManageTasks'] as bool?,
      );
}

class Household {
  final String id;
  final String name;
  final String ownerId;
  final List<HouseholdMember> members;
  final String timezone;
  final DateTime createdAt;

  Household({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    this.timezone = 'Asia/Kolkata',
    required this.createdAt,
  });

  bool isMember(String uid) => members.any((m) => m.uid == uid);
  HouseholdMember? getMember(String uid) {
    try {
      return members.firstWhere((m) => m.uid == uid);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'members': members.map((m) => m.toJson()).toList(),
        'timezone': timezone,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['ownerId'] as String,
        members: (json['members'] as List<dynamic>?)
                ?.map((m) => HouseholdMember.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

class HouseholdInvitation {
  final String id;
  final String householdId;
  final String householdName;
  final String inviterUid;
  final String inviterName;
  final String inviteeEmail;
  final String role; // 'admin', 'member', 'viewer'
  final String token;
  final String status; // 'pending', 'accepted', 'declined', 'expired'
  final DateTime expiresAt;
  final DateTime createdAt;

  HouseholdInvitation({
    required this.id,
    required this.householdId,
    required this.householdName,
    required this.inviterUid,
    required this.inviterName,
    required this.inviteeEmail,
    this.role = 'member',
    required this.token,
    this.status = 'pending',
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == 'pending' && !isExpired;

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'householdName': householdName,
        'inviterUid': inviterUid,
        'inviterName': inviterName,
        'inviteeEmail': inviteeEmail,
        'role': role,
        'token': token,
        'status': status,
        'expiresAt': expiresAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory HouseholdInvitation.fromJson(Map<String, dynamic> json) => HouseholdInvitation(
        id: json['id'] as String,
        householdId: json['householdId'] as String,
        householdName: json['householdName'] as String? ?? 'Household',
        inviterUid: json['inviterUid'] as String,
        inviterName: json['inviterName'] as String? ?? 'Family Admin',
        inviteeEmail: json['inviteeEmail'] as String,
        role: json['role'] as String? ?? 'member',
        token: json['token'] as String,
        status: json['status'] as String? ?? 'pending',
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : DateTime.now().add(const Duration(days: 7)),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

class HouseholdTask {
  final String id;
  final String householdId;
  final String title;
  final String description;
  final String? assignedToUid;
  final String? assignedToName;
  final DateTime dueDate;
  final String priority; // 'high', 'medium', 'low'
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedByUid;
  final String createdByUid;
  final DateTime createdAt;

  HouseholdTask({
    required this.id,
    required this.householdId,
    required this.title,
    this.description = '',
    this.assignedToUid,
    this.assignedToName,
    required this.dueDate,
    this.priority = 'medium',
    this.isCompleted = false,
    this.completedAt,
    this.completedByUid,
    required this.createdByUid,
    required this.createdAt,
  });

  HouseholdTask copyWith({
    String? id,
    String? householdId,
    String? title,
    String? description,
    String? assignedToUid,
    String? assignedToName,
    DateTime? dueDate,
    String? priority,
    bool? isCompleted,
    DateTime? completedAt,
    String? completedByUid,
    String? createdByUid,
    DateTime? createdAt,
  }) {
    return HouseholdTask(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedToUid: assignedToUid ?? this.assignedToUid,
      assignedToName: assignedToName ?? this.assignedToName,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedByUid: completedByUid ?? this.completedByUid,
      createdByUid: createdByUid ?? this.createdByUid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'title': title,
        'description': description,
        'assignedToUid': assignedToUid,
        'assignedToName': assignedToName,
        'dueDate': dueDate.toIso8601String(),
        'priority': priority,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'completedByUid': completedByUid,
        'createdByUid': createdByUid,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HouseholdTask.fromJson(Map<String, dynamic> json) => HouseholdTask(
        id: json['id'] as String,
        householdId: json['householdId'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        assignedToUid: json['assignedToUid'] as String?,
        assignedToName: json['assignedToName'] as String?,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : DateTime.now(),
        priority: json['priority'] as String? ?? 'medium',
        isCompleted: json['isCompleted'] as bool? ?? false,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        completedByUid: json['completedByUid'] as String?,
        createdByUid: json['createdByUid'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

class InterMemberSettlement {
  final String id;
  final String householdId;
  final String payerUid;
  final String payerName;
  final String receiverUid;
  final String receiverName;
  final double amount;
  final String reason; // e.g. "50% Electricity Bill reimbursement"
  final DateTime date;
  final bool isSettled;
  final DateTime? settledAt;

  InterMemberSettlement({
    required this.id,
    required this.householdId,
    required this.payerUid,
    required this.payerName,
    required this.receiverUid,
    required this.receiverName,
    required this.amount,
    required this.reason,
    required this.date,
    this.isSettled = false,
    this.settledAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'payerUid': payerUid,
        'payerName': payerName,
        'receiverUid': receiverUid,
        'receiverName': receiverName,
        'amount': amount,
        'reason': reason,
        'date': date.toIso8601String(),
        'isSettled': isSettled,
        'settledAt': settledAt?.toIso8601String(),
      };

  factory InterMemberSettlement.fromJson(Map<String, dynamic> json) => InterMemberSettlement(
        id: json['id'] as String,
        householdId: json['householdId'] as String,
        payerUid: json['payerUid'] as String,
        payerName: json['payerName'] as String? ?? 'Payer',
        receiverUid: json['receiverUid'] as String,
        receiverName: json['receiverName'] as String? ?? 'Receiver',
        amount: (json['amount'] as num).toDouble(),
        reason: json['reason'] as String? ?? '',
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : DateTime.now(),
        isSettled: json['isSettled'] as bool? ?? false,
        settledAt: json['settledAt'] != null
            ? DateTime.parse(json['settledAt'] as String)
            : null,
      );
}
