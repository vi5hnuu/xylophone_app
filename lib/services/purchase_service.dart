import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-off outcome of a purchase / restore, shown inline on the Pro sheet.
enum PurchaseNotice {
  purchased,
  restored,
  nothingToRestore,
  pending,
  failed,
  verifyFailed,
  storeUnavailable,
}

/// Handles the one-time "Xylophone Pro" purchase (no ads, all songs, saving).
///
/// Pro is a non-consumable product. Google Play is the source of truth; the
/// entitlement is cached locally so Pro works instantly and offline, and is
/// re-checked against Play on every launch (and on resume, throttled):
///   * purchases are only granted once Play reports them as *purchased* (cash /
///     "pending" payments wait until they clear),
///   * every purchase's signature is verified against the Play licence key, so
///     forged purchases from patched billing apps are rejected,
///   * purchases are acknowledged only after they're verified (unacknowledged
///     purchases are auto-refunded by Play after 3 days),
///   * a refunded / revoked purchase removes Pro — but only after Play reports
///     it missing on two separate app launches, so a flaky Play cache can't
///     strip a paying user of Pro,
///   * if Play can't be reached (offline), the cached entitlement is kept.
class PurchaseService extends ChangeNotifier with WidgetsBindingObserver {
  /// Configure this to match the product in the Play Console / App Store
  /// Connect.
  static const String proProductId = 'xylophone_pro';

  /// Base64 RSA licence key from Play Console → Monetize with Play →
  /// Monetization setup → Licensing. Used to verify purchase signatures. It is
  /// a public key, so it's safe to ship in the app. When empty, signature
  /// verification is skipped (purchases are still checked for package/product
  /// and purchase state).
  static const String playLicenseKey =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0LbeOHL/nq49CvXHIXuCEPbwSm1/'
      'uMBHZz+FpjlqmsVk1+TvjZr4GJYL9euzs/spwqmaRyR2eyypQ/U02OOTT6HbWiWWD605LqBv'
      '4o2E41UUjhfZT9u/WVbqKYJxZthBb3GZMq+dOoHEhErEnt/lqLeCtOmMICOfj7I6kWhfCReE'
      'sZ+O8RaNNprLooPQqN6V1Mq88AKZtcAfSwut9+Wi7mIdCSasLBgBxCZhDr+bOa4uDxJysGez'
      'xbQhd+KUVMlttx4VUaK2iMWbtHvpV9VQkNt+Rqfl5Bi8jUdDZlIAeyRcYGNQZAKvpld1zkQz'
      '8Dp7gLFqAptduOf93IvVOJg+7QIDAQAB';

  static const String _packageName = 'com.vi5hnu.xylophone';
  static const String _prefKey = 'is_pro';
  static const String _missKey = 'pro_miss_count';
  static const int _missesBeforeRevoke = 2;
  static const Duration _resyncInterval = Duration(minutes: 5);
  static const MethodChannel _channel = MethodChannel('xylophone/billing');

  final InAppPurchase _iap = InAppPurchase.instance;
  final SharedPreferences _prefs;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Reads the cached entitlement synchronously, so Pro users never see (or
  /// request) an ad while billing is still connecting at startup.
  PurchaseService(this._prefs) : _isPro = _prefs.getBool(_prefKey) ?? false;

  bool _isPro;
  bool _available = false;
  bool _flowActive = false;
  bool _paymentPending = false;
  Future<void>? _connecting;
  bool _restoring = false;
  PurchaseNotice? _notice;
  ProductDetails? _product;
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);
  bool _missCountedThisLaunch = false;
  Timer? _flowWatchdog;

  bool get isPro => _isPro;
  bool get storeAvailable => _available;

  /// True while the Play purchase sheet is open / being processed.
  bool get purchasePending => _flowActive;

  /// True when Play holds a purchase awaiting payment (e.g. cash at a store).
  bool get paymentPending => _paymentPending;
  bool get restoring => _restoring;
  ProductDetails? get product => _product;
  PurchaseNotice? get notice => _notice;

