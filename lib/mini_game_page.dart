import 'dart:math';

import 'package:flutter/material.dart';

import 'guess_game_page.dart';
import 'lucky_spin_page.dart';
import 'blind_date_quiz_page.dart';
import 'language_exchange_page_updated.dart';

class MiniGamePage extends StatefulWidget {
  final String languageCode;

  const MiniGamePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<MiniGamePage> createState() => _MiniGamePageState();
}

class _MiniGamePageState extends State<MiniGamePage>
    with TickerProviderStateMixin {
  late final AnimationController _guessAnimationController;
  late final AnimationController _spinAnimationController;
  late final AnimationController _blindDateAnimationController;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) {
    return isVi ? vi : en;
  }

  @override
  void initState() {
    super.initState();

    // Chuyển động nhẹ cho khung Guess.
    _guessAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Vòng quay Lucky Spin quay chậm liên tục.
    _spinAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _blindDateAnimationController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1800),
)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _guessAnimationController.dispose();
    _spinAnimationController.dispose();
    _blindDateAnimationController.dispose();
    super.dispose();
  }

  void _openGuessPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuessGamePage(
          languageCode: widget.languageCode,
        ),
      ),
    );
  }
void _openLuckySpinPage() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LuckySpinPage(
        languageCode: widget.languageCode,
      ),
    ),
  );
} 

 void _openBlindDateQuizPage() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlindDateQuizPage(
        languageCode: widget.languageCode,
      ),
    ),
  );
}
void _openLanguageExchangePage() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LanguageExchangePage(
        languageCode: widget.languageCode,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            18,
            20,
            18,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr(
                  'Chọn trò chơi',
                  'Choose a game',
                ),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7A2E6E),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _tr(
                  'Chơi game, khám phá điều bất ngờ và nhận phần thưởng.',
                  'Play, discover surprises and earn rewards.',
                ),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),

             // Language Exchange
_buildLanguageExchangeCard(),

const SizedBox(height: 20),

// Guess
_buildGuessCard(),

const SizedBox(height: 20),

// Lucky Spin
_buildLuckySpinCard(),

const SizedBox(height: 20),

// Blind Date Quiz
_buildBlindDateQuizCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuessCard() {
    return InkWell(
      onTap: _openGuessPage,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8D64E8),
              Color(0xFF6550C9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6550C9)
                  .withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -35,
              right: -25,
              child: Container(
                width: 135,
                height: 135,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Guess',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 33,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _tr(
                            'Đoán xem ai đã thích bạn.',
                            'Guess who liked you.',
                          ),
                          style: TextStyle(
                            color:
                                Colors.white.withOpacity(0.92),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _buildOpenButton(
                          _tr('Chơi ngay', 'Play now'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Hình chuyển động Guess
                  AnimatedBuilder(
                    animation:
                        _guessAnimationController,
                    builder: (context, child) {
                      final value =
                          _guessAnimationController.value;

                      final moveY =
                          sin(value * pi) * 10;

                      final rotation =
                          sin(value * pi * 2) * 0.05;

                      return Transform.translate(
                        offset: Offset(0, -moveY),
                        child: Transform.rotate(
                          angle: rotation,
                          child: child,
                        ),
                      );
                    },
                    child: _buildGuessMovingImage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessMovingImage() {
    return SizedBox(
      width: 125,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-30, 18),
            child: Transform.rotate(
              angle: -0.16,
              child: _buildMysteryCard(
                size: 78,
                opacity: 0.70,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(30, 18),
            child: Transform.rotate(
              angle: 0.16,
              child: _buildMysteryCard(
                size: 78,
                opacity: 0.70,
              ),
            ),
          ),
          _buildMysteryCard(
            size: 96,
            opacity: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildMysteryCard({
    required double size,
    required double opacity,
  }) {
    return Container(
      width: size,
      height: size * 1.25,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.50,
          height: size * 0.50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE4D9FF),
          ),
          child: Icon(
            Icons.question_mark_rounded,
            color: const Color(0xFF6550C9),
            size: size * 0.30,
          ),
        ),
      ),
    );
  }

  Widget _buildLuckySpinCard() {
    return InkWell(
      onTap: _openLuckySpinPage,
      borderRadius: BorderRadius.circular(28),
     child: Container(
  width: double.infinity,
 height: 235,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF729A),
              Color(0xFFE83D78),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE83D78)
                  .withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: -50,
              right: -35,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lucky Spin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                      Text(
  _tr(
    'Quay vòng quay và nhận quà.',
    'Spin the wheel and win rewards.',
  ),
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    color: Colors.white.withOpacity(0.92),
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  ),
),
                        const Spacer(),
                        _buildOpenButton(
                          _tr('Quay ngay', 'Spin now'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Vòng quay chuyển động
                  AnimatedBuilder(
                    animation:
                        _spinAnimationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle:
                            _spinAnimationController.value *
                                2 *
                                pi,
                        child: child,
                      );
                    },
                    child: const _SmallLuckyWheel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildBlindDateQuizCard() {
  return InkWell(
    onTap: _openBlindDateQuizPage,
    borderRadius: BorderRadius.circular(28),
    child: Container(
      width: double.infinity,
      height: 235,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF8A65),
            Color(0xFFFF5A7A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5A7A)
                .withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -35,
            right: -25,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blind Date Quiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _tr(
                          'Trả lời 7 câu hỏi và khám phá người phù hợp nhất hôm nay.',
                          'Answer 7 questions and discover your best match today.',
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const Spacer(),

                      _buildOpenButton(
                        _tr(
                          'Bắt đầu',
                          'Start',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                AnimatedBuilder(
                  animation:
                      _blindDateAnimationController,
                  builder: (context, child) {
                    final value =
                        _blindDateAnimationController.value;

                    final moveY =
                        sin(value * pi) * 9;

                    final scale =
                        1 + sin(value * pi) * 0.06;

                    return Transform.translate(
                      offset: Offset(0, -moveY),
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 95,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildLanguageExchangeCard() {
  return InkWell(
    onTap: _openLanguageExchangePage,
    borderRadius: BorderRadius.circular(28),
    child: Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5D74D3),
            Color(0xFF7E57C2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D74D3).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr(
                      'Trao đổi ngôn ngữ',
                      'Language Exchange',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _tr(
                      'Luyện tiếng Anh hoặc tiếng Việt và kết nối với mọi người trên toàn thế giới.',
                      'Practice English or Vietnamese and connect with people worldwide.',
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                  _buildOpenButton(
                    _tr('Khám phá', 'Explore'),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            const Icon(
              Icons.translate_rounded,
              size: 90,
              color: Colors.white,
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildOpenButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7A2E6E),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.arrow_forward_rounded,
            color: Color(0xFF7A2E6E),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _SmallLuckyWheel extends StatelessWidget {
  const _SmallLuckyWheel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: CustomPaint(
        painter: _SmallLuckyWheelPainter(),
        child: const Center(
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFFE83D78),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallLuckyWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFFD54F),
      Color(0xFF7E57C2),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFF7043),
      Color(0xFFEC407A),
      Color(0xFF26C6DA),
      Color(0xFFFFCA28),
    ];

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        min(size.width, size.height) / 2;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - 5,
    );

    final sectionAngle =
        (2 * pi) / colors.length;

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        rect,
        i * sectionAngle,
        sectionAngle,
        true,
        paint,
      );
    }

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(
      center,
      radius - 5,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}