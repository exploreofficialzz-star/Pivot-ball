import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'storage_manager.dart';

class PurchaseManager {
  static final PurchaseManager _instance = PurchaseManager._internal();
  static PurchaseManager get instance => _instance;
  PurchaseManager._internal();

  // ── Product IDs — must match exactly what you create in Play Console / App Store Connect
  static const String monthlySkipId  = 'pivot_ball_monthly_skip'; // \$8.99 — 30 days ad-free
  static const String weeklySkipId   = 'pivot_ball_weekly_skip'; // \$2.99 — 7 days ad-free
  static const String dailySkipId    = 'pivot_ball_daily_skip'; // $0.99 consumable

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available    = false;
  bool _loading      = false;
  List<ProductDetails> _products = [];

  // Notifiers
  final ValueNotifier<bool> monthlySkipNotifier = ValueNotifier(false);
  final ValueNotifier<bool> weeklySkipNotifier  = ValueNotifier(false);
  final ValueNotifier<bool> dailySkipNotifier   = ValueNotifier(false);

  bool get adsRemoved    => isMonthlySkipActive() || isWeeklySkipActive() || isDailySkipActive();
  bool get storeAvailable => _available;
  bool get loading        => _loading;
  List<ProductDetails> get products => _products;

  // =========================================================================
  // INIT
  // =========================================================================
  Future<void> initialize() async {
    // Restore saved purchase state first
    monthlySkipNotifier.value = isMonthlySkipActive();
    weeklySkipNotifier.value  = isWeeklySkipActive();
    dailySkipNotifier.value   = isDailySkipActive();

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
      final response = await _iap.queryProductDetails({monthlySkipId, weeklySkipId, dailySkipId});
      _products = response.productDetails;
    } catch (_) {}
  }

  // =========================================================================
  // PURCHASE FLOW
  // =========================================================================
  // Legacy — kept for any external calls; now both products are consumables
  Future<void> buyRemoveAds() => buyWeeklySkip();

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
    if (purchase.productID == monthlySkipId) {
      await StorageManager.instance.saveMonthlySkipTime();
      monthlySkipNotifier.value = true;
    }
    if (purchase.productID == weeklySkipId) {
      await StorageManager.instance.saveWeeklySkipTime();
      weeklySkipNotifier.value = true;
    }
    if (purchase.productID == dailySkipId) {
      // Consumable — save purchase timestamp, expires in 24 hours
      await StorageManager.instance.saveDailySkipTime();
      dailySkipNotifier.value = true;
    }
  }

  bool isMonthlySkipActive() {
    final bought = StorageManager.instance.getMonthlySkipTime();
    if (bought == null) return false;
    return DateTime.now().difference(bought).inDays < 30;
  }

  Duration get monthlySkipRemaining {
    final bought = StorageManager.instance.getMonthlySkipTime();
    if (bought == null) return Duration.zero;
    final remaining = const Duration(days: 30) - DateTime.now().difference(bought);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> buyMonthlySkip() async {
    if (!_available || _loading) return;
    final ProductDetails? product = _products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == monthlySkipId, orElse: () => null);
    if (product == null) return;
    _loading = true;
    try {
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (_) { _loading = false; }
  }

  bool isWeeklySkipActive() {
    final bought = StorageManager.instance.getWeeklySkipTime();
    if (bought == null) return false;
    return DateTime.now().difference(bought).inDays < 7;
  }

  Duration get weeklySkipRemaining {
    final bought = StorageManager.instance.getWeeklySkipTime();
    if (bought == null) return Duration.zero;
    final remaining = const Duration(days: 7) - DateTime.now().difference(bought);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> buyWeeklySkip() async {
    if (!_available || _loading) return;
    final ProductDetails? product = _products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == weeklySkipId, orElse: () => null);
    if (product == null) return;
    _loading = true;
    try {
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (_) { _loading = false; }
  }

  // Returns true if user bought a daily skip less than 24 hours ago
  bool isDailySkipActive() {
    final bought = StorageManager.instance.getDailySkipTime();
    if (bought == null) return false;
    return DateTime.now().difference(bought).inHours < 24;
  }

  Duration get dailySkipRemaining {
    final bought = StorageManager.instance.getDailySkipTime();
    if (bought == null) return Duration.zero;
    final elapsed = DateTime.now().difference(bought);
    final remaining = const Duration(hours: 24) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> buyDailySkip() async {
    if (!_available || _loading) return;
    final ProductDetails? product = _products.cast<ProductDetails?>().firstWhere(
      (p) => p?.id == dailySkipId, orElse: () => null);
    if (product == null) return;
    _loading = true;
    try {
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (_) {
      _loading = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    monthlySkipNotifier.dispose();
    weeklySkipNotifier.dispose();
    dailySkipNotifier.dispose();
  }
}
