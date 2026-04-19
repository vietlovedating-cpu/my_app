import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'login_page.dart';

class WelcomePage extends StatefulWidget {
  final String languageCode;
  final Function(String) onLanguageChanged;

  const WelcomePage({
    super.key,
    required this.languageCode,
    required this.onLanguageChanged,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late String languageCode;

  bool get isVi => languageCode == 'vi';

  @override
  void initState() {
    super.initState();

    languageCode = widget.languageCode;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant WelcomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.languageCode != widget.languageCode) {
      languageCode = widget.languageCode;
    }
  }

  void _changeLanguage(String lang) {
    if (languageCode == lang) return;

    setState(() {
      languageCode = lang;
    });

    widget.onLanguageChanged(lang);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _changeLanguage('vi'),
                        child: Text(
                          'Tiếng Việt',
                          style: TextStyle(
                            color:
                                languageCode == 'vi' ? Colors.pink : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _changeLanguage('en'),
                        child: Text(
                          'English',
                          style: TextStyle(
                            color:
                                languageCode == 'en' ? Colors.pink : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/images/couple.jpg',
                        width: double.infinity,
                        height: screenWidth < 420 ? 260 : 300,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      bottom: -28,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFE4EC),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.pink,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 46),
                Text(
                  isVi
                      ? 'Chào mừng đến VietLove Dating'
                      : 'Welcome to VietLove Dating',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isVi
                      ? 'Tìm người phù hợp, kết nối chân thật, trò chuyện an toàn.'
                      : 'Find meaningful matches, connect genuinely, and chat safely.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SignUpPage(
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
                    ),
                    child: Text(isVi ? 'Đăng ký' : 'Sign Up'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginPage(
                            initialLanguageCode: languageCode,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.pink),
                      foregroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(isVi ? 'Đăng nhập' : 'Login'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}