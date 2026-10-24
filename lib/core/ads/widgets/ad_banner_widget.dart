import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../admob_config.dart';

/// Reusable Google AdMob Banner Widget.
///
/// Automatically loads mobile banners on Android & iOS,
/// and provides a graceful, compliant fallback/test preview on desktop/web/debug environments.
class AdBannerWidget extends StatefulWidget {
  final String placement;
  final AdSize adSize;
  final EdgeInsetsGeometry? margin;

  const AdBannerWidget({
    super.key,
    this.placement = AdMobConfig.placementDiariesBanner,
    this.adSize = AdSize.banner,
    this.margin,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (!AdMobConfig.isPlatformSupported || !AdMobConfig.globalAdsEnabled) return;

    final adUnitId = AdMobConfig.getAdUnitIdForPlacement(widget.placement);

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('[AdMob] Banner failed to load (${widget.placement}): $error');
          }
          ad.dispose();
          if (mounted) setState(() => _isAdLoaded = false);
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdMobConfig.globalAdsEnabled) return const SizedBox.shrink();

    final width = widget.adSize.width.toDouble();
    final height = widget.adSize.height.toDouble();

    // 1. Real Native Mobile Ad Loaded
    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        width: width,
        height: height,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // 2. Debug / Non-mobile / Test Placeholder (Keeps layout consistent and testable)
    if (AdMobConfig.isTesting) {
      return Container(
        margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          width: width > 0 ? width : double.infinity,
          height: height > 0 ? height : 50,
          constraints: const BoxConstraints(maxWidth: 468, minHeight: 50),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Ad',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Google AdMob Test Banner • ${widget.placement}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
