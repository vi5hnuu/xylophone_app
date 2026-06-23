import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles the one-time "Xylophone Pro" purchase that removes ads.
///
/// Pro is a non-consumable product. The entitlement is verified through Google
/// Play / the App Store and cached locally so the app knows it is Pro instantly
/// on the next launch (offline-friendly). Restoring purchases re-validates it.
class PurchaseService extends ChangeNotifier {
  /// Configure this to match the product you create in the Play Console /
  /// App Store Connect. Suggested price: ₹49 (one-time).
  static const String proProductId = 'xylophone_pro';
  static const String _prefKey = 'is_pro';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  SharedPreferences? _prefs;

  bool _isPro = false;
  bool _available = false;
  bool _purchasePending = false;
  ProductDetails? _product;

  bool get isPro => _isPro;
  bool get storeAvailable => _available;
  bool get purchasePending => _purchasePending;
  ProductDetails? get product => _product;

  /// Localised price string (e.g. "₹49.00"), or a sensible fallback.
  String get priceLabel => _product?.price ?? '₹49';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isPro = _prefs?.getBool(_prefKey) ?? false;
    notifyListeners();

    _available = await _iap.isAvailable();
    if (!_available) return;

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) {/* surfaced via UI state; ignore stream errors here */},
    );

    final response = await _iap.queryProductDetails({proProductId});
    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
    }
    notifyListeners();

    // Pull through any pending/owned purchases (e.g. after reinstall).
    await _iap.restorePurchases();
  }

  Future<void> buyPro() async {
    if (!_available || _product == null || _purchasePending) return;
    _purchasePending = true;
    notifyListeners();
    final param = PurchaseParam(productDetails: _product!);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != proProductId) continue;

      switch (p.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grantPro();
          _purchasePending = false;
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _purchasePending = false;
          break;
      }

      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    notifyListeners();
  }

  Future<void> _grantPro() async {
    if (_isPro) return;
    _isPro = true;
    await _prefs?.setBool(_prefKey, true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
