import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MyGiftPage extends StatelessWidget {
  final String languageCode;

  const MyGiftPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

 Future<void> _openInstagram() async {
  final appUri = Uri.parse(
    'instagram://user?username=chichouse9999',
  );

  final webUri = Uri.parse(
    'https://www.instagram.com/chichouse9999',
  );

  try {
    if (await canLaunchUrl(appUri)) {
      await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    await launchUrl(
      webUri,
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    debugPrint('OPEN INSTAGRAM ERROR: $e');
  }
}

Future<void> _openBookingWebsite() async {
  final uri = Uri.parse(
    'https://chic-house-lash-beauty.square.site/',
  );

  try {
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    debugPrint('OPEN BOOKING WEBSITE ERROR: $e');
  }
}

String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFFE91E63),
      ),
    );
  }

  Widget _buildNoGift() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFFFCFE1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                size: 72,
                color: Color(0xFFE91E63),
              ),
              const SizedBox(height: 18),
              Text(
                _tr(
                  'Chưa có quà tặng',
                  'No gift available',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7A2E6E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _tr(
                  'Hiện tại bạn chưa có quà tặng nào.',
                  'You do not currently have a gift.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF76586A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLashVoucher({
    required String voucherCode,
    required String expiryDate,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFEDF5),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFFFBFD8),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCC3D7A).withOpacity(0.12),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 70,
              color: Color(0xFFE91E63),
            ),
            const SizedBox(height: 16),

            Text(
              '🎉 ${_tr(
                'Chào mừng bạn đến với VietLove Dating!',
                'Welcome to VietLove Dating!',
              )}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                height: 1.3,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7A2E6E),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _tr(
                'Giảm 50% tại',
                'Enjoy 50% OFF at',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4C3743),
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Chic House Lash & Beauty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE91E63),
              ),
            ),

            const SizedBox(height: 22),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 17,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFFC7DC),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _tr('Mã voucher', 'Voucher'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF93677E),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    voucherCode.isNotEmpty
                        ? voucherCode
                        : 'LASH----',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Color(0xFFB83280),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFE91E63),
                  size: 23,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '326 Illawarra Rd, Marrickville NSW 2204',
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF513D48),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

           Column(
  children: [
    InkWell(
      onTap: _openBookingWebsite,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const Icon(
              Icons.language_rounded,
              color: Color(0xFFE91E63),
              size: 23,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _tr(
                  '🌐 Đặt lịch trực tuyến',
                  '🌐 Book Online',
                ),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB83280),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              color: Color(0xFFB83280),
              size: 18,
            ),
          ],
        ),
      ),
    ),

    InkWell(
      onTap: _openInstagram,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const Icon(
              Icons.camera_alt_rounded,
              color: Color(0xFFE91E63),
              size: 23,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _tr(
                  '📷 Instagram: @chichouse9999',
                  '📷 Instagram: @chichouse9999',
                ),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB83280),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              color: Color(0xFFB83280),
              size: 18,
            ),
          ],
        ),
      ),
    ),
   ],
),

            const SizedBox(height: 18),

            Text(
              _tr(
                'Lịch hẹn chỉ được xác nhận sau khi Chic House Lash & Beauty xác nhận với bạn.',
                'Appointment is confirmed after confirmation by Chic House Lash & Beauty.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF76586A),
                fontStyle: FontStyle.italic,
              ),
            ),

            if (expiryDate.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _tr(
                    'Có giá trị đến: $expiryDate',
                    'Valid until: $expiryDate',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9C2859),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVipGift({
    required String expiryDate,
  }) {
    final expiryParts = expiryDate.split('/');

DateTime? expiry;

if (expiryParts.length == 3) {
  expiry = DateTime.tryParse(
    '${expiryParts[2]}-${expiryParts[1]}-${expiryParts[0]}',
  );
}

final now = DateTime.now();

final today = DateTime(
  now.year,
  now.month,
  now.day,
);

final isExpired =
    expiry != null &&
    today.isAfter(expiry);
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFFE8F2),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFFFBFD8),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCC3D7A).withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 76,
                color: Color(0xFFE91E63),
              ),
              const SizedBox(height: 18),

              Text(
                '🎉 ${_tr(
                  'Chào mừng bạn đến với VietLove Dating!',
                  'Welcome to VietLove Dating!',
                )}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7A2E6E),
                ),
              ),

              const SizedBox(height: 20),

             Text(
  _tr(
    isExpired
        ? 'Quà VIP của bạn'
        : 'Bạn đã nhận được',
    isExpired
        ? 'Your VIP Gift'
        : 'You have received',
  ),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF76586A),
                ),
              ),

              const SizedBox(height: 8),

             Text(
  _tr(
    isExpired
        ? 'VIP ĐÃ HẾT HẠN'
        : '2 TUẦN VIP MIỄN PHÍ',
    isExpired
        ? 'VIP EXPIRED'
        : '2 WEEKS FREE VIP',
  ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE91E63),
                ),
              ),

              const SizedBox(height: 18),

             Text(
  _tr(
    isExpired
        ? 'Quà VIP miễn phí này đã hết hạn. Cảm ơn bạn đã tham gia VietLove Dating!'
        : 'Quyền lợi VIP đã được tự động kích hoạt trên tài khoản của bạn.',
    isExpired
        ? 'Your free VIP gift has expired. Thank you for being part of VietLove Dating!'
        : 'Your VIP membership has already been activated.',
  ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4652),
                ),
              ),

              if (expiryDate.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4EF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                  _tr(
  isExpired
      ? 'VIP đã hết hạn vào: $expiryDate'
      : 'VIP có giá trị đến: $expiryDate',
  isExpired
      ? 'VIP expired on: $expiryDate'
      : 'VIP valid until: $expiryDate',
),
                 style: TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w800,
  color: isExpired
      ? Colors.red
      : const Color(0xFF9C2859),
),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7FB),
        elevation: 0,
        foregroundColor: const Color(0xFF7A2E6E),
        centerTitle: true,
        title: Text(
          _tr('Quà của bạn', 'Your Gift'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A2E6E),
          ),
        ),
      ),
      body: user == null
          ? _buildNoGift()
          : StreamBuilder<
              DocumentSnapshot<Map<String, dynamic>>
            >(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return _buildLoading();
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  return _buildNoGift();
                }

                final data =
                    snapshot.data!.data() ??
                    <String, dynamic>{};

                final welcomeGiftGranted =
                    data['welcomeGiftGranted'] == true;

                if (!welcomeGiftGranted) {
                  return _buildNoGift();
                }

                final giftType =
                    (data['welcomeGiftType'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();

                if (giftType == 'lash' ||
                    giftType == 'lash_voucher') {
                  final voucherCode =
                      (data['lashVoucherCode'] ??
                              data['welcomeGiftCode'] ??
                              '')
                          .toString()
                          .trim();

                  final expiryDate = _formatDate(
                    data['voucherExpiresAt'] ??
                        data['welcomeGiftExpiresAt'],
                  );

                  return _buildLashVoucher(
                    voucherCode: voucherCode,
                    expiryDate: expiryDate,
                  );
                }

                if (giftType == 'vip' ||
                    giftType == 'vip_14_days') {
                  final expiryDate = _formatDate(
                    data['vipGiftExpiresAt'] ??
                        data['vipExpiresAt'] ??
                        data['welcomeGiftExpiresAt'],
                  );

                  return _buildVipGift(
                    expiryDate: expiryDate,
                  );
                }

                return _buildNoGift();
              },
            ),
    );
  }
}