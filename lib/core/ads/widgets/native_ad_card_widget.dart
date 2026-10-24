import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../admob_config.dart';

/// Reusable Google AdMob Native Card Widget.
///
/// Designed to blend naturally with Magic Diary's card architecture:
/// matches elevation, shape, border styling, and typography.
class NativeAdCardWidget extends StatefulWidget {
  final String placement;
  final EdgeInsetsGeometry? margin;

  const NativeAdCardWidget({
    super.key,
    required this.placement,
    this.margin,
  });

  @override
  State<NativeAdCardWidget> createState() => _NativeAdCardWidgetState();
}

class _NativeAdCardWidgetState extends State<NativeAdCardWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    if (!AdMobConfig.isPlatformSupported || !AdMobConfig.globalAdsEnabled) return;

    final adUnitId = AdMobConfig.getAdUnitIdForPlacement(widget.placement);

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'magicDiaryNativeAdFactory',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('[AdMob] Native ad failed to load (${widget.placement}): $error');
          }
          ad.dispose();
          if (mounted) setState(() => _isAdLoaded = false);
        },
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdMobConfig.globalAdsEnabled) return const SizedBox.shrink();

    // 1. When native ad is loaded via mobile factory
    if (_isAdLoaded && _nativeAd != null) {
      return Container(
        margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
        height: 120,
        child: AdWidget(ad: _nativeAd!),
      );
    }

    // 2. Styled Native Ad Card (Official test preview & fallback)
    if (AdMobConfig.isTesting) {
      return Card(
        margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blueGrey.shade100, width: 1),
        ),
        color: Colors.blueGrey.shade50.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Ad',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sponsored • Google AdMob Test',
                    style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(Icons.info_outline, size: 14, color: Colors.blueGrey.shade400),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    radius: 20,
                    child: Icon(Icons.star_outline, color: Colors.teal.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Your Finances & Assets Smartly',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Reliable financial tools, insurance calculators & life planning.',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: Colors.teal.shade700,
                    ),
                    child: const Text('Learn More', style: TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
