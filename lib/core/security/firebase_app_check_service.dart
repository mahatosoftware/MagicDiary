import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

/// Centralized Firebase App Check Service for Magic Diary.
///
/// Enforces device attestation (Android Play Integrity, Apple App Attest / DeviceCheck,
/// and Web reCAPTCHA v3) protecting Firebase backend resources (Firestore, Cloud Storage)
/// from abuse, bots, and unauthorized API clients.
class FirebaseAppCheckService {
  static bool _isInitialized = false;

  /// Global master switch for Firebase App Check.
  ///
  /// Keep `false` until the Google Play Console project is linked to Google Cloud
  /// and the Play App Signing SHA-256 fingerprint is registered in Firebase Console (App Check > Apps).
  /// Activating Play Integrity before console registration causes release builds on Play Store to crash.
  static bool isEnabled = false;

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

    if (!isEnabled) {
      if (kDebugMode) {
        debugPrint('[AppCheck] Skipped: App Check is disabled until Play Integrity is registered in Firebase Console.');
      }
      return;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        providerWeb: webRecaptchaSiteKey != null
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
