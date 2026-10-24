import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized Google AdMob Configuration for Magic Diary.
///
/// Contains all Debug/Test Ad Unit IDs provided by Google AdMob,
/// production slot placeholders, and screen-by-screen placement configurations.
/// Manage and switch all ad IDs from this single file.
class AdMobConfig {
  AdMobConfig._();

  /// When set to true, forces test ads even in release builds.
  /// Keep false for production; debug builds will automatically serve test ads.
  static const bool forceTestAds = false;

  /// Determines whether Google AdMob should serve Test Ads.
  ///
  /// ALWAYS returns `true` in debug mode builds ([kDebugMode]), guaranteeing that
  /// all debug builds (emulators, simulators, or physical devices running debug builds)
  /// strictly use Google's official Test Ad IDs and never request production ads.
  ///
  /// In release mode builds ([kReleaseMode]), returns `false` (unless [forceTestAds] is true),
  /// serving registered production AdMob IDs.
  static bool get isTesting => kDebugMode || forceTestAds;

  /// Global master switch to enable or disable all ads across the app.
  static const bool globalAdsEnabled = true;

  // ---------------------------------------------------------------------------
  // Google Official Test IDs (Never click production ads during development!)
  // ---------------------------------------------------------------------------
  static const String _testAndroidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';

  static const String _testAndroidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  static const String _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static const String _testAndroidNative = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testIosNative = 'ca-app-pub-3940256099942544/3986624511';

  static const String _testAndroidAppOpen = 'ca-app-pub-3940256099942544/9257390202';
  static const String _testIosAppOpen = 'ca-app-pub-3940256099942544/5575463023';

  // ---------------------------------------------------------------------------
  // Production Ad Unit IDs (Replace with your registered AdMob Unit IDs)
  // ---------------------------------------------------------------------------
  static const String _prodAndroidBanner = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodIosBanner = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  static const String _prodAndroidInterstitial = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodIosInterstitial = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  static const String _prodAndroidRewarded = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodIosRewarded = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  static const String _prodAndroidNative = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodIosNative = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  // ---------------------------------------------------------------------------
  // Screen-by-Screen Placement Identifiers
  // ---------------------------------------------------------------------------
  static const String placementDiariesBanner = 'diaries_hub_banner';
  static const String placementWarrantyNative = 'warranty_list_native';
  static const String placementRemindersNative = 'reminders_hub_native';
  static const String placementVehicleInline = 'vehicle_diary_inline';
  static const String placementPaymentsInline = 'payments_hub_inline';
  static const String placementReportsInline = 'financial_reports_inline';

  /// Checks if current platform supports native Google Mobile Ads SDK (Android / iOS).
  static bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Banner Ad Unit ID resolved for the current operating system.
  static String get bannerAdUnitId {
    if (isTesting) {
      return Platform.isAndroid ? _testAndroidBanner : _testIosBanner;
    }
    return Platform.isAndroid ? _prodAndroidBanner : _prodIosBanner;
  }

  /// Native Advanced Ad Unit ID resolved for the current operating system.
  static String get nativeAdUnitId {
    if (isTesting) {
      return Platform.isAndroid ? _testAndroidNative : _testIosNative;
    }
    return Platform.isAndroid ? _prodAndroidNative : _prodIosNative;
  }

  /// Interstitial Ad Unit ID resolved for the current operating system.
  static String get interstitialAdUnitId {
    if (isTesting) {
      return Platform.isAndroid ? _testAndroidInterstitial : _testIosInterstitial;
    }
    return Platform.isAndroid ? _prodAndroidInterstitial : _prodIosInterstitial;
  }

  /// Rewarded Video Ad Unit ID resolved for the current operating system.
  static String get rewardedAdUnitId {
    if (isTesting) {
      return Platform.isAndroid ? _testAndroidRewarded : _testIosRewarded;
    }
    return Platform.isAndroid ? _prodAndroidRewarded : _prodIosRewarded;
  }

  /// App Open Ad Unit ID resolved for the current operating system.
  static String get appOpenAdUnitId {
    if (isTesting) {
      return Platform.isAndroid ? _testAndroidAppOpen : _testIosAppOpen;
    }
    return Platform.isAndroid ? _prodAndroidBanner : _prodIosBanner;
  }

  /// Returns ad unit ID for a specific screen placement.
  static String getAdUnitIdForPlacement(String placement) {
    switch (placement) {
      case placementWarrantyNative:
      case placementRemindersNative:
      case placementPaymentsInline:
      case placementReportsInline:
        return nativeAdUnitId;
      case placementDiariesBanner:
      case placementVehicleInline:
      default:
        return bannerAdUnitId;
    }
  }
}
