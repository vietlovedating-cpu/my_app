import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'group_chat_page.dart';
import 'group_data.dart';

class GroupDetailPage extends StatefulWidget {
  final String languageCode;
  final DatingGroupItem group;

  const GroupDetailPage({
    super.key,
    required this.languageCode,
    required this.group,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _purchasePending = false;

  

  bool _shownAppleLinkedPopup = false;
  String? _buyingProductId;
String? _buyingGroupId;
  final Set<String> _handledPurchaseIds = {};
  Map<String, dynamic>? _membershipData;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _availableProducts = [];

  bool get isVi => widget.languageCode == 'vi';
  User? get currentUser => FirebaseAuth.instance.currentUser;

  String _label(String vi, String en) => isVi ? vi : en;

  DocumentReference<Map<String, dynamic>> get _memberDocRef =>
      FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.id)
          .collection('members')
          .doc(currentUser!.uid);

  @override
  void initState() {
    super.initState();
    _loadMembership();
    _listenToPurchases();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  void _listenToPurchases() {
    _purchaseSubscription =
        _inAppPurchase.purchaseStream.listen(_onPurchaseUpdated);
  }

  Future<void> _loadMembership() async {
    final user = currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await _memberDocRef.get();

      if (!mounted) return;
      setState(() {
        _membershipData = doc.data();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool get _hasJoinedGroup => _membershipData != null;

  bool get _isActive {
    final data = _membershipData;
    if (data == null) return false;

    final membershipActive = data['membershipActive'] == true;
    final expiresAt = data['expiresAt'] as Timestamp?;

    if (!membershipActive || expiresAt == null) return false;

    return expiresAt.toDate().isAfter(DateTime.now());
  }

  String get _statusText {
    if (_membershipData == null) {
      return _label(
        'Bạn chưa tham gia nhóm này',
        'You have not joined this group yet',
      );
    }
    if (_isActive) {
      return _label(
        'Gói nhóm của bạn đang hoạt động',
        'Your group plan is active',
      );
    }
    return _label(
      'Gói nhóm của bạn đã hết hạn',
      'Your group plan has expired',
    );
  }

  String _priceText() {
  final productId = _productId();

  if (productId != null) {
    final matchingProducts =
        _availableProducts.where((p) => p.id == productId).toList();

    if (matchingProducts.isNotEmpty) {
      return matchingProducts.first.price;
    }
  }

  return '\$9.99 / 1 month';
}
  double _groupPrice() {
  switch (widget.group.id) {
    case 'sydney_vietnamese':
      return 9.99;
    case 'melbourne_vietnamese':
      return 9.99;
    case 'queensland_vietnamese':
      return 9.99;
    case 'perth_vietnamese':
      return 9.99;
    default:
      return 9.99;
  }
}

  String? _productId() {
  switch (widget.group.id) {
    case 'sydney_vietnamese':
      return 'group.sydney_vietnamese.monthlyv3';

    case 'melbourne_vietnamese':
      return 'group.melbourne_vietnamese.monthly';

    case 'queensland_vietnamese':
      return 'group.queensland_vietnamese.monthly';

    case 'perth_vietnamese':
      return 'group.perth_vietnamese.monthly';

    default:
      return null;
  }
}


  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatPage(
          languageCode: widget.languageCode,
          group: widget.group,

          // thêm các field này để GroupChatPage biết current user
          // đã mua / active / expired hay chưa
          currentUserMembership: _membershipData,
          currentUserGroupId: widget.group.id,
          currentUserEmail: currentUser?.email,
          currentUserUid: currentUser?.uid,
          currentUserHasJoined: _hasJoinedGroup,
          currentUserIsActive: _isActive,
        ),
      ),
    );
  }

  void _handleGroupImageTap() {
  _openActiveGroupPage();
}

  void _openActiveGroupPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActiveGroupOverviewPage(
          languageCode: widget.languageCode,
          group: widget.group,
          isVi: isVi,
          isActive: _isActive,
          statusText: _statusText,
          expiryText: _expiryText(),
          expiryLineText: _expiryLineText(),
          daysLeft: _daysLeft(),
          priceText: _priceText(),
          descriptionParagraphs: _groupIntroParagraphs(),
          isProcessing: _isProcessing,
          purchasePending: _purchasePending,
          onOpenChat: _openChat,
          onRenew: _startAppleRenewFlow,
        ),
      ),
    );
  }

  Future<void> _startAppleRenewFlow() async {
    final productId = _productId();
    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Không tìm thấy gói thanh toán cho nhóm này.',
              'Could not find a payment product for this group.',
            ),
          ),
        ),
      );
      return;
    }

    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Không thể kết nối Apple Store.',
              'Cannot connect to Apple Store.',
            ),
          ),
        ),
      );
      return;
    }
