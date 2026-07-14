import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'home_page.dart';


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
  bool _shownDuplicateTransactionMessage = false;
  bool _isBuying = false;
  bool _isLoadingStore = true;
  bool _storeAvailable = false;
  bool _isRestoring = false;

  final Set<String> _handledFailedPurchaseIds = {};
  String? _pendingVipProductId;
String? _pendingVipPlanId;

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
          priceTextEn: '\$26.66/month',
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
  if (plan.id == '1_week') {
    return _label('\$14.99/tuần', '\$14.99/week');
  }

  if (plan.id == '1_month') {
    return _label('\$29.99/tháng', '\$29.99/month');
  }

  if (plan.id == '3_months') {
    return _label('\$79.99 / 3 tháng', '\$79.99 / 3 months');
  }

  if (plan.id == '6_months') {
    return _label('\$149.94 / 6 tháng', '\$149.94 / 6 months');
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
                        ? 'Gói này sẽ tự động gia hạn. Số tiền thanh toán là ${_displayPrice(plan)}. Có thể hủy bất kỳ lúc nào.'
                        : 'This subscription renews automatically. The billed amount is ${_displayPrice(plan)}. Cancel anytime.',
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

const SizedBox(height: 12),

Center(
  child: Wrap(
    alignment: WrapAlignment.center,
    children: [
      if (Platform.isIOS) ...[
  GestureDetector(
    onTap: () async {
      final uri = Uri.parse(
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
      );

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    },
    child: Text(
      _label('Điều khoản sử dụng', 'Terms of Use'),
      style: const TextStyle(
        decoration: TextDecoration.underline,
        color: Colors.blue,
        fontSize: 13,
      ),
    ),
  ),

  const Text('  •  '),
],

GestureDetector(
  onTap: () async {
    final uri = Uri.parse(
      'https://eloquent-sorbet-6cf41f.netlify.app/',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  },
  child: Text(
    _label('Chính sách bảo mật', 'Privacy Policy'),
    style: const TextStyle(
      decoration: TextDecoration.underline,
      color: Colors.blue,
      fontSize: 13,
    ),
  ),
),
    ],
  ),
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
  _pendingVipProductId = plan.productId;
  _pendingVipPlanId = plan.id;
});

print(
  'VIP START BUY planId=${plan.id} productId=${plan.productId}',
);

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      print('VIP BUY BUTTON PRODUCT: ${product.id}');
print('VIP BUY PLAN PRODUCT: ${plan.productId}');
      final started = await _inAppPurchase.buyNonConsumable(
  purchaseParam: purchaseParam,
);

if (!started && mounted) {
  setState(() {
    _isBuying = false;
  });
}
    } catch (e) {
  if (!mounted) return;

  setState(() {
    _isBuying = false;
    _isRestoring = false;
  });

  final errorText = e.toString();

  if (errorText.contains('storekit_duplicate_product_object')) {
    if (_shownDuplicateTransactionMessage) {
      return;
    }

    _shownDuplicateTransactionMessage = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _label(
            'Giao dịch trước đó vẫn đang được App Store xử lý. Vui lòng đóng trang này rồi mở lại sau vài giây.',
            'Your previous transaction is still being processed by the App Store. Please close this page and reopen it after a few seconds.',
          ),
        ),
      ),
    );

    return;
  }

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
Future.delayed(const Duration(seconds: 2), () {
  if (!mounted) return;

  setState(() {
    _isRestoring = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        _label(
          'Đã kiểm tra mua hàng trước đó. Nếu bạn có VIP đang hoạt động, vui lòng chắc chắn bạn đang dùng đúng tài khoản Apple/Google đã mua.',
          'Previous purchases checked. If you have an active VIP, please make sure you are using the same Apple/Google account used to purchase.',
        ),
      ),
    ),
  );
});
      if (!mounted) return;
      
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRestoring = false;
      });
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
    print('PURCHASE STATUS: ${purchaseDetails.status}');
    print('RESTORE MODE ACTIVE: $_isRestoring');
    print('PRODUCT ID: ${purchaseDetails.productID}');
    print('PENDING COMPLETE: ${purchaseDetails.pendingCompletePurchase}');
    print('PURCHASE ERROR: ${purchaseDetails.error}');

    try {
      if (purchaseDetails.status == PurchaseStatus.pending) {
  print('VIP purchase is pending...');

  if (mounted) {
    setState(() {
      _isBuying = true;
    });
  }

  continue;
}

      if (purchaseDetails.status == PurchaseStatus.error ||
          purchaseDetails.status == PurchaseStatus.canceled) {
            final failedId =
    purchaseDetails.purchaseID ??
    purchaseDetails.verificationData.serverVerificationData;

if (_handledFailedPurchaseIds.contains(failedId)) {
  continue;
}

_handledFailedPurchaseIds.add(failedId);
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }

        if (mounted) {
          setState(() {
            _isBuying = false;
            _isRestoring = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _label(
                  'Thanh toán thất bại hoặc đã bị hủy. Vui lòng thử lại.',
                  'Purchase failed or was canceled. Please try again.',
                ),
              ),
            ),
          );
        }
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.restored && !_isRestoring) {
  print('Ignored automatic restored purchase because user did not tap Restore.');

  if (purchaseDetails.pendingCompletePurchase) {
    await _inAppPurchase.completePurchase(purchaseDetails);
  }

  if (mounted) {
    setState(() {
      _isBuying = false;
      _isRestoring = false;
    });
  }

  continue;
}

