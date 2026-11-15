import 'package:cloud_firestore/cloud_firestore.dart';

class FrequentContact {
  final String id;
  final String userId;
  final String email;
  final String name;
  final String? username;
  final String? photoUrl;
  final int useCount;
  final DateTime lastUsedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FrequentContact({
    required this.id,
    required this.userId,
    required this.email,
    this.name = '',
    this.username,
    this.photoUrl,
    this.useCount = 1,
    required this.lastUsedAt,
    required this.createdAt,
    this.updatedAt,
  });

  /// Deterministic ID generator from owner UID and contact email
  static String generateId(String userId, String email) {
    final cleanEmail = email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return '${userId}_contact_$cleanEmail';
  }

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (username != null && username!.trim().isNotEmpty) return '@${username!.trim()}';
    return email.split('@').first;
  }

  String get initials {
    if (name.trim().isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim()[0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  bool matchesQuery(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return true;
    final cleanEmail = email.toLowerCase();
    final cleanName = name.toLowerCase();
    final cleanUsername = username?.toLowerCase() ?? '';

    return cleanEmail.contains(clean) ||
        cleanName.contains(clean) ||
        cleanUsername.contains(clean) ||
        '@$cleanUsername'.contains(clean);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'username': username?.trim(),
      'photoUrl': photoUrl,
      'useCount': useCount,
      'lastUsedAt': Timestamp.fromDate(lastUsedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory FrequentContact.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return FrequentContact(
      id: id,
      userId: map['userId'] as String? ?? '',
      email: (map['email'] as String? ?? '').trim().toLowerCase(),
      name: map['name'] as String? ?? '',
      username: map['username'] as String?,
      photoUrl: map['photoUrl'] as String?,
      useCount: (map['useCount'] as num?)?.toInt() ?? 1,
      lastUsedAt: parseDate(map['lastUsedAt']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  FrequentContact copyWith({
    String? id,
    String? userId,
    String? email,
    String? name,
    String? username,
    String? photoUrl,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FrequentContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
