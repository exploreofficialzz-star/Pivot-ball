import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'storage_manager.dart';

class PurchaseManager {
  static final PurchaseManager _instance = PurchaseManager._internal();
  static PurchaseManager get instance => _instance;
  PurchaseManager._internal();

  // ── Product IDs — must match exactly what you create in Play Console / App Store Connect
  static const String removeAdsId = 'pivot_ball_remove_ads';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available    = false;
  bool _adsRemoved   = false;
  bool _loading      = false;
  List<ProductDetails> _products = [];

  // Notifier so UI rebuilds when purchase completes
  final ValueNotifier<bool> adsRemovedNotifier = ValueNotifier(false);

  bool get adsRemoved    => _adsRemoved;
  bool get storeAvailable => _available;
  bool get loading        => _loading;
  List<ProductDetails> get products => _products;

  // =========================================================================
  // INIT
  // =========================================================================
  Future<void> initialize() async {
    // Restore saved purchase state first
    _adsRemoved = StorageManager.instance.getAdsRemoved();
    adsRemovedNotifier.value = _adsRemoved;

    _available = await _iap.isAvailable();
    if (!_available) return;

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );

    // Load product details from store
    await _loadProducts();

    // Silently restore previous purchases (e.g. after reinstall)
    await _iap.restorePurchases();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails({removeAdsId});
      _products = response.productDetails;
    } catch (_) {}
  }

  // =========================================================================
  // PURCHASE FLOW
  // =========================================================================
  Future<void> buyRemoveAds() async {
    if (!_available || _loading) return;
    final product = _products.firstWhere(
      (p) => p.id == removeAdsId,
      orElse: () => throw Exception('Product not found — check Play Console / App Store'),
    );
    _loading = true;
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      _loading = false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  // =========================================================================
  // PURCHASE HANDLER
  // =========================================================================
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grant(purchase);
          break;
        case PurchaseStatus.error:
          _loading = false;
          break;
        case PurchaseStatus.canceled:
          _loading = false;
          break;
        case PurchaseStatus.pending:
          break;
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    _loading = false;
  }

  Future<void> _grant(PurchaseDetails purchase) async {
    if (purchase.productID == removeAdsId) {
      _adsRemoved = true;
      adsRemovedNotifier.value = true;
      await StorageManager.instance.saveAdsRemoved(true);
    }
  }

  void dispose() {
    _subscription?.cancel();
    adsRemovedNotifier.dispose();
  }
}
