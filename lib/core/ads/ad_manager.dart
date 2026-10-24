import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'admob_config.dart';

/// Centralized service to manage AdMob lifecycle: initialization, interstitial ads,
/// and rewarded ads with built-in frequency capping.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  DateTime? _lastInterstitialShownAt;

  /// Minimum duration between consecutive interstitial ads (prevents user spam).
  static const Duration minInterstitialInterval = Duration(minutes: 5);

  /// Initializes the Google Mobile Ads SDK. Safe to call on any platform.
  Future<void> initialize() async {
    if (!AdMobConfig.isPlatformSupported || !AdMobConfig.globalAdsEnabled) {
      if (kDebugMode) {
        debugPrint('[AdMob] Skipping MobileAds init: unsupported platform or ads disabled.');
      }
      return;
    }

    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      if (AdMobConfig.isTesting) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: <String>[]),
        );
        if (kDebugMode) {
          debugPrint('[AdMob] Google Mobile Ads initialized in DEBUG mode (Test Ads enforced).');
        }
      } else {
        if (kDebugMode) {
          debugPrint('[AdMob] Google Mobile Ads initialized in RELEASE mode (Production Ads active).');
        }
      }
      loadInterstitialAd();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdMob] Error initializing MobileAds: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Interstitial Ads Management
  // ---------------------------------------------------------------------------
  void loadInterstitialAd() {
    if (!_isInitialized || !AdMobConfig.isPlatformSupported || !AdMobConfig.globalAdsEnabled) return;

    InterstitialAd.load(
      adUnitId: AdMobConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          if (kDebugMode) debugPrint('[AdMob] Interstitial ad loaded.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          if (kDebugMode) debugPrint('[AdMob] Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Displays an interstitial ad if ready and frequency cap allows.
  /// Ideal for natural transition points (e.g. after successfully logging a payment).
  void showInterstitialAd({VoidCallback? onDismissed}) {
    if (_interstitialAd == null) {
      loadInterstitialAd();
      onDismissed?.call();
      return;
    }

    // Enforce frequency capping
    final now = DateTime.now();
    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!) < minInterstitialInterval) {
      if (kDebugMode) {
        debugPrint('[AdMob] Interstitial skipped due to frequency capping.');
      }
      onDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialShownAt = DateTime.now();
        loadInterstitialAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onDismissed?.call();
      },
    );

    _interstitialAd!.show();
  }

  // ---------------------------------------------------------------------------
  // Rewarded Ads Management
  // ---------------------------------------------------------------------------
  void loadRewardedAd({VoidCallback? onLoaded}) {
    if (!_isInitialized || !AdMobConfig.isPlatformSupported || !AdMobConfig.globalAdsEnabled) return;

    RewardedAd.load(
      adUnitId: AdMobConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          onLoaded?.call();
          if (kDebugMode) debugPrint('[AdMob] Rewarded ad loaded.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          if (kDebugMode) debugPrint('[AdMob] Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  /// Shows a rewarded ad. Triggers [onUserEarnedReward] when reward is granted.
  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    if (_rewardedAd == null) {
      loadRewardedAd();
      onDismissed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onDismissed?.call();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      onUserEarnedReward(reward);
    });
  }
}
