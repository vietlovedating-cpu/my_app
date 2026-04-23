import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

    switch (widget.group.id) {
      case 'weekend_coffee':
        return '\$24.99 / 1 month';
      case 'hiking_camping':
        return '\$24.99 / 1 month';
      case 'speed_dating':
        return '\$49.99 / 1 month';
      case 'gym_fitness':
        return '\$24.99 / 1 month';
      default:
        return '\$24.99 / 1 month';
    }
  }

  double _groupPrice() {
    switch (widget.group.id) {
      case 'weekend_coffee':
        return 24.99;
      case 'hiking_camping':
        return 24.99;
      case 'speed_dating':
        return 49.99;
      case 'gym_fitness':
        return 24.99;
      default:
        return 24.99;
    }
  }

  String? _productId() {
    switch (widget.group.id) {
      case 'weekend_coffee':
        return 'group.weekend_coffee.monthly.v2';
      case 'hiking_camping':
        return 'group.hiking_camping.monthly';
      case 'speed_dating':
        return 'group.speed_dating.monthly';
      case 'gym_fitness':
        return 'group.gym_fitness.monthly';
      default:
        return null;
    }
  }

  Future<void> _joinOrRenewMembership() async {
    final user = currentUser;
    if (user == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final firstName = (userData['firstName'] ?? '').toString().trim();
      final mainPhotoUrl = (userData['mainPhotoUrl'] ?? '').toString().trim();

      final now = DateTime.now();
      final existingExpiresAt = _membershipData?['expiresAt'] as Timestamp?;
      final existingDate = existingExpiresAt?.toDate();

      final baseDate = (existingDate != null && existingDate.isAfter(now))
          ? existingDate
          : now;

      final newExpiresAt = baseDate.add(const Duration(days: 30));

      await _memberDocRef.set({
        'userId': user.uid,
        'email': user.email,
        'uid': user.uid,
        'firstName': firstName,
        'mainPhotoUrl': mainPhotoUrl,
        'joinedAt': _membershipData?['joinedAt'] ?? Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(newExpiresAt),
        'expiredHandled': false,
        'reminder7dSent': false,
        'reminder3dSent': false,
        'membershipActive': true,
        'planType': '1_month',
        'price': _groupPrice(),
        'currency': 'AUD',
        'groupId': widget.group.id,
        'groupTitle': widget.group.title(isVi),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadMembership();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Đã cập nhật gói nhóm thành công',
              'Group plan updated successfully',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Không thể xử lý gói nhóm. Vui lòng thử lại.',
              'Could not process the group plan. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
    if (_isActive) {
      _openActiveGroupPage();
    }
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
      _purchasePending = true;
    });

    final response = await _inAppPurchase.queryProductDetails({productId});

    if (response.error != null || response.productDetails.isEmpty) {
      if (!mounted) return;
      setState(() {
        _purchasePending = false;
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

    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _onPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (mounted) {
          setState(() {
            _purchasePending = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _purchasePending = false;
          });
        }

        if (purchaseDetails.status == PurchaseStatus.error) {
          if (!mounted) continue;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _label(
                  'Thanh toán chưa thành công. Vui lòng thử lại.',
                  'Payment was not successful. Please try again.',
                ),
              ),
            ),
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _joinOrRenewMembership();

          if (!mounted) continue;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _label(
                  'Gia hạn thành công 🎉',
                  'Renewal successful 🎉',
                ),
              ),
            ),
          );
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
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
      case 'weekend_coffee':
        return [
          _label(
            'Đây là không gian dành cho những ai thích cà phê, trò chuyện nhẹ nhàng và gặp gỡ cuối tuần trong không khí thoải mái.',
            'This is a space for people who enjoy coffee, relaxed conversations, and casual weekend meetups in a comfortable atmosphere.',
          ),
          _label(
            'Bạn có thể cùng mọi người khám phá quán mới, tâm sự những điều đời thường và tạo nên những kết nối tự nhiên.',
            'You can explore new cafes together, share everyday moments, and build natural connections.',
          ),
          _label(
            'Sau khi tham gia, bạn sẽ được chat cùng các thành viên khác, làm quen một cách nhẹ nhàng, thoải mái và cùng nhau hẹn những buổi cà phê hoặc gặp gỡ cuối tuần nếu phù hợp.',
            'After joining, you can chat with other members, get to know each other naturally, and arrange coffee catch-ups or weekend meetups when it feels right.',
          ),
        ];

      case 'hiking_camping':
        return [
          _label(
            'Đây là nhóm dành cho những ai yêu thiên nhiên, thích vận động và muốn cùng nhau tham gia các chuyến hiking hoặc camping cuối tuần.',
            'This group is for people who love nature, enjoy being active, and want to join hiking or camping trips on weekends.',
          ),
          _label(
            'Bạn sẽ có cơ hội gặp gỡ những người cùng sở thích, lên kế hoạch cho các chuyến đi vui vẻ và năng động.',
            'You will have the chance to meet others with similar interests and plan fun, energetic outdoor adventures together.',
          ),
          _label(
            'Sau khi tham gia, bạn có thể trò chuyện với các thành viên khác, chia sẻ kinh nghiệm đi bộ đường dài, cắm trại và cùng nhau lên lịch cho những chuyến đi sắp tới.',
            'After joining, you can chat with other members, share hiking or camping experiences, and plan upcoming outdoor trips together.',
          ),
        ];

      case 'speed_dating':
        return [
          _label(
            'Đây là nhóm phù hợp cho những ai muốn mở rộng cơ hội gặp gỡ, trò chuyện và kết nối trong các buổi speed dating hoặc sự kiện giao lưu.',
            'This group is ideal for those who want to expand their opportunities to meet, chat, and connect through speed dating sessions or social events.',
          ),
          _label(
            'Môi trường ở đây thân thiện, cởi mở và phù hợp để làm quen một cách nhanh chóng nhưng vẫn tự nhiên.',
            'The atmosphere is friendly, open, and great for getting to know new people in a natural way.',
          ),
          _label(
            'Sau khi tham gia, bạn có thể cập nhật thông tin event, trò chuyện với các thành viên khác trước khi gặp mặt và cảm thấy thoải mái hơn khi tham gia các buổi giao lưu.',
            'After joining, you can stay updated on events, chat with other members before meeting in person, and feel more comfortable joining social sessions.',
          ),
        ];

      case 'gym_fitness':
        return [
          _label(
            'Đây là nhóm dành cho những ai yêu thích gym, fitness và lối sống lành mạnh.',
            'This group is for people who enjoy gym, fitness, and a healthy lifestyle.',
          ),
          _label(
            'Bạn có thể cùng mọi người chia sẻ mục tiêu tập luyện, động viên nhau và hẹn các buổi tập hoặc hoạt động thể thao cuối tuần.',
            'You can share your workout goals, motivate each other, and arrange gym sessions or weekend fitness activities together.',
          ),
          _label(
            'Sau khi tham gia, bạn sẽ được chat cùng các thành viên khác, trao đổi kinh nghiệm tập luyện, chế độ ăn uống và tìm bạn đồng hành để duy trì động lực lâu dài.',
            'After joining, you can chat with other members, exchange workout and nutrition tips, and find a fitness buddy to stay motivated long term.',
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
                            style: const TextStyle(
                              fontSize: 21,
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
                      style: const TextStyle(
                        fontSize: 21,
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
                              onPressed: (isProcessing || purchasePending)
                                  ? null
                                  : onRenew,
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