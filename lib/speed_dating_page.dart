import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SpeedDatingPage extends StatelessWidget {
  final String languageCode;

  const SpeedDatingPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _label(String vi, String en) => isVi ? vi : en;

  Future<void> _openRegistrationLink(BuildContext context) async {
    final uri = Uri.parse(
      'https://vietlove-sydney-meetup.netlify.app/',
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(
              'Không thể mở trang đăng ký. Vui lòng thử lại.',
              'Could not open the registration page. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF6D6D6D),
        centerTitle: true,
        title: Text(
          _label(
            'VietLove Speed Dating',
            'VietLove Speed Dating',
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 54,
                  color: Color(0xFFE86E8D),
                ),
                const SizedBox(height: 14),
                Text(
                  _label(
                    '❤️ Bạn đang ở Úc?',
                    '❤️ Living in Australia?',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4C53D1),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _label(
                    'VietLove tổ chức các buổi Speed Dating hàng tháng dành cho người Việt độc thân tại nhiều thành phố như Sydney, Melbourne, Brisbane và các thành phố khác tại Úc.',
                    'VietLove hosts monthly Speed Dating events for Vietnamese singles in cities across Australia, including Sydney, Melbourne, Brisbane and more.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.55,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _label(
                    'Hãy cho bản thân cơ hội gặp gỡ một người thực sự trân trọng bạn',
                    'Give yourself a chance to meet someone who truly values you',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _label(
                    'Hãy tham gia VietLove Speed Dating để gặp gỡ trực tiếp những người Việt độc thân cùng văn hoá, cùng ngôn ngữ và đang tìm kiếm một mối quan hệ nghiêm túc.',
                    'Join VietLove Speed Dating to meet Vietnamese singles in person who share your culture, language and are looking for a serious relationship.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.55,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _label(
                    '✨ Trò chuyện thật',
                    '✨ Real conversations',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                  ),
                ),
                Text(
                  _label(
                    '✨ Kết nối thật',
                    '✨ Real connections',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                  ),
                ),
                Text(
                  _label(
                    '✨ Không gian an toàn và thân thiện',
                    '✨ A safe and friendly environment',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _openRegistrationLink(context),
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      _label(
                        'Đăng ký ngay',
                        'Register Now',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE86E8D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}