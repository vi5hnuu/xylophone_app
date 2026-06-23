import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Initialises Google Mobile Ads (AdMob) with a **child-safe** configuration and
/// holds the ad unit ids.
///
/// Xylophone is aimed at young children, so every ad request is:
///   * tagged child-directed (TFCD = yes) and under age of consent (TFUA = yes),
///   * capped at the "G" (everyone) content rating, and
///   * non-personalised.
///
/// NOTE: the unit ids below are the real (production) ids. While developing,
/// either test on a registered test device or avoid tapping live ads, to stay
/// within AdMob policy.
class AdsService {
  static bool _initialised = false;

  // ── Real AdMob ad unit ids (Android) ───────────────────────────────────────
  static const String androidBanner =
      'ca-app-pub-4715945578201106/4319664749';
  static const String androidAppOpen =
      'ca-app-pub-4715945578201106/3667938372';
  static const String androidInterstitial =
      'ca-app-pub-4715945578201106/1313237770';

  // ── iOS test units (no iOS ids were provided; replace before iOS release) ───
  static const String _iosBannerTest = 'ca-app-pub-3940256099942544/2934735716';
  static const String _iosAppOpenTest =
      'ca-app-pub-3940256099942544/5575463023';
  static const String _iosInterstitialTest =
      'ca-app-pub-3940256099942544/4411468910';

  static String get bannerAdUnitId =>
      Platform.isIOS ? _iosBannerTest : androidBanner;
  static String get appOpenAdUnitId =>
      Platform.isIOS ? _iosAppOpenTest : androidAppOpen;
  static String get interstitialAdUnitId =>
      Platform.isIOS ? _iosInterstitialTest : androidInterstitial;

  static Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );
    await MobileAds.instance.initialize();
  }

  /// All ad requests are non-personalised, as required for a kids app.
  static AdRequest request() => const AdRequest(nonPersonalizedAds: true);
}
