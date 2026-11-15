import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../app_info.dart';
import '../data/doc_store.dart';
import '../data/docs.dart';
import '../data/models.dart';

/// The one-time "Remove ads" purchase (Google Play Billing). Once bought,
/// banners and between-puzzles ads never show again on this install, and
/// "Restore purchase" brings it back after a reinstall or on a new phone.
/// Rewarded ads stay available because the player chooses them.
abstract class PurchaseService extends ChangeNotifier {
  Future<void> init();

  bool get adsRemoved;

  /// Whether Google Play billing is available and the product was found.
  bool get canBuy;

  /// Localised price from Google Play, e.g. "$2.99" (null until known).
  String? get price;

  /// A purchase or restore is in progress.
  bool get busy;

  /// Starts the Google Play purchase sheet. Returns false if it could not
  /// be started. The result arrives later through [adsRemoved].
  Future<bool> buyRemoveAds();

  /// Asks Google Play for earlier purchases.
  Future<void> restore();
}

class PlayPurchaseService extends PurchaseService {
  PlayPurchaseService(this._store)
    : _adsRemoved = _store.load(Docs.purchases).value?.adsRemoved ?? false;

  final DocStore _store;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _available = false;
  bool _adsRemoved;
  bool _busy = false;

  @override
  bool get adsRemoved => _adsRemoved;
  @override
  bool get canBuy => _available && _product != null && !_adsRemoved;
  @override
  String? get price => _product?.price;
  @override
  bool get busy => _busy;

  @override
  Future<void> init() async {
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('Purchase stream: $e'),
      );
      final r = await _iap.queryProductDetails({AppInfo.removeAdsProductId});
      if (r.productDetails.isNotEmpty) _product = r.productDetails.first;
      if (r.notFoundIDs.isNotEmpty) {
        debugPrint('Play product not found: ${r.notFoundIDs.join(', ')}');
      }
      // Quietly picks up an earlier purchase (reinstall, new phone).
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Billing unavailable: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != AppInfo.removeAdsProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _busy = true;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grant();
          _busy = false;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _busy = false;
      }
      if (p.pendingCompletePurchase) {
        try {
          // Acknowledges the purchase; Google refunds unacknowledged ones.
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('Could not complete purchase: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> _grant() async {
    if (_adsRemoved) return;
    _adsRemoved = true;
    await _store.save(Docs.purchases, const PurchaseState(adsRemoved: true));
  }

  @override
  Future<bool> buyRemoveAds() async {
    final product = _product;
    if (!_available || product == null || _adsRemoved) return false;
    try {
      _busy = true;
      notifyListeners();
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) _busy = false;
      notifyListeners();
      return started;
    } catch (e) {
      debugPrint('Purchase failed to start: $e');
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  @override
  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// No billing (tests, unsupported platforms). [grant] simulates a purchase.
class NoPurchaseService extends PurchaseService {
  NoPurchaseService({bool adsRemoved = false, this.price})
    : _removed = adsRemoved;

  bool _removed;
  int buyCalls = 0;

  @override
  final String? price;

  @override
  Future<void> init() async {}
  @override
  bool get adsRemoved => _removed;
  @override
  bool get canBuy => price != null && !_removed;
  @override
  bool get busy => false;

  @override
  Future<bool> buyRemoveAds() async {
    buyCalls++;
    if (price == null) return false;
    grant();
    return true;
  }

  @override
  Future<void> restore() async {}

  void grant() {
    _removed = true;
    notifyListeners();
  }
}
