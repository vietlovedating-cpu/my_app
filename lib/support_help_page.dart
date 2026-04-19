import 'package:flutter/material.dart';
import 'faq_page.dart';
import 'contact_support_page.dart';
import 'safety_tips_page.dart';
import 'app_version_page.dart';
class SupportHelpPage extends StatelessWidget {
  final String languageCode;

  const SupportHelpPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  Widget _item({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('Hỗ trợ & Trợ giúp', 'Support & Help')),
      ),
      body: Column(
        children: [
          _item(
            icon: Icons.support_agent,
            title: _tr('Liên hệ hỗ trợ', 'Contact Support'),
            subtitle: _tr(
              'Liên hệ đội ngũ hỗ trợ',
              'Contact our support team',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ContactSupportPage(languageCode: languageCode),
                ),
              );
            },
          ),
          _item(
            icon: Icons.help_outline,
            title: _tr('Câu hỏi thường gặp', 'FAQ'),
            subtitle: _tr(
              'Các câu hỏi phổ biến',
              'Frequently asked questions',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FAQPage(languageCode: languageCode),
                ),
              );
            },
          ),
          _item(
            icon: Icons.shield_outlined,
            title: _tr('An toàn hẹn hò', 'Safety Tips'),
            subtitle: _tr(
              'Hướng dẫn an toàn',
              'Stay safe while dating',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SafetyTipsPage(languageCode: languageCode),
                ),
              );
            },
          ),
          _item(
            icon: Icons.info_outline,
            title: _tr('Phiên bản', 'App Version'),
            subtitle: '1.0.0',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AppVersionPage(languageCode: languageCode),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}