import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product id of the non-consumable "unlock all skins" purchase.
/// This MUST match the managed product id created in Google Play Console
/// (and App Store Connect if/when iOS is added).
const String kUnlockAllSkinsProductId = 'unlock_all_skins';

/// Outcome of an attempted purchase, surfaced to the UI.
enum PurchaseResult { success, cancelled, pending, error, unavailable }

/// Handles in-app purchases (currently the premium "unlock all skins" pack).
///
/// Flow:
///  1. [buyUnlockAllSkins] launches the store purchase.
///  2. The platform delivers updates on [InAppPurchase.purchaseStream].
///  3. On a purchased/restored item we send the receipt to the
///     `verifyPurchase` Cloud Function, which validates it against the Google
///     Play Developer API and, if valid, sets `allSkinsUnlocked = true` on the
///     user document (server-side, so the client can never forge it).
///  4. We always call [InAppPurchase.completePurchase] to finish the tx.
class PurchaseService {
  PurchaseService() {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) => debugPrint('purchaseStream error: $e'),
    );
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  /// Emits whenever a verified unlock completes, so listeners (e.g. a snackbar)
  /// can react. Carries the final [PurchaseResult].
  final StreamController<PurchaseResult> _resultController =
      StreamController<PurchaseResult>.broadcast();
  Stream<PurchaseResult> get results => _resultController.stream;

  ProductDetails? _unlockAllProduct;

  /// Whether IAP is usable on this platform (mobile stores only).
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Localized, store-provided price string (e.g. "4,99 €"). Null until the
  /// product has been loaded via [loadProducts].
  String? get unlockAllPrice => _unlockAllProduct?.price;

  bool get unlockAllAvailable => _unlockAllProduct != null;

  /// Query the store for the unlock-all product. Safe to call multiple times.
  Future<void> loadProducts() async {
    if (!isSupported) return;
    final available = await _iap.isAvailable();
    if (!available) return;
    final response =
        await _iap.queryProductDetails({kUnlockAllSkinsProductId});
    if (response.productDetails.isNotEmpty) {
      _unlockAllProduct = response.productDetails.first;
    }
  }

  /// Launch the purchase flow for the unlock-all pack. The actual unlock is
  /// applied asynchronously once the receipt is verified server-side; listen
  /// to [results] for the outcome.
  Future<PurchaseResult> buyUnlockAllSkins() async {
    if (!isSupported) return PurchaseResult.unavailable;
    if (_unlockAllProduct == null) {
      await loadProducts();
      if (_unlockAllProduct == null) return PurchaseResult.unavailable;
    }
    final param = PurchaseParam(productDetails: _unlockAllProduct!);
    final started = await _iap.buyNonConsumable(purchaseParam: param);
    return started ? PurchaseResult.pending : PurchaseResult.error;
  }

  /// Ask the store to re-deliver past non-consumable purchases. Required for
  /// App Store review and lets users recover the unlock on a new device.
  Future<void> restorePurchases() async {
    if (!isSupported) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _resultController.add(PurchaseResult.pending);
          break;
        case PurchaseStatus.canceled:
          _resultController.add(PurchaseResult.cancelled);
          break;
        case PurchaseStatus.error:
          debugPrint('purchase error: ${purchase.error}');
          _resultController.add(PurchaseResult.error);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = await _verify(purchase);
          _resultController
              .add(ok ? PurchaseResult.success : PurchaseResult.error);
          break;
      }
      // Always finish the transaction so the store stops re-delivering it.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Send the receipt to the backend for server-side verification. Returns
  /// true only if the Cloud Function confirmed and applied the unlock.
  Future<bool> _verify(PurchaseDetails purchase) async {
    if (purchase.productID != kUnlockAllSkinsProductId) return false;
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyPurchase');
      final result = await callable.call<Map<String, dynamic>>({
        'productId': purchase.productID,
        'source': purchase.verificationData.source,
        'serverVerificationData':
            purchase.verificationData.serverVerificationData,
      });
      return result.data['valid'] == true;
    } catch (e) {
      debugPrint('verifyPurchase failed: $e');
      return false;
    }
  }

  void dispose() {
    _subscription.cancel();
    _resultController.close();
  }
}

/// App-wide singleton for in-app purchases.
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(service.dispose);
  return service;
});
