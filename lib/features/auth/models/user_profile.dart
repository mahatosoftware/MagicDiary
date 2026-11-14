import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Generates a clean 7-character alphanumeric username (lowercase a-z and 0-9).
  /// Starts with an alphabetic character and contains at least one numeric digit.
  static String generate7CharUsername() {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    const digits = '0123456789';
    const allChars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();

    final buffer = StringBuffer();
    // 1st character: letter (a-z)
    buffer.write(letters[random.nextInt(letters.length)]);
    // Next 5 characters: alphanumeric
    for (int i = 0; i < 5; i++) {
      buffer.write(allChars[random.nextInt(allChars.length)]);
    }
    // 7th character guarantee: numeric digit (0-9)
    final digitChar = digits[random.nextInt(digits.length)];
    final charsList = buffer.toString().split('')..add(digitChar);

    // Keep first character as letter, shuffle characters 1..6
    final firstChar = charsList[0];
    final remaining = charsList.sublist(1)..shuffle(random);
    return firstChar + remaining.join();
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
