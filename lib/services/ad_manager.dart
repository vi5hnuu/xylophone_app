import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_service.dart';
import 'purchase_service.dart';

/// Manages the full-screen ad formats (app-open + interstitial) for free users.
///
/// Kept deliberately gentle for a kids app:
///   * App-open ads show only when returning from the background (never on the
///     very first cold start, so children aren't greeted by a full-screen ad),
///     and at most once per [_appOpenCooldown].
///   * Interstitials show only at a natural break (when the Settings sheet is
///     closed) and at most once per [_interstitialCooldown].
///   * Nothing ever shows for Pro users.
class AdManager with WidgetsBindingObserver {
  final PurchaseService purchases;
  AdManager(this.purchases);

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitial;
  bool _showingAd = false;
  bool _started = false;
  bool _sawFirstResume = false;
  DateTime _lastAppOpen = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastInterstitial = DateTime.fromMillisecondsSinceEpoch(0);

  static const _appOpenCooldown = Duration(seconds: 30);
  static const _interstitialCooldown = Duration(minutes: 2);

  bool get _pro => purchases.isPro;

  /// Call after MobileAds has initialised.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _loadAppOpen();
    _loadInterstitial();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appOpenAd?.dispose();
    _interstitial?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_sawFirstResume) {
      _sawFirstResume = true; // skip the cold-start resume
      return;
    }
    _showAppOpenIfAvailable();
  }

  // ── App-open ───────────────────────────────────────────────────────────────
  void _loadAppOpen() {
    if (_pro) return;
    AppOpenAd.load(
      adUnitId: AdsService.appOpenAdUnitId,
      request: AdsService.request(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (_) => _appOpenAd = null,
      ),
    );
  }

  void _showAppOpenIfAvailable() {
    if (_pro || _showingAd) return;
    if (DateTime.now().difference(_lastAppOpen) < _appOpenCooldown) return;
    final ad = _appOpenAd;
    if (ad == null) {
      _loadAppOpen();
      return;
    }
    _appOpenAd = null;
    _showingAd = true;
    _lastAppOpen = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showingAd = false;
        ad.dispose();
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showingAd = false;
        ad.dispose();
        _loadAppOpen();
      },
    );
    ad.show();
  }

  // ── Interstitial ─────────────────────────────────────────────────────────────
  void _loadInterstitial() {
    if (_pro) return;
    InterstitialAd.load(
      adUnitId: AdsService.interstitialAdUnitId,
      request: AdsService.request(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Show an interstitial at a natural break, at most once per cooldown.
  void maybeShowInterstitial() {
    if (_pro || _showingAd) return;
    if (DateTime.now().difference(_lastInterstitial) < _interstitialCooldown) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _showingAd = true;
    _lastInterstitial = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _showingAd = false;
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showingAd = false;
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }
}
