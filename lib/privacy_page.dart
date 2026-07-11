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
Privacy Policy – VietLoveDating

Your privacy is important to us. This Privacy Policy explains how we collect, use, and protect your information when you use VietLoveDating.

1. Information We Collect
We collect information you provide when signing up, including your name, email, phone number, profile details, photos, and preferences. We may also collect messages and interactions within the app.

2. How We Use Information
We use your information to:
- Create and manage your account
- Provide matching and communication features
- Improve user experience
- Ensure safety and prevent fraud

3. Third-Party Services
We use trusted services such as Firebase (Google) to store and process data securely.

4. Data Sharing
We do NOT sell your personal data. We may share information only when necessary for:
- App functionality
- Safety and moderation
- Legal requirements

5. User Interactions
Messages and interactions may be reviewed where necessary for safety, moderation, and legal compliance.

6. Data Retention
We keep your data while your account is active. You may request deletion of your account and data at any time.

7. Account Control
You can update or delete your account at any time by contacting us or using in-app features.

8. Security
We apply reasonable security measures to protect your data, but no system is completely secure.

9. Age Requirement
This app is for users aged 18 and above only.

10. Changes
We may update this policy at any time. Continued use means you accept updates.

11. Contact
If you have any questions, contact us at:
Contact: info@vietlovedating.com
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