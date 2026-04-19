import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  final String languageCode;

  const FAQPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  List<Map<String, String>> get faqs => [
        {
          'q_vi': 'Tôi không nhận được mã OTP?',
          'q_en': 'I did not receive the OTP code.',
          'a_vi':
              'Vui lòng kiểm tra lại số điện thoại, kết nối mạng và thư mục Spam. Bạn có thể bấm “Gửi lại mã” sau 60 giây.',
          'a_en':
              'Please check your phone number, network connection, and Spam folder. You can tap “Resend code” after 60 seconds.',
        },
        {
          'q_vi': 'Làm sao đổi thông tin hồ sơ?',
          'q_en': 'How do I edit my profile?',
          'a_vi':
              'Vào “Hồ sơ của tôi” → “Sửa hồ sơ” để cập nhật thông tin.',
          'a_en':
              'Go to “My Profile” → “Edit Profile” to update your information.',
        },
        {
          'q_vi': 'Làm sao xoá tài khoản?',
          'q_en': 'How do I delete my account?',
          'a_vi':
              'Vào “Tài khoản” → “Xoá tài khoản”. Lưu ý hành động này không thể hoàn tác.',
          'a_en':
              'Go to “Account” → “Delete Account”. This action cannot be undone.',
        },
        {
          'q_vi': 'Tôi không xác minh được email?',
          'q_en': 'I cannot verify my email.',
          'a_vi':
              'Kiểm tra thư mục Spam hoặc bấm “Gửi lại email xác minh”.',
          'a_en':
              'Check your Spam folder or tap “Resend verification email”.',
        },
        {
          'q_vi': 'Tôi không nhận được mã xác minh số điện thoại?',
          'q_en': 'I did not receive the phone verification code.',
          'a_vi':
              'Hãy đảm bảo số điện thoại của bạn chính xác và có tín hiệu mạng. Vui lòng thử lại sau vài phút.',
          'a_en':
              'Make sure your phone number is correct and has network signal. Please try again after a few minutes.',
        },
        {
          'q_vi': 'Tại sao tôi không có match?',
          'q_en': 'Why am I not getting matches?',
          'a_vi':
              'Hãy cập nhật hồ sơ rõ ràng, thêm ảnh đẹp và mở rộng phạm vi tìm kiếm để tăng cơ hội match.',
          'a_en':
              'Improve your profile, add quality photos, and expand your search range to increase your chances of getting matches.',
        },
        {
          'q_vi': 'Tại sao tôi không gửi được tin nhắn?',
          'q_en': 'Why can’t I send messages?',
          'a_vi':
              'Bạn chỉ có thể nhắn tin khi đã match với người đó. Nếu dùng gói miễn phí, bạn chỉ có thể gửi tối đa 3 tin nhắn và dùng hoa để bắt đầu.',
          'a_en':
              'You can only send messages after matching with that person. Free plan allows up to 3 messages and using flowers to start.',
        },
        {
          'q_vi': 'Làm sao báo cáo người dùng?',
          'q_en': 'How do I report a user?',
          'a_vi':
              'Vào hồ sơ người đó → bấm “Báo cáo” và chọn lý do.',
          'a_en':
              'Go to the user\'s profile → tap “Report” and select a reason.',
        },
        {
          'q_vi': 'Làm sao đổi ngôn ngữ?',
          'q_en': 'How do I change the language?',
          'a_vi':
              'Bấm “Tiếng Việt / English” ở góc màn hình trong phần đăng nhập.',
          'a_en':
              'Tap “Tiếng Việt / English” at the top of the login screen.',
        },
        {
          'q_vi': 'Thông tin của tôi có an toàn không?',
          'q_en': 'Is my information safe?',
          'a_vi':
              'Chúng tôi bảo vệ dữ liệu người dùng và không chia sẻ với bên thứ ba nếu không có sự cho phép hoặc yêu cầu pháp lý.',
          'a_en':
              'We protect user data and do not share it with third parties without permission or legal requirement.',
        },
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('Câu hỏi thường gặp', 'FAQ')),
      ),
      body: ListView(
        children: faqs.map((faq) {
          return ExpansionTile(
            title: Text(isVi ? faq['q_vi']! : faq['q_en']!),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(isVi ? faq['a_vi']! : faq['a_en']!),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}