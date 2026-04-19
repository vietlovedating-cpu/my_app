import 'package:flutter/material.dart';

class SafetyTipsPage extends StatelessWidget {
  final String languageCode;

  const SafetyTipsPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  List<String> get _tipsVi => const [
        'Không gửi tiền cho người lạ.',
        'Không chia sẻ thông tin cá nhân quá sớm.',
        'Luôn gặp ở nơi công cộng trong lần gặp đầu tiên.',
        'Hãy thông báo cho bạn bè hoặc người thân biết trước khi đi gặp.',
        'Nếu bạn cảm thấy không an toàn, hãy rời đi ngay và chặn người đó.',
        'Không nhấn vào các đường link đáng ngờ do người lạ gửi.',
        'Báo cáo ngay những hành vi quấy rối, lừa đảo hoặc không phù hợp.',
      ];

  List<String> get _tipsEn => const [
        'Do not send money to strangers.',
        'Do not share personal information too early.',
        'Always meet in a public place for the first meeting.',
        'Tell a friend or family member before meeting someone.',
        'If you feel unsafe, leave immediately and block that person.',
        'Do not click suspicious links sent by strangers.',
        'Report any harassment, scam, or inappropriate behaviour immediately.',
      ];

  @override
  Widget build(BuildContext context) {
    final tips = isVi ? _tipsVi : _tipsEn;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8FB),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _tr('An toàn hẹn hò', 'Dating Safety Tips'),
          style: const TextStyle(
            color: Color(0xFF7A2E6E),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF7A2E6E)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.pink.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Colors.pink.shade400,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tips[index],
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}