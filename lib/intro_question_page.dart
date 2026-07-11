import 'package:flutter/material.dart';
import 'place_you_call_home_page.dart';

class IntroPage extends StatefulWidget {
  final String languageCode;
  final String firstName;

  const IntroPage({
    super.key,
    required this.languageCode,
    required this.firstName,
  });

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_heartController);

    _heartController.repeat();
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.languageCode == 'vi';

    final titleText =
        isVi ? 'Chào ${widget.firstName}' : 'Hi, ${widget.firstName}';

    final introText = isVi
        ? 'Chào mừng bạn đến với Viet Love, nơi những trái tim tìm thấy nhau. Hãy bắt đầu hành trình gặp gỡ một người thật sự thấu hiểu bạn.'
        : 'Welcome to Viet Love, where hearts find each other. Let’s begin your journey to meet someone who truly understands you.';

    final buttonText = isVi ? 'Tiếp tục' : 'Continue';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: child,
                          );
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF5C93).withOpacity(0.10),
                              ),
                            ),
                            Container(
                              width: 105,
                              height: 105,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF5C93).withOpacity(0.14),
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xFFFF7AA8),
                                    Color(0xFFE91E63),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds);
                              },
                              child: const Icon(
                                Icons.favorite,
                                size: 72,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        titleText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F5BD5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        introText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.favorite, color: Color(0xFFFF8FB1), size: 16),
                          SizedBox(width: 8),
                          Icon(Icons.favorite, color: Color(0xFFFF5C93), size: 20),
                          SizedBox(width: 8),
                          Icon(Icons.favorite, color: Color(0xFFFF8FB1), size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaceYouCallHomePage(
                            languageCode: widget.languageCode,
                            firstName: widget.firstName,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}