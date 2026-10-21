import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../services/ad_manager.dart';
import '../services/ads_service.dart';

/// A compact 320×50 banner. A fixed standard size (rather than the *large*
/// adaptive size) keeps the ad tight to its creative, with no empty padding
/// above/below it. Renders nothing until loaded, and collapses on failure. Only
/// mount this when ads are on. A small "AD" label keeps it clearly marked as
/// an ad (Families policy).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      adUnitId: AdsService.bannerAdUnitId,
      size: AdSize.banner, // 320 × 50
      request: AdsService.request(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
          if (mounted) setState(() => _loaded = false);
        },
        // A click opens the advertiser outside the app; coming back from it
        // must not trigger an app-open ad.
        onAdClicked: (_) {
          if (mounted) context.read<AdManager>().suppressAppOpenOnce();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    final width = ad.size.width.toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('AD',
                style: AppTheme.nunitoLabel(
                    size: 9,
                    weight: FontWeight.w800,
                    color: AppTheme.hint,
                    spacing: 1)),
          ),
        ),
        SizedBox(
          width: width,
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ],
    );
  }
}
