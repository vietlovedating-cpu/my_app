import 'package:flutter/material.dart';
import 'home_page.dart';
import 'prompt_questions_page.dart';

class PromptIntroPage extends StatelessWidget {
  final String languageCode;

  const PromptIntroPage({
    super.key,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = languageCode == 'vi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8DCE5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.pink,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    Text(
                      isVi ? 'Thêm Prompt để hồ sơ nổi bật hơn' : 'Add prompts to make your profile stand out',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isVi
                          ? 'Chọn câu hỏi phù hợp, viết vài dòng về bản thân hoặc dùng AI hỗ trợ. Bạn cũng có thể sửa lại sau trong hồ sơ.'
                          : 'Choose questions that fit you, write a few lines about yourself, or use AI help. You can edit these later in your profile.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.45,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _FeatureRow(
                      icon: Icons.auto_awesome,
                      text: isVi ? '5 chủ đề lớn dễ chọn' : '5 major topics to choose from',
                    ),
                    const SizedBox(height: 10),
                    _FeatureRow(
                      icon: Icons.edit_note,
                      text: isVi ? 'Tự viết hoặc AI hỗ trợ' : 'Write yourself or get AI help',
                    ),
                    const SizedBox(height: 10),
                    _FeatureRow(
                      icon: Icons.person_outline,
                      text: isVi ? 'Người khác có thể hiểu bạn hơn' : 'People can get to know you better.',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PromptQuestionsPage(
                          languageCode: languageCode,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isVi ? 'Tiếp theo →' : 'Next →',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => HomePage(languageCode: languageCode),
                      ),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.pink,
                    side: const BorderSide(color: Colors.pink, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isVi ? 'Để sau' : 'Maybe later',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.pink, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}