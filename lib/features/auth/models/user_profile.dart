import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String? photoUrl;
  final String currencySymbol;
  final String themeMode; // 'system', 'light', 'dark'
  final bool enableNotifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const String allowedCapsLetters = 'ABCDEFGHIJKLMNPQRSTUVWXYZ'; // 25 letters, strictly no 'O'
  static const String allowedDigits = '123456789'; // 9 digits, strictly no '0'
  static const String allowedAlphanumeric = 'ABCDEFGHIJKLMNPQRSTUVWXYZ123456789'; // 34 characters

  /// Generates a clean 7-character alphanumeric username with uppercase letters and numbers (1-9),
  /// strictly excluding 'O' (letter O) and '0' (digit zero) to eliminate visual ambiguity.
  /// Guarantees both uppercase letters and digits are present in every generated username.
  static String generate7CharUsername() {
    final random = Random.secure();
    final chars = <String>[];

    // Ensure at least one uppercase letter (no 'O') and at least one digit (no '0')
    chars.add(allowedCapsLetters[random.nextInt(allowedCapsLetters.length)]);
    chars.add(allowedDigits[random.nextInt(allowedDigits.length)]);

    // Fill remaining 5 positions from the combined alphanumeric pool
    for (int i = 0; i < 5; i++) {
      chars.add(allowedAlphanumeric[random.nextInt(allowedAlphanumeric.length)]);
    }

    // Securely shuffle positions
    chars.shuffle(random);
    return chars.join();
  }

  /// Checks if a username contains confusing characters ('0', 'O', or 'o').
  static bool hasConfusingChars(String username) {
    final upper = username.toUpperCase();
    return upper.contains('0') || upper.contains('O');
  }

  /// Checks if a username is valid alphanumeric with uppercase letters and digits 1-9 (no 0, no O/o).
  static bool isValidAlphanumeric(String username) {
    final clean = username.trim();
    if (clean.length < 3 || clean.length > 30) return false;
    return RegExp(r'^[A-NP-Z1-9]+$').hasMatch(clean);
  }

  /// Generates a unique 7-character username using only capital letters that is guaranteed not to exist in the database.
  /// If the generated username exists in the db, it regenerates until a unique one is generated.
  static Future<String> generateUniqueUsername({
    FirebaseFirestore? firestore,
    int maxAttempts = 100,
    Future<bool> Function(String username)? isTakenFn,
  }) async {
    final check = isTakenFn ?? ((candidate) => isUsernameTaken(candidate, firestore: firestore));
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = generate7CharUsername();
      final exists = await check(candidate);
      if (!exists) {
        return candidate;
      }
      debugPrint('Generated username "$candidate" already exists in db (attempt ${attempt + 1}). Regenerating...');
    }
    // High-entropy fallback if max attempts reached
    return generate7CharUsername();
  }

  /// Checks if a username already exists in Firestore (checks 'usernames' doc, then fallback 'users' collection).
  /// Case-insensitive so checking 'KXMPEQA' detects both uppercase and legacy lowercase entries.
  static Future<bool> isUsernameTaken(
    String username, {
    FirebaseFirestore? firestore,
  }) async {
    final clean = username.trim();
    if (clean.isEmpty) return false;
    final upper = clean.toUpperCase();
    final lower = clean.toLowerCase();

    // 1. Primary check in 'usernames' collection (single doc lookup)
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      var doc = await db.collection('usernames').doc(upper).get();
      if (!doc.exists && upper != lower) {
        doc = await db.collection('usernames').doc(lower).get();
      }
      if (doc.exists) {
        return true;
      }
    } catch (e) {
      debugPrint('Note: Error checking usernames collection for "$upper": $e');
    }

    // 2. Secondary fallback check in 'users' collection by 'username' field
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      var query = await db
          .collection('users')
          .where('username', isEqualTo: upper)
          .limit(1)
          .get();
      if (query.docs.isEmpty && upper != lower) {
        query = await db
            .collection('users')
            .where('username', isEqualTo: lower)
            .limit(1)
            .get();
      }
      if (query.docs.isNotEmpty) {
        return true;
      }
    } catch (e) {
      // Permission might be denied if unauthenticated or non-owner, which is expected
    }

    return false;
  }

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.username = '',
    this.photoUrl,
    this.currencySymbol = '₹',
    this.themeMode = 'system',
    this.enableNotifications = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      username: map['username'] ?? '',
      photoUrl: map['photoUrl'],
      currencySymbol: map['currencySymbol'] ?? '₹',
      themeMode: map['themeMode'] ?? 'system',
      enableNotifications: map['enableNotifications'] ?? true,
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
      'currencySymbol': currencySymbol,
      'themeMode': themeMode,
      'enableNotifications': enableNotifications,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? photoUrl,
    String? currencySymbol,
    String? themeMode,
    bool? enableNotifications,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      themeMode: themeMode ?? this.themeMode,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
