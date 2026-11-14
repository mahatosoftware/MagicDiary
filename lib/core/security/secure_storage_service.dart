import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized platform-secure storage service.
/// Uses Android EncryptedSharedPreferences and iOS Keychain Services.
class SecureStorageService {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = {};
  bool _useFallback = false;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  static const String keyAppLockPinHash = 'sec_app_lock_pin_hash';
  static const String keyBiometricEnabled = 'sec_biometric_enabled';
  static const String keyLockTimeoutMinutes = 'sec_lock_timeout_mins';
  static const String keyActiveSessionId = 'sec_active_session_id';
  static const String keyHideSensitiveNotifications = 'sec_hide_sensitive_notifs';
  static const String keyLastActiveTimestamp = 'sec_last_active_ts';

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      _useFallback = true;
      _memoryFallback[key] = value;
    }
  }

  Future<String?> read(String key) async {
    if (_useFallback) return _memoryFallback[key];
    try {
      return await _storage.read(key: key);
    } catch (_) {
      _useFallback = true;
      return _memoryFallback[key];
    }
  }

  Future<void> delete(String key) async {
    _memoryFallback.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    _memoryFallback.clear();
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  // --- Convenience Getters & Setters ---

  Future<bool> isAppLockConfigured() async {
    final hash = await read(keyAppLockPinHash);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setAppLockPin(String pinHash) async {
    await write(keyAppLockPinHash, pinHash);
  }

  Future<void> clearAppLockPin() async {
    await delete(keyAppLockPinHash);
  }

  Future<bool> isBiometricEnabled() async {
    final val = await read(keyBiometricEnabled);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await write(keyBiometricEnabled, enabled.toString());
  }

  Future<int> getLockTimeoutMinutes() async {
    final val = await read(keyLockTimeoutMinutes);
    if (val != null) {
      return int.tryParse(val) ?? 5;
    }
    return 5; // Default 5 minutes
  }

  Future<void> setLockTimeoutMinutes(int minutes) async {
    await write(keyLockTimeoutMinutes, minutes.toString());
  }

  Future<bool> isHideSensitiveNotifications() async {
    final val = await read(keyHideSensitiveNotifications);
    return val == 'true';
  }

  Future<void> setHideSensitiveNotifications(bool hide) async {
    await write(keyHideSensitiveNotifications, hide.toString());
  }
}
