import 'dart:async';
import 'package:flutter/material.dart';
import 'welcome_page.dart';

class SplashPage extends StatefulWidget {
  final String languageCode;
  final Function(String) onLanguageChanged;

  const SplashPage({
    super.key,
    required this.languageCode,
    required this.onLanguageChanged,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 2), _goNext);
  }

  void _goNext() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomePage(
          languageCode: widget.languageCode,
          onLanguageChanged: widget.onLanguageChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel(); // 🔥 tránh memory leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF0F5),
              Color(0xFFFFFFFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite,
              size: 90,
              color: Colors.pink,
            ),
            const SizedBox(height: 20),
            const Text(
              'VietLove',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.pink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isVi
                  ? 'Kết nối người Việt xa xứ'
                  : 'Connect Vietnamese hearts abroad',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.pink),
          ],
        ),
      ),
    );
  }
}