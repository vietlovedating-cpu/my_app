import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  bool _isBuying = false;
  String selectedPlanId = '1_week';

  bool get isVi => widget.languageCode == 'vi';

  String _label(String vi, String en) => isVi ? vi : en;

  List<_VipPlan> get plans => [
        _VipPlan(
          id: '1_week',
          titleVi: '1 tuần',
          titleEn: '1 week',
          priceTextVi: '\$14.99/tuần',
          priceTextEn: '\$14.99/week',
          monthsToAdd: 0,
          daysToAdd: 7,
        ),
        _VipPlan(
          id: '1_month',
          titleVi: '1 tháng',
          titleEn: '1 month',
          priceTextVi: '\$29.99/tháng',
          priceTextEn: '\$29.99/month',
          monthsToAdd: 1,
          daysToAdd: 0,
        ),
        _VipPlan(
          id: '3_months',
          titleVi: '3 tháng',
          titleEn: '3 mths',
          priceTextVi: '\$24.99/tháng',
          priceTextEn: '\$24.99/month',
          monthsToAdd: 3,
          daysToAdd: 0,
        ),
        _VipPlan(
          id: '6_months',
          titleVi: '6 tháng',
          titleEn: '6 months',
          priceTextVi: '\$19.99/tháng',
          priceTextEn: '\$19.99/month',
          monthsToAdd: 6,
          daysToAdd: 0,
        ),
      ];

  _VipPlan get selectedPlan =>
      plans.firstWhere((item) => item.id == selectedPlanId);

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
                          ? 'Bạn đã chọn gói VIP ${plan.titleVi} ${plan.priceTextVi}'
                          : 'You selected VIP ${plan.titleEn} ${plan.priceTextEn}',
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
                          ? 'Bạn đã chọn gói VIP ${plan.titleVi} cho ${plan.priceTextVi}.'
                          : 'You selected VIP ${plan.titleEn} for ${plan.priceTextEn}.',
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isBuying = true;
    });

    try {
      final now = DateTime.now();
      final expiresAt = DateTime(
        now.year,
        now.month + plan.monthsToAdd,
        now.day + plan.daysToAdd,
        now.hour,
        now.minute,
        now.second,
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isVip': true,
        'vipUnlocked': true,
        'membership': 'vip',
        'plan': 'vip',
        'subscriptionType': plan.id,
        'vipPlanId': plan.id,
        'vipPlanTitleVi': plan.titleVi,
        'vipPlanTitleEn': plan.titleEn,
        'vipPriceTextVi': plan.priceTextVi,
        'vipPriceTextEn': plan.priceTextEn,
        'vipPurchasedAt': FieldValue.serverTimestamp(),
        'vipExpiresAt': Timestamp.fromDate(expiresAt),
      }, SetOptions(merge: true));

      if (!mounted) return;

      await widget.onPurchaseSuccess();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Mua VIP thành công. Bộ lọc VIP đã được mở khóa.',
              'VIP purchase successful. VIP filters are now unlocked.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVi ? 'Mua VIP thất bại: $e' : 'VIP purchase failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBuying = false;
        });
      }
    }
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
        Navigator.pop(context); // 👈 quay về trang trước
      },
    ),
  ),

  body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                                onTap: _isBuying
                                    ? null
                                    : () {
                                        setState(() {
                                          selectedPlanId = item.id;
                                        });
                                        _confirmPurchase(item);
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 14,
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
                                    children: [
                                      Text(
                                        isVi ? item.titleVi : item.titleEn,
                                        textAlign: TextAlign.center,
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
                                        isVi
                                            ? item.priceTextVi
                                            : item.priceTextEn,
                                        textAlign: TextAlign.center,
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
                        'Unlock the full premium dating experience',
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
                        onPressed:
                            _isBuying ? null : () => _confirmPurchase(plan),
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
  final String titleVi;
  final String titleEn;
  final String priceTextVi;
  final String priceTextEn;
  final int monthsToAdd;
  final int daysToAdd;

  const _VipPlan({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.priceTextVi,
    required this.priceTextEn,
    required this.monthsToAdd,
    required this.daysToAdd,
  });
}