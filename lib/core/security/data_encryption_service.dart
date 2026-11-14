import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Centralized data protection, hashing, and field masking service.
/// Uses standard SHA-256 cryptographic hashing and constant-time comparisons.
class DataEncryptionService {
  /// Hashes a sensitive input (e.g., PIN, password, verification token) using SHA-256 with salt.
  static String hashWithSalt(String input, {String salt = 'magic_diary_secure_salt_v1'}) {
    final bytes = utf8.encode('$salt:$input:$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Constant-time string comparison to prevent timing attacks.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Verifies whether candidate input matches the stored hash.
  static bool verifyHash(String candidate, String storedHash, {String salt = 'magic_diary_secure_salt_v1'}) {
    final computed = hashWithSalt(candidate, salt: salt);
    return constantTimeEquals(computed, storedHash);
  }

  /// Masks sensitive financial numbers (e.g. "123456789012" -> "•••• •••• 9012")
  static String maskAccountNumber(String? accountNumber) {
    if (accountNumber == null || accountNumber.isEmpty) return '••••';
    final trimmed = accountNumber.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length <= 4) return trimmed;
    final last4 = trimmed.substring(trimmed.length - 4);
    return '•••• •••• $last4';
  }

  /// Masks sensitive tax or government IDs (e.g. PAN "ABCDE1234F" -> "AB••••••4F")
  static String maskGovernmentId(String? id) {
    if (id == null || id.isEmpty) return '••••';
    if (id.length <= 4) return '••••';
    final prefix = id.substring(0, 2);
    final suffix = id.substring(id.length - 2);
    return '$prefix••••••$suffix';
  }

  /// Masks sensitive currency values for lock-screen or viewer previews (e.g. "₹50,000" -> "₹••••")
  static String maskCurrencyAmount(double? amount, {String symbol = '₹'}) {
    return '$symbol••••';
  }

  /// Generates a cryptographically strong deterministic fingerprint of a string payload.
  static String generateFingerprint(String payload) {
    return sha256.convert(utf8.encode(payload)).toString().substring(0, 16);
  }
}
