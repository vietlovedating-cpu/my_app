import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  IAPService._();
  static final IAPService instance = IAPService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  List<ProductDetails> products = [];
  bool storeAvailable = false;
  bool initialized = false;

  Future<void> init(Set<String> productIds) async {
    if (initialized) return;

    storeAvailable = await _inAppPurchase.isAvailable();
    if (!storeAvailable) {
      throw Exception('Store is not available');
    }

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(productIds);

    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }

    products = response.productDetails;

    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('Purchase stream error: $error');
      },
    );

    initialized = true;
  }

  ProductDetails? getProductById(String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  Future<void> buySubscription(String productId) async {
    final product = getProductById(productId);
    if (product == null) {
      throw Exception('Product not loaded: $productId');
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );

    await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending: ${purchase.productID}');
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        debugPrint('Purchase success/restored: ${purchase.productID}');

        // Tạm thời chỉ complete purchase.
        // Bước sau mình sẽ nối Firestore unlock group ở đây.
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> restorePurchases() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _inAppPurchase.restorePurchases();
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}