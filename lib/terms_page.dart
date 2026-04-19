import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  final String languageCode;

  const TermsPage({
    super.key,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = languageCode == 'vi';

    return Scaffold(
      appBar: AppBar(
        title: Text(isVi ? 'Điều khoản sử dụng' : 'Terms & Conditions'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          isVi ? _termsVi : _termsEn,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

const String _termsEn = '''
Terms & Conditions

By using this application, you agree to the following terms:

This application is intended for users who are at least 18 years old.

Users are responsible for the accuracy of the information they provide.

Harassment, hate speech, spam, scams, or inappropriate content are strictly prohibited.

We reserve the right to review, suspend, or permanently ban any account that violates our rules, without prior notice.

We are not responsible for interactions, conversations, or relationships formed between users.

We may update these Terms & Conditions from time to time. Continued use of the app means you accept the updated terms.

If you do not agree with these terms, please do not use the application.
''';

const String _termsVi = '''
Điều khoản sử dụng

Khi sử dụng ứng dụng này, bạn đồng ý với các điều khoản sau:

Ứng dụng dành cho người dùng từ 18 tuổi trở lên.

Người dùng chịu trách nhiệm về tính chính xác của thông tin cá nhân đã cung cấp.

Nghiêm cấm các hành vi quấy rối, ngôn từ thù ghét, spam, lừa đảo hoặc nội dung không phù hợp.

Chúng tôi có quyền xem xét, tạm khóa hoặc chấm dứt tài khoản vi phạm mà không cần thông báo trước.

Chúng tôi không chịu trách nhiệm về các tương tác, cuộc trò chuyện hoặc mối quan hệ giữa các người dùng.

Điều khoản sử dụng có thể được cập nhật theo thời gian. Việc tiếp tục sử dụng ứng dụng đồng nghĩa với việc bạn chấp nhận các điều khoản mới.

Nếu bạn không đồng ý với các điều khoản này, vui lòng không sử dụng ứng dụng.
''';