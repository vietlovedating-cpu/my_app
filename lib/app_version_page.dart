import 'package:flutter/material.dart';

class AppVersionPage extends StatelessWidget {
  final String languageCode;

  const AppVersionPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8FB),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _tr('Phiên bản', 'App Version'),
          style: const TextStyle(
            color: Color(0xFF7A2E6E),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF7A2E6E)),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.pink.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black ,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 42,
                color: Colors.pink.shade400,
              ),
              const SizedBox(height: 14),
              Text(
                _tr('Phiên bản ứng dụng', 'App Version'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7A2E6E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1.0.0',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}