if (purchaseDetails.status == PurchaseStatus.purchased ||
    purchaseDetails.status == PurchaseStatus.restored) {
      if (!_isRestoring &&
    _pendingVipProductId != null &&
    purchaseDetails.productID != _pendingVipProductId) {
  print(
    'VIP SKIP OLD TRANSACTION: purchaseProduct=${purchaseDetails.productID}, pendingProduct=$_pendingVipProductId',
  );

  if (purchaseDetails.pendingCompletePurchase) {
    await _inAppPurchase.completePurchase(purchaseDetails);
  }

  continue;
}
        final verified = await _verifyPurchase(purchaseDetails);

        if (!verified) {
          final failedId =
    purchaseDetails.purchaseID ??
    purchaseDetails.verificationData.serverVerificationData;

if (_handledFailedPurchaseIds.contains(failedId)) {
  continue;
}

_handledFailedPurchaseIds.add(failedId);
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }

          if (mounted) {
            setState(() {
              _isBuying = false;
              _isRestoring = false;
            });

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
          continue;
        }

        final granted = await _grantVip(purchaseDetails);

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }

        if (!granted) {
          final failedId =
    purchaseDetails.purchaseID ??
    purchaseDetails.verificationData.serverVerificationData;

if (_handledFailedPurchaseIds.contains(failedId)) {
  continue;
}

_handledFailedPurchaseIds.add(failedId);
  print('VIP transaction skipped: expired, already processed, or no popup needed.');

  if (mounted) {
    setState(() {
      _isBuying = false;
      _isRestoring = false;
    });
  }

  continue;
}

        if (!mounted) return;

_pendingVipProductId = null;
_pendingVipPlanId = null;

await widget.onPurchaseSuccess();

if (mounted) {
          setState(() {
            _isBuying = false;
            _isRestoring = false;
          });

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
        }
      }
    } catch (e) {
  print('VIP PURCHASE HANDLE ERROR: $e');

  final failedId =
      purchaseDetails.purchaseID ??
      purchaseDetails.verificationData.serverVerificationData;

  if (purchaseDetails.pendingCompletePurchase) {
    await _inAppPurchase.completePurchase(purchaseDetails);
  }

  if (_handledFailedPurchaseIds.contains(failedId)) {
    if (mounted) {
      setState(() {
        _isBuying = false;
        _isRestoring = false;
      });
    }
    continue;
  }

  _handledFailedPurchaseIds.add(failedId);

  if (mounted) {
    setState(() {
      _isBuying = false;
      _isRestoring = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().contains('already-exists')
              ? _label(
                  'Gói VIP này đã được dùng cho tài khoản khác. Vui lòng đăng nhập đúng tài khoản đã mua VIP hoặc dùng Apple ID khác.',
                  'This VIP subscription is already linked to another account. Please sign in to the original account or use a different Apple ID.',
                )
              : _label(
                  'Không thể thực hiện giao dịch này. Vui lòng thử lại.',
                  'This transaction cannot be completed. Please try again.',
                ),
        ),
      ),
    );
  }
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

    if (purchase.status == PurchaseStatus.restored && !_isRestoring) {
  return false;
}

if (purchase.status != PurchaseStatus.purchased &&
    purchase.status != PurchaseStatus.restored) {
  return false;
}

    return true;
  }

  Future<bool> _grantVip(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final productId = purchase.productID;
    final transactionId =
    purchase.purchaseID ?? purchase.verificationData.serverVerificationData;
    if (Platform.isIOS) {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'verifyAppleVipPurchase',
  );

  final result = await callable.call({
    'userId': user.uid,
    'productId': productId,
    'transactionId': transactionId,
    'mode': purchase.status == PurchaseStatus.restored
        ? 'restore'
        : 'purchase',
  });

  final data = Map<String, dynamic>.from(result.data);


  if (data['success'] == true) {
  if (data['alreadyProcessed'] == true) {
    print('VIP iOS purchase already processed, skip popup.');
    return false;
  }

  if (data['shouldShowPopup'] == false) {
    print('VIP iOS purchase verified but popup skipped.');
    return false;
  }

  return true;
}

  return false;
}

