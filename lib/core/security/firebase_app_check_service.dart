import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

/// Centralized Firebase App Check Service for Magic Diary.
///
/// Enforces device attestation (Android Play Integrity, Apple App Attest / DeviceCheck,
/// and Web reCAPTCHA v3) protecting Firebase backend resources (Firestore, Cloud Storage)
/// from abuse, bots, and unauthorized API clients.
class FirebaseAppCheckService {
  static bool _isInitialized = false;

  /// Whether App Check has been activated in the current session.
  static bool get isInitialized => _isInitialized;

  /// Initializes and activates Firebase App Check with environment-appropriate providers.
  ///
  /// - Debug Mode: Activates [AndroidProvider.debug] and [AppleProvider.debug], printing
  ///   the App Check debug token to the debug console for registration in Firebase Console.
  /// - Production/Release Mode: Activates [AndroidProvider.playIntegrity] on Android and
  ///   [AppleProvider.appAttestWithDeviceCheckFallback] on Apple devices.
  static Future<void> initialize({String? webRecaptchaSiteKey}) async {
    if (_isInitialized) return;

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
        webProvider: webRecaptchaSiteKey != null
            ? ReCaptchaV3Provider(webRecaptchaSiteKey)
            : null,
      );
      _isInitialized = true;
      debugPrint('[AppCheck] Activated successfully. Debug mode: $kDebugMode');
    } catch (e) {
      // Gracefully capture attestation initialization warnings in environments
      // where App Check has not yet been registered in Firebase console.
      debugPrint('[AppCheck] Initialization warning: $e');
    }
  }

  /// Configures automatic token refreshing.
  static Future<void> setTokenAutoRefreshEnabled(bool enabled) async {
    try {
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(enabled);
    } catch (e) {
      debugPrint('[AppCheck] Error setting token auto-refresh: $e');
    }
  }
}
