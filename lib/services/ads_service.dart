import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Initialises Google Mobile Ads (AdMob) with a **child-safe** configuration and
/// holds the ad unit ids.
///
/// Xylophone is aimed at young children, so every ad request is:
///   * tagged child-directed (TFCD = yes) and under age of consent (TFUA = yes),
///   * capped at the "G" (everyone) content rating, and
///   * non-personalised.
///
/// Release builds use the real (production) unit ids. Debug/profile builds use
/// Google's public test units, so testing on a device can never generate
/// invalid traffic on the real AdMob account.
class AdsService {
  static bool _initialised = false;

  // ── Real AdMob ad unit ids (Android) ───────────────────────────────────────
  static const String androidBanner =
      'ca-app-pub-4715945578201106/4319664749';
  static const String androidAppOpen =
      'ca-app-pub-4715945578201106/3667938372';
  static const String androidInterstitial =
      'ca-app-pub-4715945578201106/1313237770';
  static const String androidRewarded =
      'ca-app-pub-4715945578201106/5758299456';

  // ── Google test units ───────────────────────────────────────────────────────
  static const String _androidBannerTest =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _androidAppOpenTest =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _androidInterstitialTest =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _androidRewardedTest =
      'ca-app-pub-3940256099942544/5224354917';
  // iOS: no iOS ids were provided; replace before an iOS release.
  static const String _iosBannerTest = 'ca-app-pub-3940256099942544/2934735716';
  static const String _iosAppOpenTest =
      'ca-app-pub-3940256099942544/5575463023';
  static const String _iosInterstitialTest =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _iosRewardedTest =
      'ca-app-pub-3940256099942544/1712485313';

  static String _pick(String real, String androidTest, String iosTest) {
    if (Platform.isIOS) return iosTest;
    return kReleaseMode ? real : androidTest;
  }

  static String get bannerAdUnitId =>
      _pick(androidBanner, _androidBannerTest, _iosBannerTest);
  static String get appOpenAdUnitId =>
      _pick(androidAppOpen, _androidAppOpenTest, _iosAppOpenTest);
  static String get interstitialAdUnitId => _pick(
      androidInterstitial, _androidInterstitialTest, _iosInterstitialTest);
  static String get rewardedAdUnitId =>
      _pick(androidRewarded, _androidRewardedTest, _iosRewardedTest);

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