setState(() {
  _buyingProductId = productId;
  _buyingGroupId = widget.group.id;
});

    print('GROUP RENEW CLICKED: groupId=${widget.group.id}, productId=$productId');

final response = await _inAppPurchase.queryProductDetails({productId});

print('GROUP PRODUCT QUERY ERROR: ${response.error}');
print('GROUP PRODUCTS FOUND: ${response.productDetails.map((p) => p.id).toList()}');
print('GROUP PRODUCTS NOT FOUND: ${response.notFoundIDs}');

if (response.error != null || response.productDetails.isEmpty) {
  if (!mounted) return;
  setState(() {
    _purchasePending = false;
    _buyingProductId = null;
    _buyingGroupId = null;
  });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Không tìm thấy sản phẩm thanh toán trong App Store Connect.',
              'Product not found in App Store Connect.',
            ),
          ),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _availableProducts = response.productDetails;
      });
    }

    final productDetails = response.productDetails.first;
    final purchaseParam = PurchaseParam(productDetails: productDetails);

    setState(() {
  _purchasePending = true;
});

final started = await _inAppPurchase.buyNonConsumable(
  purchaseParam: purchaseParam,
);

if (!started && mounted) {
  setState(() {
    _purchasePending = false;
    _buyingProductId = null;
    _buyingGroupId = null;
  });
}
}

Future<bool> _verifyAndActivateGroupMembership(
  PurchaseDetails purchaseDetails,
) async {
  final user = currentUser;
  if (user == null) return false;

  final productId = purchaseDetails.productID;

  final transactionId =
      purchaseDetails.purchaseID ??
      purchaseDetails.verificationData.serverVerificationData;

  final callable = FirebaseFunctions.instance.httpsCallable(
    'verifyAppleGroupPurchase',
  );

  final result = await callable.call({
  'userId': user.uid,
  'groupId': widget.group.id,
  'productId': productId,
  'transactionId': transactionId,
  'mode': 'purchase',
});

  final data = Map<String, dynamic>.from(result.data);

  if (data['success'] == true) {
    await _loadMembership();
    return data['shouldShowPopup'] == true;
  }

  return false;
}

