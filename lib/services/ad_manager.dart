import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_free_pass.dart';
import 'ads_service.dart';
import 'purchase_service.dart';

/// Manages the full-screen ad formats (app-open, interstitial, rewarded).
///
/// Kept deliberately gentle for a kids app:
///   * App-open ads show only when the app returns after really being in the
///     background for a while — never on cold start, and never after the
///     notification shade, the Play billing sheet, the share sheet, a browser
///     the app opened, or another ad.
///   * Interstitials show only at a natural break (after a finished song), not
///     in the first minutes of a session, and at most once per cooldown.
///   * At least [_fullScreenGap] separates any two full-screen ads.
///   * Nothing shows for Pro users, or while an earned ad-free pass is active.
///
/// Rewarded ads grant [AdFreePass.reward] of ad-free play. The reward is given
/// only when the SDK reports both a recorded impression *and* an earned reward
/// — closing the video early, a failed show, or watching a cached video while
/// offline earns nothing.
class AdManager extends ChangeNotifier with WidgetsBindingObserver {
  final PurchaseService purchases;
  final AdFreePass pass;

  AdManager(this.purchases, this.pass) {
    purchases.addListener(_onEntitlementChanged);
    pass.addListener(_onEntitlementChanged);
  }

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  final Map<String, DateTime> _loadedAt = {};
  final Set<String> _loading = {};
  final Map<String, int> _failures = {};

  bool _started = false;
  bool _showingAd = false;
  bool _suppressNextResume = false;
  DateTime? _backgroundedAt;
  final DateTime _sessionStart = DateTime.now();
  DateTime _lastFullScreen = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAppOpen = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastInterstitial = DateTime.fromMillisecondsSinceEpoch(0);

  static const _appOpenCooldown = Duration(minutes: 4);
  static const _interstitialCooldown = Duration(minutes: 3);
  static const _fullScreenGap = Duration(seconds: 90);
  static const _sessionGrace = Duration(minutes: 2);
  static const _minBackground = Duration(seconds: 30);
  // Ads go stale: app-open after 4h, others after 1h (Google guidance).
  static const _appOpenMaxAge = Duration(hours: 4);
  static const _fullScreenMaxAge = Duration(minutes: 55);

  static const _kAppOpen = 'appOpen';
  static const _kInterstitial = 'interstitial';
  static const _kRewarded = 'rewarded';

  /// No ads at all: Pro, or an active ad-free pass.
  bool get adsOff => purchases.isPro || pass.active;

  /// A rewarded video is loaded and fresh, ready to offer.
  bool get rewardedReady =>
      !purchases.isPro && _rewarded != null && _fresh(_kRewarded);

