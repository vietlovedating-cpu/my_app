import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactSupportPage extends StatefulWidget {
  final String languageCode;

  const ContactSupportPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    _emailController.text = currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final value = email.trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  String _supportEmailSubject() {
    return 'VietLove Dating Support';
  }

  String _supportEmailBody() {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'N/A';
    final userEmail = user?.email ?? _emailController.text.trim();

    if (isVi) {
      return '''
Xin chào VietLove Dating,

Tôi cần hỗ trợ về vấn đề sau:

[Nhập nội dung tại đây]

Thông tin tài khoản:
- User ID: $userId
- Email: $userEmail

Cảm ơn.
''';
    }

    return '''
Hello VietLove Dating,

I need help with the following issue:

[Enter your message here]

Account details:
- User ID: $userId
- Email: $userEmail

Thank you.
''';
  }

  String _whatsAppPrefilledMessage() {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'N/A';
    final userEmail = user?.email ?? _emailController.text.trim();

    if (isVi) {
      return '''
Xin chào VietLove Dating, tôi cần hỗ trợ.

User ID: $userId
Email: $userEmail

Vấn đề của tôi là:
''';
    }

    return '''
Hello VietLove Dating, I need support.

User ID: $userId
Email: $userEmail

My issue is:
''';
  }

  Future<void> _openEmailApp() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'vietlovedating@gmail.com',
      queryParameters: {
        'subject': _supportEmailSubject(),
        'body': _supportEmailBody(),
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        return;
      }

      final fallbackUri = Uri.parse('https://mail.google.com/');
      await launchUrl(
        fallbackUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Không thể mở email lúc này.',
              'Could not open email right now.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openWhatsApp() async {
    final bool? shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_tr('Thông báo', 'Notice')),
          content: Text(
            _tr(
              'Yêu cầu của bạn sẽ được phản hồi sớm. Bạn có muốn tiếp tục mở WhatsApp không?',
              'Your query will be answered shortly. Do you want to continue to WhatsApp?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('Huỷ', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('Tiếp tục', 'Continue')),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true) return;

    final encodedMessage = Uri.encodeComponent(_whatsAppPrefilledMessage());
    final whatsappUri = Uri.parse(
      'https://wa.me/61466708208?text=$encodedMessage',
    );

    try {
      await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      try {
        await launchUrl(whatsappUri);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'Không thể mở WhatsApp.',
                'Could not open WhatsApp.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _submitSupportRequest() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final contactEmail = _emailController.text.trim();
      final message = _messageController.text.trim();

      await FirebaseFirestore.instance.collection('support_requests').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'contactEmail': contactEmail,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'support',
        'status': 'new',
        'source': 'contact_support_page',
      });

      _messageController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Yêu cầu hỗ trợ đã được gửi thành công.',
              'Support request sent successfully.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Gửi yêu cầu thất bại. Vui lòng thử lại.',
              'Failed to send request. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pink.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.pink.shade50,
          child: Icon(icon, color: Colors.pink),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.pink.shade100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.pink.shade100),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(
          color: Color(0xFFE91E63),
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8FB),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _tr('Liên hệ hỗ trợ', 'Contact Support'),
          style: const TextStyle(
            color: Color(0xFF7A2E6E),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF7A2E6E),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildActionCard(
              icon: Icons.email_outlined,
              title: _tr('Email hỗ trợ', 'Email Support'),
              subtitle: 'vietlovedating@gmail.com',
              onTap: _openEmailApp,
            ),
            _buildActionCard(
              icon: Icons.chat_outlined,
              title: _tr('Hỗ trợ qua WhatsApp', 'WhatsApp Support'),
              subtitle: '+61 468 995 932',
              onTap: _openWhatsApp,
            ),
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink.shade50.withOpacity(0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pink.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.pink.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tr(
                        'Bạn có thể liên hệ với chúng tôi qua email, WhatsApp hoặc gửi yêu cầu trực tiếp bên dưới. Chúng tôi sẽ phản hồi sớm nhất có thể.',
                        'You can contact us by email, WhatsApp, or submit a support request below. We will reply as soon as possible.',
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.pink.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr('Gửi yêu cầu hỗ trợ', 'Send Support Request'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A2E6E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tr(
                        'Vui lòng nhập email và mô tả vấn đề bạn đang gặp phải.',
                        'Please enter your email and describe the issue you are facing.',
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        label: _tr('Email', 'Email'),
                        hint: _tr(
                          'Nhập email của bạn',
                          'Enter your email',
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return _tr(
                            'Vui lòng nhập email.',
                            'Please enter your email.',
                          );
                        }
                        if (!_isValidEmail(text)) {
                          return _tr(
                            'Email không hợp lệ.',
                            'Invalid email.',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 6,
                      decoration: _inputDecoration(
                        label: _tr('Nội dung', 'Message'),
                        hint: _tr(
                          'Nhập vấn đề bạn cần hỗ trợ',
                          'Describe the issue you need help with',
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return _tr(
                            'Vui lòng nhập nội dung.',
                            'Please enter your message.',
                          );
                        }
                        if (text.length < 6) {
                          return _tr(
                            'Nội dung quá ngắn.',
                            'Message is too short.',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _submitSupportRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.pink.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _tr('Gửi', 'Send'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}