final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

final processedRef =
    userRef.collection('processedVipPurchases').doc(transactionId);

final processedDoc = await processedRef.get();

if (processedDoc.exists) {
  print('VIP purchase already processed: $transactionId');
  return false;
}
if (Platform.isAndroid) {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'verifyGoogleVipPurchase',
  );

  final result = await callable.call({
    'userId': user.uid,
    'productId': productId,
    'purchaseToken': purchase.verificationData.serverVerificationData,
    'mode': purchase.status == PurchaseStatus.restored
        ? 'restore'
        : 'purchase',
  });

  final data = Map<String, dynamic>.from(result.data);

  if (data['success'] == true) {
    if (data['alreadyProcessed'] == true) {
      print('VIP Google purchase already processed, skip popup.');
      return false;
    }

    if (data['shouldShowPopup'] == false) {
      print('VIP Google purchase verified but popup skipped.');
      return false;
    }

    return true;
  }

  return false;
}
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

await userRef.set({
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

await processedRef.set({
  'transactionId': transactionId,
  'vipProductId': productId,
  'vipPlanId': planId,
  'purchaseStatus': purchase.status.name,
  'vipExpiresAt': Timestamp.fromDate(expiresAt),
  'createdAt': FieldValue.serverTimestamp(),
});
return true;
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
    backgroundColor: const Color(0xFFFFF8FB),
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new),
      onPressed: () {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => HomePage(
        languageCode: widget.languageCode,
      ),
    ),
    (route) => false,
  );
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
                    GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: plans.length,
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 0.85,
  ),
  itemBuilder: (context, index) {
    final item = plans[index];
    final selected = selectedPlanId == item.id;

    final String? monthlyPrice = item.id == '3_months'
        ? _label('\$26.66/tháng', '\$26.66/month')
        : item.id == '6_months'
            ? _label('\$24.99/tháng', '\$24.99/month')
            : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: (_isBuying || _isRestoring)
            ? null
            : () {
                setState(() {
                  selectedPlanId = item.id;
                });

                _confirmPurchase(item);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF0EEFF)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF4F46E5)
                  : Colors.grey.shade300,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isVi ? item.titleVi : item.titleEn,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _displayPrice(item),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? const Color(0xFF4F46E5)
                        : Colors.black87,
                  ),
                ),
              ),

              if (monthlyPrice != null) ...[
                const SizedBox(height: 6),
                Text(
                  monthlyPrice,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black45,
                  ),
                ),
              ],

              const SizedBox(height: 5),

              Text(
                item.id == '1_week'
                    ? _label(
                        'Thanh toán mỗi tuần',
                        'Billed weekly',
                      )
                    : item.id == '1_month'
                        ? _label(
                            'Thanh toán mỗi tháng',
                            'Billed monthly',
                          )
                        : item.id == '3_months'
                            ? _label(
                                'Thanh toán \$79.99 mỗi 3 tháng',
                                'Billed \$79.99 every 3 months',
                              )
                            : _label(
                                'Thanh toán \$149.94 mỗi 6 tháng',
                                'Billed \$149.94 every 6 months',
                              ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
),
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
                      '🌸',
                      _label(
                        'Gởi hoa không giới hạn',
                        'Send Unlimited flowers',
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


                    const SizedBox(height: 12),

                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          if (Platform.isIOS) ...[
  GestureDetector(
    onTap: () async {
      final uri = Uri.parse(
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
      );

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    },
    child: Text(
      _label('Điều khoản sử dụng', 'Terms of Use'),
      style: const TextStyle(
        decoration: TextDecoration.underline,
        color: Colors.blue,
        fontSize: 13,
      ),
    ),
  ),

  const Text('  •  '),
],

GestureDetector(
  onTap: () async {
    final uri = Uri.parse(
      'https://eloquent-sorbet-6cf41f.netlify.app/',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  },
  child: Text(
    _label('Chính sách bảo mật', 'Privacy Policy'),
    style: const TextStyle(
      decoration: TextDecoration.underline,
      color: Colors.blue,
      fontSize: 13,
    ),
  ),
),
                        ],
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