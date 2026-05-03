import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BuyFlowerPage extends StatefulWidget {
  final String languageCode;
  final String? autoBuyProductId;

  const BuyFlowerPage({
    super.key,
    required this.languageCode,
    this.autoBuyProductId,
  });

  @override
  State<BuyFlowerPage> createState() => _BuyFlowerPageState();
}

class _BuyFlowerPageState extends State<BuyFlowerPage> {
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPurchasing = false;

  ProductDetails? _selectedProduct;
  List<ProductDetails> _products = [];

  bool get isVi => widget.languageCode == 'vi';

  String _label(String vi, String en) => isVi ? vi : en;

  static const Set<String> _productIds = {
    'flower_1',
    'flower_5',
    'flower_10',
  };

  @override
  void initState() {
    super.initState();

    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isPurchasing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _label(
                'Thanh toán bị lỗi. Vui lòng thử lại.',
                'Purchase failed. Please try again.',
              ),
            ),
          ),
        );
      },
    );

    _loadProducts();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final available = await _iap.isAvailable();

    if (!available) {
      if (!mounted) return;
      setState(() {
        _isAvailable = false;
        _isLoading = false;
      });
      return;
    }

    final response = await _iap.queryProductDetails(_productIds);
debugPrint('FLOWER FOUND: ${response.productDetails.map((e) => e.id).toList()}');
debugPrint('FLOWER NOT FOUND: ${response.notFoundIDs}');
debugPrint('FLOWER ERROR: ${response.error}');
    final products = response.productDetails.toList();

    products.sort((a, b) {
      return _flowerCountFromProductId(a.id)
          .compareTo(_flowerCountFromProductId(b.id));
    });

    if (!mounted) return;

    setState(() {
      _isAvailable = true;
      _products = products;
      _selectedProduct = products.isNotEmpty ? products.first : null;
      _isLoading = false;
    });
    if (widget.autoBuyProductId != null && products.isNotEmpty) {
  final matched = products
      .where((p) => p.id == widget.autoBuyProductId)
      .toList();

  if (matched.isNotEmpty) {
    _selectedProduct = matched.first;

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _buySelectedProduct();
      }
    });
  }
}
  }

  Future<void> _buySelectedProduct() async {
    if (_selectedProduct == null || _isPurchasing) return;

    setState(() {
      _isPurchasing = true;
    });

    final purchaseParam = PurchaseParam(productDetails: _selectedProduct!);

    await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: true,
    );
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        setState(() {
          _isPurchasing = true;
        });
      }

      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _label(
                  'Thanh toán không thành công.',
                  'Purchase was not successful.',
                ),
              ),
            ),
          );
        }
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _giveFlowersToUser(purchase.productID);

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        if (!mounted) return;

        setState(() {
          _isPurchasing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _label(
                'Mua flower thành công.',
                'Flowers purchased successfully.',
              ),
            ),
          ),
        );

        Navigator.pop(context);
      }

      if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() {
            _isPurchasing = false;
          });
        }
      }
    }
  }

  Future<void> _giveFlowersToUser(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final count = _flowerCountFromProductId(productId);
    if (count <= 0) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'flowerBalance': FieldValue.increment(count),
      'lastFlowerPurchaseAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  int _flowerCountFromProductId(String productId) {
    if (productId == 'flower_1') return 1;
    if (productId == 'flower_5') return 5;
    if (productId == 'flower_10') return 10;
    return 0;
  }

  String _titleForProduct(ProductDetails product) {
    final count = _flowerCountFromProductId(product.id);

    if (count == 1) {
      return _label('1 flower', '1 flower');
    }

    return _label('$count flowers', '$count flowers');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCC3D7A),
        foregroundColor: Colors.white,
        title: Text(_label('Mua Flower', 'Buy Flowers')),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFCC3D7A)),
            )
          : !_isAvailable
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _label(
                        'Thanh toán chưa khả dụng trên thiết bị này.',
                        'Purchases are not available on this device.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _label(
                            'Chưa tìm thấy gói flower. Hãy kiểm tra product ID trên Apple/Google.',
                            'No flower products found. Please check your product IDs on Apple/Google.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 18),
                          const Icon(
                            Icons.local_florist,
                            size: 80,
                            color: Color(0xFFCC3D7A),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _label(
                              'Mua thêm flowers để gửi lời nhắn đặc biệt',
                              'Buy more flowers to send a special message',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 26),

                          ..._products.map((product) {
                            final selected = _selectedProduct?.id == product.id;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedProduct = product;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFFFE1EE)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFCC3D7A)
                                        : Colors.grey.shade300,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: const Color(0xFFCC3D7A),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        _titleForProduct(product),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      product.price,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFCC3D7A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          const Spacer(),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed:
                                  _isPurchasing ? null : _buySelectedProduct,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCC3D7A),
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isPurchasing
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _label('Purchase', 'Purchase'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: _isPurchasing
                                ? null
                                : () {
                                    Navigator.pop(context);
                                  },
                            child: Text(
                              _label('Huỷ', 'Cancel'),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}