  /// Localised price from the store (e.g. "₹49.00"), or null if not loaded —
  /// never a guessed currency.
  String? get priceLabel => _product?.price;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _connect();
  }

  /// Retry the store connection / product query (e.g. when the Pro sheet is
  /// opened after the app started offline), and re-check a pending payment
  /// that may have cleared or lapsed since.
  Future<void> refresh() async {
    if (_available && _product != null && !_paymentPending) return;
    await _connect();
  }

  /// Concurrent callers share the in-flight attempt.
  Future<void> _connect() => _connecting ??= _doConnect();

  Future<void> _doConnect() async {
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      _sub ??= _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (Object e) => debugPrint('Xylophone: purchase stream: $e'),
      );
      if (_product == null) {
        final response = await _iap.queryProductDetails({proProductId});
        if (response.productDetails.isNotEmpty) {
          _product = response.productDetails.first;
        }
      }
      await _syncOwnership();
    } catch (e) {
      debugPrint('Xylophone: billing connect failed: $e');
    } finally {
      _connecting = null;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The Play sheet always reports back through the purchase stream; if it
    // somehow doesn't, never leave the buy button spinning forever.
    if (_flowActive) {
      _flowWatchdog?.cancel();
      _flowWatchdog = Timer(const Duration(seconds: 8), () {
        if (!_flowActive) return;
        _flowActive = false;
        notifyListeners();
        _syncOwnership();
      });
    }
    if (DateTime.now().difference(_lastSync) > _resyncInterval) {
      _connect();
    }
  }

  Future<void> buyPro() async {
    if (_isPro || !_available || _product == null || _flowActive) return;
    if (_paymentPending) {
      _notice = PurchaseNotice.pending;
      notifyListeners();
      return;
    }
    _flowActive = true;
    _notice = null;
    notifyListeners();
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!),
      );
      if (!started) {
        _flowActive = false;
        _notice = PurchaseNotice.failed;
      }
    } catch (e) {
      // Most commonly "item already owned" (bought on another device, or a
      // purchase interrupted earlier) — re-check ownership instead of failing.
      _flowActive = false;
      final owned = await _syncOwnership();
      _notice = owned == true ? PurchaseNotice.restored : PurchaseNotice.failed;
    }
    notifyListeners();
  }

  /// User-initiated restore with explicit feedback.
  Future<void> restore() async {
    if (_restoring) return;
    _restoring = true;
    _notice = null;
    notifyListeners();
    if (!_available) await _connect();
    final owned = await _syncOwnership();
    _restoring = false;
    // App Store restores report back through the purchase stream instead.
    if (!Platform.isAndroid) {
      notifyListeners();
      return;
    }
    _notice = switch (owned) {
      true => PurchaseNotice.restored,
      false when _paymentPending => PurchaseNotice.pending,
      false => PurchaseNotice.nothingToRestore,
      null => PurchaseNotice.storeUnavailable,
    };
    notifyListeners();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  /// Asks Play which purchases this account currently owns and reconciles the
  /// cached entitlement. Returns whether Pro is owned, or null if Play couldn't
  /// be asked (keep the cache).
  Future<bool?> _syncOwnership() async {
    if (!_available) return null;
    if (!Platform.isAndroid) {
      // App Store: owned purchases arrive on the purchase stream as restored.
      await _iap.restorePurchases();
      return null;
    }
    try {
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) return null;
      _lastSync = DateTime.now();

      var owned = false;
      var pending = false;
      for (final p in response.pastPurchases) {
        if (p.productID != proProductId) continue;
        if (p.status == PurchaseStatus.pending) {
          pending = true;
        } else if (p.status == PurchaseStatus.purchased && await _verify(p)) {
          owned = true;
          if (p.pendingCompletePurchase) await _complete(p);
        }
      }
      _paymentPending = pending && !owned;

      if (owned) {
        await _prefs.remove(_missKey);
        await _setPro(true);
      } else if (_isPro) {
        // Refunded, revoked, or a different Play account. Revoke only once
        // checks on two separate launches agree, so a transient empty answer
        // from Play can't take Pro away from a paying user.
        if (!_missCountedThisLaunch) {
          _missCountedThisLaunch = true;
          final misses = (_prefs.getInt(_missKey) ?? 0) + 1;
          if (misses >= _missesBeforeRevoke) {
            await _prefs.remove(_missKey);
            await _setPro(false);
          } else {
            await _prefs.setInt(_missKey, misses);
          }
        }
      }
      notifyListeners();
      return owned;
    } catch (e) {
      debugPrint('Xylophone: ownership check failed: $e');
      return null;
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != proProductId) continue;
      var acknowledge = p.pendingCompletePurchase;

      switch (p.status) {
        case PurchaseStatus.pending:
          _paymentPending = true;
          _flowActive = false;
          _notice = PurchaseNotice.pending;
          acknowledge = false; // can't complete until payment clears
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (!await _verify(p)) {
            // Never grant or acknowledge a purchase that fails verification.
            acknowledge = false;
            if (_flowActive) _notice = PurchaseNotice.verifyFailed;
            _flowActive = false;
            break;
          }
          await _prefs.remove(_missKey);
          await _setPro(true);
          _paymentPending = false;
          if (_flowActive || p.status == PurchaseStatus.purchased) {
            _notice = p.status == PurchaseStatus.restored
                ? PurchaseNotice.restored
                : PurchaseNotice.purchased;
          }
          _flowActive = false;
          break;
        case PurchaseStatus.error:
          final wasActive = _flowActive;
          _flowActive = false;
          final owned = await _syncOwnership();
          if (wasActive) {
            _notice = owned == true
                ? PurchaseNotice.restored
                : PurchaseNotice.failed;
          }
          break;
        case PurchaseStatus.canceled:
          _flowActive = false;
          break;
      }

      if (acknowledge) await _complete(p);
    }
    notifyListeners();
  }

  Future<void> _complete(PurchaseDetails p) async {
    try {
      await _iap.completePurchase(p);
    } catch (e) {
      debugPrint('Xylophone: completePurchase failed: $e');
    }
  }

  /// Validates a Play purchase: right app, right product, and (when the
  /// licence key is configured) a genuine Google Play signature.
  Future<bool> _verify(PurchaseDetails p) async {
    if (p is! GooglePlayPurchaseDetails) return true; // App Store path
    final purchase = p.billingClientPurchase;
    try {
      final json = jsonDecode(purchase.originalJson) as Map<String, dynamic>;
      if (json['packageName'] != _packageName) return false;
      final ids = <Object?>[
        json['productId'],
        ...(json['productIds'] as List<Object?>? ?? const []),
      ];
      if (!ids.contains(proProductId)) return false;
    } catch (_) {
      return false;
    }
    if (playLicenseKey.isEmpty) {
      debugPrint('Xylophone: playLicenseKey not set — signature unchecked');
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('verifyPurchase', {
            'publicKey': playLicenseKey,
            'signedData': purchase.originalJson,
            'signature': purchase.signature,
          }) ??
          false;
    } catch (e) {
      debugPrint('Xylophone: signature check failed: $e');
      return false;
    }
  }

  Future<void> _setPro(bool value) async {
    if (_isPro == value) return;
    _isPro = value;
    await _prefs.setBool(_prefKey, value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flowWatchdog?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
