import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  final String languageCode;

  const PrivacyPage({
    super.key,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = languageCode == 'vi';

    return Scaffold(
      appBar: AppBar(
        title: Text(isVi ? 'Chính sách quyền riêng tư' : 'Privacy Policy'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          isVi ? _privacyVi : _privacyEn,
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

const String _privacyEn = '''
Privacy Policy

Your privacy is important to us. This policy explains how we collect and use your information:

We collect basic information you provide during sign-up, such as name, email, and profile details.

Your information is used only to operate and improve the app experience.

We do not sell or share your personal data with third parties for marketing purposes.

Messages and interactions may be reviewed only for moderation, safety, or legal reasons.

You may request to update or delete your account and personal data at any time.

We apply reasonable security measures to protect your information.

By using this app, you agree to this Privacy Policy.
''';

const String _privacyVi = '''
Chính sách quyền riêng tư

Chúng tôi tôn trọng và bảo vệ quyền riêng tư của bạn. Chính sách này giải thích cách chúng tôi thu thập và sử dụng dữ liệu:

Chúng tôi thu thập các thông tin cơ bản khi bạn đăng ký, bao gồm tên, email và thông tin hồ sơ.

Dữ liệu được sử dụng nhằm vận hành và cải thiện trải nghiệm ứng dụng.

Chúng tôi không bán hoặc chia sẻ dữ liệu cá nhân của bạn cho bên thứ ba vì mục đích thương mại.

Tin nhắn và tương tác chỉ được xem xét trong trường hợp cần kiểm duyệt, đảm bảo an toàn hoặc theo yêu cầu pháp lý.

Bạn có quyền yêu cầu chỉnh sửa hoặc xóa tài khoản và dữ liệu cá nhân của mình.

Chúng tôi áp dụng các biện pháp bảo mật hợp lý để bảo vệ thông tin người dùng.

Việc sử dụng ứng dụng đồng nghĩa với việc bạn đồng ý với Chính sách quyền riêng tư này.
''';