  /// Call after MobileAds has initialised.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _preload();
  }

  /// Call right before the app itself opens another screen (Play billing,
  /// share sheet, browser, mail) so returning from it doesn't trigger an
  /// app-open ad.
  void suppressAppOpenOnce() => _suppressNextResume = true;

  @override
  void dispose() {
    purchases.removeListener(_onEntitlementChanged);
    pass.removeListener(_onEntitlementChanged);
    WidgetsBinding.instance.removeObserver(this);
    _disposeAll();
    super.dispose();
  }

  void _onEntitlementChanged() {
    if (purchases.isPro) {
      _disposeAll();
    } else if (_started) {
      _preload();
    }
    notifyListeners();
  }

  void _disposeAll() {
    _appOpenAd?.dispose();
    _interstitial?.dispose();
    _rewarded?.dispose();
    _appOpenAd = null;
    _interstitial = null;
    _rewarded = null;
    _loadedAt.clear();
  }

  void _preload() {
    if (purchases.isPro) return;
    _loadRewarded();
    if (pass.active) return;
    _loadAppOpen();
    _loadInterstitial();
  }

  bool _fresh(String key) {
    final at = _loadedAt[key];
    if (at == null) return false;
    final maxAge = key == _kAppOpen ? _appOpenMaxAge : _fullScreenMaxAge;
    return DateTime.now().difference(at) < maxAge;
  }

  bool _gapOk(DateTime last, Duration cooldown) {
    final now = DateTime.now();
    return !adsOff &&
        !_showingAd &&
        now.difference(_lastFullScreen) >= _fullScreenGap &&
        now.difference(last) >= cooldown;
  }

  /// Retry a failed load with exponential backoff (30s → 10min), so being
  /// offline doesn't hammer the ad server.
  void _onLoadFailed(String key, VoidCallback reload) {
    _loading.remove(key);
    final n = (_failures[key] ?? 0) + 1;
    _failures[key] = n;
    final delay = Duration(seconds: min(600, 30 * pow(2, n - 1).toInt()));
    Timer(delay, reload);
  }

  void _onLoaded(String key) {
    _loading.remove(key);
    _failures.remove(key);
    _loadedAt[key] = DateTime.now();
    notifyListeners();
  }

  // ── Lifecycle → app-open ─────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (_suppressNextResume || _showingAd) {
          _suppressNextResume = false;
          return;
        }
        // Only "inactive" (notification shade, system dialog) → no ad.
        if (since == null) return;
        if (DateTime.now().difference(since) < _minBackground) return;
        _showAppOpen();
        break;
      default:
        break;
    }
  }

  void _loadAppOpen() {
    if (adsOff || _loading.contains(_kAppOpen)) return;
    if (_appOpenAd != null && _fresh(_kAppOpen)) return;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _loading.add(_kAppOpen);
    AppOpenAd.load(
      adUnitId: AdsService.appOpenAdUnitId,
      request: AdsService.request(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _onLoaded(_kAppOpen);
        },
        onAdFailedToLoad: (_) => _onLoadFailed(_kAppOpen, _loadAppOpen),
      ),
    );
  }

  void _showAppOpen() {
    if (!_gapOk(_lastAppOpen, _appOpenCooldown)) return;
    final ad = _appOpenAd;
    if (ad == null || !_fresh(_kAppOpen)) {
      _loadAppOpen();
      return;
    }
    _appOpenAd = null;
    _lastAppOpen = DateTime.now();
    ad.fullScreenContentCallback = _fullScreen<AppOpenAd>(_loadAppOpen);
    ad.show();
  }

  // ── Interstitial ─────────────────────────────────────────────────────────
  void _loadInterstitial() {
    if (adsOff || _loading.contains(_kInterstitial)) return;
    if (_interstitial != null && _fresh(_kInterstitial)) return;
    _interstitial?.dispose();
    _interstitial = null;
    _loading.add(_kInterstitial);
    InterstitialAd.load(
      adUnitId: AdsService.interstitialAdUnitId,
      request: AdsService.request(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _onLoaded(_kInterstitial);
        },
        onAdFailedToLoad: (_) =>
            _onLoadFailed(_kInterstitial, _loadInterstitial),
      ),
    );
  }

  /// A natural break (e.g. a song was just finished and the child tapped on):
  /// maybe show an interstitial, within all the limits above.
  void onNaturalBreak() {
    if (DateTime.now().difference(_sessionStart) < _sessionGrace) return;
    if (!_gapOk(_lastInterstitial, _interstitialCooldown)) return;
    final ad = _interstitial;
    if (ad == null || !_fresh(_kInterstitial)) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _lastInterstitial = DateTime.now();
    ad.fullScreenContentCallback =
        _fullScreen<InterstitialAd>(_loadInterstitial);
    ad.show();
  }

  /// Marks a full-screen ad as showing and builds its lifecycle callback.
  FullScreenContentCallback<T> _fullScreen<T extends Ad>(VoidCallback reload) {
    _showingAd = true;
    _suppressNextResume = true; // the ad itself pauses the app
    _lastFullScreen = DateTime.now();
    return FullScreenContentCallback<T>(
      onAdDismissedFullScreenContent: (ad) {
        _showingAd = false;
        ad.dispose();
        reload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showingAd = false;
        _suppressNextResume = false;
        ad.dispose();
        reload();
      },
    );
  }

  // ── Rewarded (1 hour ad-free) ────────────────────────────────────────────
  void _loadRewarded() {
    if (purchases.isPro || _loading.contains(_kRewarded)) return;
    if (_rewarded != null && _fresh(_kRewarded)) return;
    _rewarded?.dispose();
    _rewarded = null;
    _loading.add(_kRewarded);
    RewardedAd.load(
      adUnitId: AdsService.rewardedAdUnitId,
      request: AdsService.request(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _onLoaded(_kRewarded);
        },
        onAdFailedToLoad: (_) => _onLoadFailed(_kRewarded, _loadRewarded),
      ),
    );
  }

  /// Shows the rewarded video. Completes with the outcome once it closes.
  Future<RewardOutcome> showRewarded() async {
    if (purchases.isPro) return RewardOutcome.notNeeded;
    if (_showingAd) return RewardOutcome.unavailable;
    final ad = _rewarded;
    if (ad == null || !_fresh(_kRewarded)) {
      _loadRewarded();
      return RewardOutcome.unavailable;
    }
    // A video cached earlier could play offline, where its impression can't be
    // counted. Require a live connection before showing it.
    if (!await _online()) return RewardOutcome.offline;

    _rewarded = null;
    _loadedAt.remove(_kRewarded);
    notifyListeners();

    final done = Completer<RewardOutcome>();
    var impression = false;
    var earned = false;
    var granted = false;
    void grantIfDue() {
      if (granted || !impression || !earned) return;
      granted = true;
      pass.grant();
    }

    _showingAd = true;
    _suppressNextResume = true;
    _lastFullScreen = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdImpression: (_) {
        impression = true;
        grantIfDue();
      },
      onAdDismissedFullScreenContent: (ad) {
        _showingAd = false;
        ad.dispose();
        grantIfDue();
        _loadRewarded();
        if (!done.isCompleted) {
          done.complete(
              granted ? RewardOutcome.earned : RewardOutcome.closedEarly);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        _showingAd = false;
        _suppressNextResume = false;
        ad.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(RewardOutcome.unavailable);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) {
      earned = true;
      grantIfDue();
    });
    return done.future;
  }

  Future<bool> _online() async {
    try {
      final result = await InternetAddress.lookup('googleads.g.doubleclick.net')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

enum RewardOutcome { earned, closedEarly, offline, unavailable, notNeeded }