Future<void> _onPurchaseUpdated(
  List<PurchaseDetails> purchaseDetailsList,
) async {
  for (final purchaseDetails in purchaseDetailsList) {
    final purchaseId =
        purchaseDetails.purchaseID ??
        purchaseDetails.verificationData.serverVerificationData;

    if (_handledPurchaseIds.contains(purchaseId)) {
      continue;
    }

    if (purchaseDetails.status == PurchaseStatus.pending) {
  print(
    'Group purchase pending: '
    '${purchaseDetails.productID}',
  );

  if (mounted) {
    setState(() {
      _purchasePending = true;
    });
  }

  continue;
}

    if (purchaseDetails.status == PurchaseStatus.restored) {
  final expectedProductId = _buyingProductId;

  if (expectedProductId == null ||
      purchaseDetails.productID != expectedProductId) {
    print(
      'Ignored old restored group purchase. '
      'expectedProductId=$expectedProductId, '
      'purchaseProductId=${purchaseDetails.productID}',
    );

    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }

    continue;
  }

  _handledPurchaseIds.add(purchaseId);

  try {
    await _verifyAndActivateGroupMembership(purchaseDetails);
  } catch (e) {
    print('Restore group verify error: $e');
  }

  if (purchaseDetails.pendingCompletePurchase) {
    await _inAppPurchase.completePurchase(purchaseDetails);
  }

  if (mounted) {
    setState(() {
      _purchasePending = false;
      _buyingProductId = null;
      _buyingGroupId = null;
    });
  }

  continue;
}

    if (purchaseDetails.status == PurchaseStatus.error ||
        purchaseDetails.status == PurchaseStatus.canceled) {
      _handledPurchaseIds.add(purchaseId);
      if (mounted) {
  setState(() {
    _purchasePending = false;
    _buyingProductId = null;
    _buyingGroupId = null;
  });
}

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }

      if (!mounted) continue;

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

      continue;
    }

    if (purchaseDetails.status == PurchaseStatus.purchased) {
  final expectedProductId = _buyingProductId;

if (expectedProductId == null) {
  print(
    'Ignored group purchase because user did not start purchase on this page. '
    'purchaseProductId=${purchaseDetails.productID}, '
    'purchaseId=$purchaseId',
  );


  continue;
}
  if (purchaseDetails.productID != expectedProductId) {
  print(
    'Ignored and completed old group transaction. '
    'currentGroup=${widget.group.id}, '
    'expectedProductId=$expectedProductId, '
    'purchaseProductId=${purchaseDetails.productID}, '
    'purchaseId=$purchaseId',
  );

  _handledPurchaseIds.add(purchaseId);

  if (purchaseDetails.pendingCompletePurchase) {
    await _inAppPurchase.completePurchase(purchaseDetails);
  }

  continue;
}

  _handledPurchaseIds.add(purchaseId);

  bool shouldShowPopup = false;

try {
  shouldShowPopup =
      await _verifyAndActivateGroupMembership(
        purchaseDetails,
      );
} on FirebaseFunctionsException catch (e) {
  if (
      e.code == 'already-exists' &&
      !_shownAppleLinkedPopup &&
      mounted) {

    _shownAppleLinkedPopup = true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isVi
              ? 'Apple ID đã liên kết tài khoản khác'
              : 'Apple ID already linked',
        ),
        content: Text(
          isVi
              ? 'Gói nhóm Apple này đã được liên kết với một tài khoản khác.'
              : 'This Apple group subscription is already linked to another account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isVi ? 'Đóng' : 'Close',
            ),
          ),
        ],
      ),
    );
  }

  if (mounted) {
    setState(() {
      _purchasePending = false;
      _buyingProductId = null;
      _buyingGroupId = null;
    });
  }

  if (purchaseDetails.pendingCompletePurchase) {
    await _inAppPurchase.completePurchase(
      purchaseDetails,
    );
  }

  continue;
}
      if (mounted) {
  setState(() {
    _purchasePending = false;
    _buyingProductId = null;
    _buyingGroupId = null;
  });
}

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }

      if (shouldShowPopup && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _label(
                'Đã gia hạn gói nhóm thành công',
                'Group membership renewed successfully',
              ),
            ),
          ),
        );
      }

      continue;
    }
  }
}

  String _expiryText() {
    final data = _membershipData;
    if (data == null) return '';

    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt == null) return '';

    final dt = expiresAt.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _expiryLineText() {
    final expiry = _expiryText();
    if (expiry.isEmpty) {
      return _label(
        'Ngày hết hạn: Chưa có',
        'Expiry date: Not available',
      );
    }

    return _label(
      'Ngày hết hạn: $expiry',
      'Expiry date: $expiry',
    );
  }

  int _daysLeft() {
    final data = _membershipData;
    if (data == null) return 0;

    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt == null) return 0;

    final now = DateTime.now();
    final expiry = expiresAt.toDate();

    final difference = expiry.difference(now).inHours;

    if (difference <= 0) return 0;

    return (difference / 24).ceil();
  }

  List<String> _groupIntroParagraphs() {
  switch (widget.group.id) {
    case 'sydney_vietnamese':
      return [
        _label(
          'Đây là cộng đồng dành cho người Việt đang sinh sống, học tập và làm việc tại Sydney.',
          'This community is for Vietnamese people living, studying and working in Sydney.',
        ),
        _label(
          'Bạn có thể kết bạn, trò chuyện, hẹn hò, chia sẻ kinh nghiệm cuộc sống và tham gia các hoạt động cuối tuần cùng những người Việt khác.',
          'You can make friends, chat, date, share life experiences and join weekend activities with other Vietnamese members.',
        ),
        _label(
          'Sau khi tham gia, bạn sẽ được trò chuyện với các thành viên khác trong khu vực Sydney và mở rộng các mối quan hệ một cách tự nhiên.',
          'After joining, you can chat with members in the Sydney area and build meaningful connections naturally.',
        ),
      ];

    case 'melbourne_vietnamese':
      return [
        _label(
          'Đây là cộng đồng dành cho người Việt tại Melbourne muốn giao lưu, kết bạn và mở rộng các mối quan hệ.',
          'This community is for Vietnamese people in Melbourne who want to meet new friends and build connections.',
        ),
        _label(
          'Bạn có thể chia sẻ kinh nghiệm cuộc sống, công việc, học tập và tham gia các buổi gặp mặt cùng cộng đồng.',
          'You can share experiences about life, work, study and join local gatherings with the community.',
        ),
        _label(
          'Sau khi tham gia, bạn có thể trò chuyện với những người Việt khác trong khu vực Melbourne và kết nối dễ dàng hơn.',
          'After joining, you can chat with other Vietnamese members in Melbourne and connect more easily.',
        ),
      ];

    case 'queensland_vietnamese':
      return [
        _label(
          'Đây là cộng đồng người Việt tại Queensland dành cho những ai muốn kết bạn, giao lưu và tìm kiếm các mối quan hệ phù hợp.',
          'This Vietnamese community in Queensland is for people who want to make friends, socialize and build meaningful relationships.',
        ),
        _label(
          'Bạn có thể tham gia các cuộc trò chuyện, chia sẻ hoạt động địa phương và kết nối với những người sống gần bạn.',
          'You can join discussions, share local activities and connect with people living near you.',
        ),
        _label(
          'Sau khi tham gia, bạn sẽ có cơ hội gặp gỡ và trò chuyện với cộng đồng người Việt tại Queensland.',
          'After joining, you will have the opportunity to meet and chat with Vietnamese members across Queensland.',
        ),
      ];

    case 'perth_vietnamese':
      return [
        _label(
          'Đây là cộng đồng dành cho người Việt tại Perth muốn giao lưu, kết bạn và xây dựng các mối quan hệ lâu dài.',
          'This community is for Vietnamese people in Perth who want to socialize, make friends and build long-term relationships.',
        ),
        _label(
          'Bạn có thể trò chuyện, chia sẻ kinh nghiệm cuộc sống và tham gia các hoạt động cộng đồng cùng những thành viên khác.',
          'You can chat, share life experiences and take part in community activities with other members.',
        ),
        _label(
          'Sau khi tham gia, bạn sẽ được kết nối với cộng đồng người Việt tại Perth trong môi trường thân thiện và tích cực.',
          'After joining, you will connect with the Vietnamese community in Perth in a friendly and welcoming environment.',
        ),
      ];

    default:
      return [
        _label(
          'Sau khi tham gia, bạn có thể trò chuyện với các thành viên khác và cùng tham gia các hoạt động phù hợp với chủ đề của nhóm.',
          'After joining, you can chat with other members and take part in activities related to the group theme.',
        ),
      ];
  }
}

  Widget _buildGroupDescription() {
    final paragraphs = _groupIntroParagraphs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((text) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            text,
            softWrap: true,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: Color(0xFF666666),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    if (!_hasJoinedGroup) {
      return SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: (_isProcessing || _purchasePending)
              ? null
              : _startAppleRenewFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5D74D3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: (_isProcessing || _purchasePending)
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _label('Tham gia ngay', 'Join now'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      );
    }

    if (!_isActive) {
      return SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: (_isProcessing || _purchasePending)
              ? null
              : _startAppleRenewFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE86E8D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: (_isProcessing || _purchasePending)
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _label('Gia hạn ngay', 'Renew now'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_isProcessing || _purchasePending) ? null : _openChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D74D3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _label('Vào nhóm chat', 'Open group chat'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_isProcessing || _purchasePending)
                  ? null
                  : _startAppleRenewFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE86E8D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _purchasePending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _label('Gia hạn ngay', 'Renew now'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.group.title(isVi);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
  backgroundColor: Colors.white,
  elevation: 0,
  foregroundColor: const Color(0xFF6D6D6D),
  centerTitle: true,
  title: Text(
    title,
    textAlign: TextAlign.center,
    maxLines: 2,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 16,
      color: Color(0xFF555555),
    ),
  ),
),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFDDEA),
              Color(0xFFFFEFF5),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _handleGroupImageTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            Image.asset(
                              widget.group.imageAsset,
                              height: 260,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  height: 260,
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    widget.group.icon,
                                    size: 60,
                                    color: const Color(0xFF6F72C9),
                                  ),
                                );
                              },
                            ),
                            if (_isActive)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _label('Xem nhóm', 'View group'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
  title,
  textAlign: TextAlign.center,
  maxLines: 2,
  style: const TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: Color(0xFF333333),
  ),
),
                          const SizedBox(height: 8),
                          Text(
                            widget.group.subtitle(isVi),
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _isActive
                                  ? const Color(0xFFEAF8F0)
                                  : const Color(0xFFFFF1F1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isActive
                                      ? Icons.verified_rounded
                                      : Icons.access_time_rounded,
                                  color: _isActive
                                      ? const Color(0xFF2E9B63)
                                      : const Color(0xFFE05A5A),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _statusText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _isActive
                                          ? const Color(0xFF2E9B63)
                                          : const Color(0xFFE05A5A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_membershipData != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _expiryLineText(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (_membershipData != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _isActive
                                  ? _label(
                                      'Còn ${_daysLeft()} ngày',
                                      '${_daysLeft()} days left',
                                    )
                                  : _label(
                                      'Đã hết hạn',
                                      'Expired',
                                    ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isActive
                                    ? (_daysLeft() <= 3
                                        ? Colors.orange
                                        : const Color(0xFF2E9B63))
                                    : const Color(0xFFE05A5A),
                              ),
                            ),
                          ],
                          if (_isActive && _daysLeft() <= 3) ...[
                            const SizedBox(height: 6),
                            Text(
                              _label(
                                '⚠️ Gia hạn sớm để không bị gián đoạn',
                                '⚠️ Renew soon to avoid interruption',
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              const Icon(
                                Icons.local_offer_outlined,
                                color: Color(0xFF6F72C9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _priceText(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6F72C9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildGroupDescription(),
                          const SizedBox(height: 22),
                          _buildActionButtons(),
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

class _ActiveGroupOverviewPage extends StatelessWidget {
  final String languageCode;
  final DatingGroupItem group;
  final bool isVi;
  final bool isActive;
  final String statusText;
  final String expiryText;
  final String expiryLineText;
  final int daysLeft;
  final String priceText;
  final List<String> descriptionParagraphs;
  final bool isProcessing;
  final bool purchasePending;
  final VoidCallback onOpenChat;
  final VoidCallback onRenew;

  const _ActiveGroupOverviewPage({
    required this.languageCode,
    required this.group,
    required this.isVi,
    required this.isActive,
    required this.statusText,
    required this.expiryText,
    required this.expiryLineText,
    required this.daysLeft,
    required this.priceText,
    required this.descriptionParagraphs,
    required this.isProcessing,
    required this.purchasePending,
    required this.onOpenChat,
    required this.onRenew,
  });

  String _label(String vi, String en) => isVi ? vi : en;

  @override
  Widget build(BuildContext context) {
    final title = group.title(isVi);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF6D6D6D),
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF555555),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFDDEA),
              Color(0xFFFFEFF5),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  group.imageAsset,
                  height: 260,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      height: 260,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: Icon(
                        group.icon,
                        size: 60,
                        color: const Color(0xFF6F72C9),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
  title,
  textAlign: TextAlign.center,
  maxLines: 2,
  style: const TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: Color(0xFF333333),
  ),
),
                    const SizedBox(height: 8),
                    Text(
                      group.subtitle(isVi),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFEAF8F0)
                            : const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.verified_rounded
                                : Icons.access_time_rounded,
                            color: isActive
                                ? const Color(0xFF2E9B63)
                                : const Color(0xFFE05A5A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? const Color(0xFF2E9B63)
                                    : const Color(0xFFE05A5A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      expiryLineText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF555555),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isActive
                          ? _label(
                              'Còn $daysLeft ngày',
                              '$daysLeft days left',
                            )
                          : _label(
                              'Đã hết hạn',
                              'Expired',
                            ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? (daysLeft <= 3
                                ? Colors.orange
                                : const Color(0xFF2E9B63))
                            : const Color(0xFFE05A5A),
                      ),
                    ),
                    if (isActive && daysLeft <= 3) ...[
                      const SizedBox(height: 6),
                      Text(
                        _label(
                          '⚠️ Gia hạn sớm để không bị gián đoạn',
                          '⚠️ Renew soon to avoid interruption',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          color: Color(0xFF6F72C9),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          priceText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6F72C9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: descriptionParagraphs.map((text) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            text,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                              color: Color(0xFF666666),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: (isProcessing || purchasePending)
                                  ? null
                                  : onOpenChat,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5D74D3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _label('Vào nhóm chat', 'Open group chat'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isProcessing ? null : onRenew,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE86E8D),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: purchasePending
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _label('Gia hạn ngay', 'Renew now'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
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