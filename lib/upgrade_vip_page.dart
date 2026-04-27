import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';


class UpgradeVipPage extends StatefulWidget {
  final String languageCode;
  final Future<void> Function() onPurchaseSuccess;

  const UpgradeVipPage({
    super.key,
    required this.languageCode,
    required this.onPurchaseSuccess,
  });

  @override
  State<UpgradeVipPage> createState() => _UpgradeVipPageState();
}

class _UpgradeVipPageState extends State<UpgradeVipPage> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isBuying = false;
  bool _isLoadingStore = true;
  bool _storeAvailable = false;
  bool _isRestoring = false;

  String selectedPlanId = '1_week';

  final Map<String, ProductDetails> _storeProducts = {};

  bool get isVi => widget.languageCode == 'vi';

  String _label(String vi, String en) => isVi ? vi : en;

  List<_VipPlan> get plans => [
        _VipPlan(
          id: '1_week',
          productId: 'com.vietlove.vip.weekly',
          titleVi: '1 tuần',
          titleEn: '1 week',
          priceTextVi: '\$14.99/tuần',
          priceTextEn: '\$14.99/week',
          monthsToAdd: 0,
          daysToAdd: 7,
        ),
        _VipPlan(
          id: '1_month',
          productId: 'com.vietlove.vip.monthly',
          titleVi: '1 tháng',
          titleEn: '1 month',
          priceTextVi: '\$29.99/tháng',
          priceTextEn: '\$29.99/month',
          monthsToAdd: 1,
          daysToAdd: 0,
        ),
        _VipPlan(
          id: '3_months',
          productId: 'com.vietlove.vip.3months',
          titleVi: '3 tháng',
          titleEn: '3 months',
          priceTextVi: '\$26.66/tháng',
          priceTextEn: '\$26.66/months',
          monthsToAdd: 3,
          daysToAdd: 0,
        ),
        _VipPlan(
          id: '6_months',
          productId: 'com.vietlove.vip.6months',
          titleVi: '6 tháng',
          titleEn: '6 months',
          priceTextVi: '\$24.99/tháng',
          priceTextEn: '\$24.99/month',
          monthsToAdd: 6,
          daysToAdd: 0,
        ),
      ];

  _VipPlan get selectedPlan =>
      plans.firstWhere((item) => item.id == selectedPlanId);

  @override
  void initState() {
    super.initState();

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () {
        _purchaseSubscription?.cancel();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isBuying = false;
          _isRestoring = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Lỗi purchase stream: $error'
                  : 'Purchase stream error: $error',
            ),
          ),
        );
      },
    );

    _loadStoreProducts();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStoreProducts() async {
    final available = await _inAppPurchase.isAvailable();

    if (!mounted) return;

    if (!available) {
      setState(() {
        _storeAvailable = false;
        _isLoadingStore = false;
      });
      return;
    }

    final productIds = plans.map((e) => e.productId).toSet();
    final response = await _inAppPurchase.queryProductDetails(productIds);

    if (!mounted) return;

    final map = <String, ProductDetails>{};
    for (final item in response.productDetails) {
      map[item.id] = item;
    }

    setState(() {
      _storeAvailable = true;
      _storeProducts.clear();
      _storeProducts.addAll(map);
      _isLoadingStore = false;
    });
  }

  String _displayPrice(_VipPlan plan) {
    final storeProduct = _storeProducts[plan.productId];
    if (storeProduct != null) {
      return storeProduct.price;
    }
    return isVi ? plan.priceTextVi : plan.priceTextEn;
  }

  Future<void> _confirmPurchase(_VipPlan plan) async {
    final bool? shouldBuy = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      isVi
                          ? 'Bạn đã chọn gói VIP ${plan.titleVi} ${_displayPrice(plan)}'
                          : 'You selected VIP ${plan.titleEn} ${_displayPrice(plan)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4438CA),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      _label(
                        'Bạn có chắc muốn tiếp tục không?',
                        'Are you sure you want to proceed?',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isVi
                          ? 'Bạn đã chọn gói VIP ${plan.titleVi} cho ${_displayPrice(plan)}.'
                          : 'You selected VIP ${plan.titleEn} for ${_displayPrice(plan)}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(_label('Hủy', 'Cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B4BDB),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _label('Mua', 'Purchase'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                top: 10,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (shouldBuy == true) {
      await _purchasePlan(plan);
    }
  }

  Future<void> _purchasePlan(_VipPlan plan) async {
    if (_isLoadingStore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Đang tải thông tin từ App Store, thử lại sau chút.',
              'Loading App Store products, please try again.',
            ),
          ),
        ),
      );
      return;
    }

    if (!_storeAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'App Store hiện chưa sẵn sàng.',
              'App Store is not available right now.',
            ),
          ),
        ),
      );
      return;
    }

    final product = _storeProducts[plan.productId];
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Không tìm thấy gói này trên App Store.',
              'This subscription was not found on App Store.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isBuying = true;
    });

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isBuying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Mua VIP thất bại: $e' : 'VIP purchase failed: $e',
          ),
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
    if (_isLoadingStore) return;

    setState(() {
      _isRestoring = true;
    });

    try {
      await _inAppPurchase.restorePurchases();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Đang kiểm tra các giao dịch đã mua trước đó...',
              'Checking your previous purchases...',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRestoring = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi
                ? 'Khôi phục mua hàng thất bại: $e'
                : 'Restore purchases failed: $e',
          ),
        ),
      );
    }
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (!mounted) return;
        setState(() {
          _isBuying = true;
        });
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (!mounted) return;
        setState(() {
          _isBuying = false;
          _isRestoring = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _label(
                'Thanh toán thất bại. Vui lòng thử lại.',
                'Purchase failed. Please try again.',
              ),
            ),
          ),
        );
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final verified = await _verifyPurchase(purchaseDetails);

        if (verified) {
          await _grantVip(purchaseDetails);
          await widget.onPurchaseSuccess();

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                purchaseDetails.status == PurchaseStatus.restored
                    ? _label(
                        'Đã khôi phục VIP thành công.',
                        'VIP restored successfully.',
                      )
                    : _label(
                        'Mua VIP thành công.',
                        'VIP purchase successful.',
                      ),
              ),
            ),
          );
        } else {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _label(
                  'Không thể xác minh giao dịch.',
                  'Could not verify this purchase.',
                ),
              ),
            ),
          );
        }

        if (!mounted) return;
        setState(() {
          _isBuying = false;
          _isRestoring = false;
        });
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // Bước 6:
    // Hiện tại tạm cho pass để app chạy được end-to-end.
    // Sau này bạn thay phần này bằng call Firebase Function / backend
    // để verify thật với Apple server.

    final validProductIds = plans.map((e) => e.productId).toSet();

    if (!validProductIds.contains(purchase.productID)) {
      return false;
    }

    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return false;
    }

    return true;
  }

  Future<void> _grantVip(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final productId = purchase.productID;

    String planId = 'unknown';
String titleVi = '';
String titleEn = '';
String priceVi = '';
String priceEn = '';
int monthsToAdd = 0;
int daysToAdd = 0;

    for (final plan in plans) {
  if (plan.productId == productId) {
    planId = plan.id;
    titleVi = plan.titleVi;
    titleEn = plan.titleEn;
    priceVi = plan.priceTextVi;
    priceEn = plan.priceTextEn;
    monthsToAdd = plan.monthsToAdd;
    daysToAdd = plan.daysToAdd;
    break;
  }
}

final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .get();

DateTime now = DateTime.now();

DateTime expiresAt = now;

final existingExpire = userDoc.data()?['vipExpiresAt'];

if (existingExpire != null) {
  final currentExpire = existingExpire.toDate();

  // nếu VIP còn hạn → cộng thêm
  if (currentExpire.isAfter(now)) {
    expiresAt = currentExpire;
  }
}

if (daysToAdd > 0) {
  expiresAt = expiresAt.add(Duration(days: daysToAdd));
}

if (monthsToAdd > 0) {
  expiresAt = DateTime(
    expiresAt.year,
    expiresAt.month + monthsToAdd,
    expiresAt.day,
    expiresAt.hour,
    expiresAt.minute,
    expiresAt.second,
  );
}
final String platform = Platform.isIOS ? 'app_store' : 'google_play';
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'isVip': true,
      'vipUnlocked': true,
      'membership': 'vip',
      'plan': 'vip',
      'subscriptionType': planId,
      'vipPlanId': planId,
      'vipProductId': productId,
      'vipPlatform': platform,
      'vipStatus': 'active',


       'vipExpiresAt': Timestamp.fromDate(expiresAt),
  'vipReminder7dSent': false,
  'vipReminder3dSent': false,
  'vipReminder1dSent': false,
  'vipExpiredHandled': false,

      'vipPlanTitleVi': titleVi,
      'vipPlanTitleEn': titleEn,
      'vipPriceTextVi': priceVi,
      'vipPriceTextEn': priceEn,
      'vipPurchasedAt': FieldValue.serverTimestamp(),
      'vipUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Widget _featureItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = selectedPlan;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingStore)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _label(
                      'Đang kết nối App Store...',
                      'Connecting to App Store...',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (!_isLoadingStore && !_storeAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _label(
                      'Không kết nối được App Store lúc này.',
                      'Unable to connect to App Store right now.',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label('Vietlove VIP', 'Vietlove VIP'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: plans.map((item) {
                        final selected = selectedPlanId == item.id;
                        final isLast = item.id == plans.last.id;

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: isLast ? 0 : 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: (_isBuying || _isRestoring)
                                    ? null
                                    : () {
                                        setState(() {
                                          selectedPlanId = item.id;
                                        });
                                        _confirmPurchase(item);
                                      },
                                child: Container(
  constraints: const BoxConstraints(
    minHeight: 118,
  ),
  padding: const EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 18,
  ),
  decoration: BoxDecoration(
    color: selected
        ? const Color(0xFFF0EEFF)
        : Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: selected
          ? const Color(0xFF4F46E5)
          : Colors.grey.shade300,
      width: selected ? 1.5 : 1,
    ),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        isVi ? item.titleVi : item.titleEn,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: selected
              ? const Color(0xFF4F46E5)
              : Colors.black87,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _displayPrice(item),
        textAlign: TextAlign.center,
        maxLines: 2,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: selected
              ? const Color(0xFF4F46E5)
              : Colors.black54,
        ),
      ),
    ],
  ),
),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _label('Quyền lợi VIP', 'VIP benefits'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _featureItem(
                      '🚀',
                      _label(
                        'Mở khóa toàn bộ trải nghiệm hẹn hò cao cấp',
                        'Unlock premium dating experience',
                      ),
                    ),
                    _featureItem(
                      '💎',
                      _label('Xem ai đã thích bạn ngay', 'See who likes you'),
                    ),
                    _featureItem(
                      '🔥',
                      _label(
                        'Nhiều cơ hội match nhanh hơn',
                        'Get more matches',
                      ),
                    ),
                    _featureItem(
                      '⚡',
                      _label(
                        'Luôn được ưu tiên hiển thị',
                        'Be seen first',
                      ),
                    ),
                    _featureItem(
                      '❤️',
                      _label(
                        'Nhắn tin và gởi hoa không giới hạn',
                        'Unlimited message and send flowers',
                      ),
                    ),
                    _featureItem(
                      '👀',
                      _label(
                        'Biết ai đang quan tâm bạn',
                        'Know who’s interested',
                      ),
                    ),
                    _featureItem(
                      '🎯',
                      _label(
                        'Gợi ý tìm người phù hợp với tiêu chí của bạn',
                        'Suggestions to find people who match your criteria ',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isBuying || _isRestoring)
                            ? null
                            : () => _confirmPurchase(plan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B4BDB),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isBuying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _label(
                                  'Mua gói đã chọn',
                                  'Buy selected plan',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: (_isBuying || _isRestoring)
                            ? null
                            : _restorePurchases,
                        child: _isRestoring
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _label(
                                  'Khôi phục mua hàng',
                                  'Restore Purchases',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VipPlan {
  final String id;
  final String productId;
  final String titleVi;
  final String titleEn;
  final String priceTextVi;
  final String priceTextEn;
  final int monthsToAdd;
  final int daysToAdd;

  const _VipPlan({
    required this.id,
    required this.productId,
    required this.titleVi,
    required this.titleEn,
    required this.priceTextVi,
    required this.priceTextEn,
    required this.monthsToAdd,
    required this.daysToAdd,
  });
}