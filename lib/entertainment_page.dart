import 'package:flutter/material.dart';

import 'lucky_spin_page.dart';
import 'snake_game_page.dart';
import 'breakout_game_page.dart';
import 'tetris_game_page.dart';



class EntertainmentPage extends StatelessWidget {
  final String languageCode;

  const EntertainmentPage({
    super.key,
    required this.languageCode,
  });

  bool get isVi => languageCode == 'vi';

  String _tr(String vi, String en) {
    return isVi ? vi : en;
  }

  // ============================================================
  // LUCKY SPIN
  // ============================================================

  void _openLuckySpin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LuckySpinPage(
          languageCode: languageCode,
        ),
      ),
    );
  }

  // ============================================================
  // SNAKE
  // ============================================================

  void _openSnake(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SnakeGamePage(
          languageCode: languageCode,
        ),
      ),
    );
  }

  // ============================================================
  // BREAKOUT
  // ============================================================

  void _openBreakout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreakoutGamePage(
          languageCode: languageCode,
        ),
      ),
    );
  }

  // ============================================================
  // TETRIS
  // ============================================================

  void _openTetris(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TetrisGamePage(
          languageCode: languageCode,
        ),
      ),
    );
  }


  // ============================================================
  // NEON RUNNER
  // ============================================================


  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFFF8FB),
        foregroundColor: const Color(0xFF7A2E6E),

        title: Text(
          _tr(
            'Giải trí',
            'Entertainment',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
            18,
            20,
            18,
            32,
          ),

          child: Column(
            children: [

              // ==================================================
              // HEADER
              // ==================================================

              Text(
                _tr(
                  'Chọn trò chơi',
                  'Choose a game',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7A2E6E),
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                _tr(
                  'Chọn một trò chơi để bắt đầu.',
                  'Choose a game to get started.',
                ),
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      Colors.grey.shade700,
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              // ==================================================
              // LUCKY SPIN
              // ==================================================

              _GameCard(
                icon:
                    Icons.casino_rounded,

                title:
                    'Lucky Spin',

                description: _tr(
                  'Quay vòng quay và nhận phần thưởng.',
                  'Spin the wheel and win rewards.',
                ),

                gradient: const [
                  Color(0xFFFF729A),
                  Color(0xFFE83D78),
                ],

                buttonText: _tr(
                  'Chơi ngay',
                  'Play now',
                ),

                onTap: () =>
                    _openLuckySpin(
                  context,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // SNAKE
              // ==================================================

              _GameCard(
                icon:
                    Icons.pets_rounded,

                title:
                    'Snake',

                description: _tr(
                  'Điều khiển rắn, ăn thức ăn và ghi điểm.',
                  'Control the snake, eat the food and score points.',
                ),

                gradient: const [
                  Color(0xFF39FF88),
                  Color(0xFF087F5B),
                ],

                buttonText: _tr(
                  'Chơi ngay',
                  'Play now',
                ),

                onTap: () =>
                    _openSnake(
                  context,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // BREAKOUT
              // ==================================================

              _GameCard(
                icon:
                    Icons.grid_4x4_rounded,

                title:
                    'Breakout',

                description: _tr(
                  'Phá các viên gạch và ghi điểm.',
                  'Break the bricks and score points.',
                ),

                gradient: const [
                  Color(0xFF7C4DFF),
                  Color(0xFF3F1FA8),
                ],

                buttonText: _tr(
                  'Chơi ngay',
                  'Play now',
                ),

                onTap: () =>
                    _openBreakout(
                  context,
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // TETRIS
              // ==================================================

              _GameCard(
                icon: Icons.view_quilt_rounded,
                title: 'Tetris',
                description: _tr(
                  'Xoay và xếp gạch để lấp đầy hàng.',
                  'Rotate and stack falling blocks to complete rows.',
                ),
                gradient: const [
                  Color(0xFF00D9FF),
                  Color(0xFF6A35D4),
                ],
                buttonText: _tr(
                  'Chơi ngay',
                  'Play now',
                ),
                onTap: () => _openTetris(context),
              ),

          

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // NEON RUNNER
              // ==================================================

      
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// GAME CARD
// ==================================================================

class _GameCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final String buttonText;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(28),

      child: Container(
        width: double.infinity,

        padding:
            const EdgeInsets.all(24),

        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(28),

          gradient:
              LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: gradient,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  gradient.last.withOpacity(
                0.25,
              ),
              blurRadius: 20,
              offset:
                  const Offset(0, 10),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // ==================================================
            // ICON
            // ==================================================

            Container(
              width: 64,
              height: 64,

              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withOpacity(0.18),
                shape:
                    BoxShape.circle,
              ),

              child: Icon(
                icon,
                color: Colors.white,
                size: 34,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            // ==================================================
            // TITLE
            // ==================================================

            Text(
              title,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 28,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            // ==================================================
            // DESCRIPTION
            // ==================================================

            Text(
              description,
              style:
                  TextStyle(
                color: Colors.white
                    .withOpacity(0.94),
                fontSize: 15,
                height: 1.4,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // BUTTON
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 11,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),

              child: Row(
                mainAxisSize:
                    MainAxisSize.min,

                children: [

                  Text(
                    buttonText,
                    style:
                        const TextStyle(
                      color:
                          Color(0xFF7A2E6E),
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    width: 6,
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_rounded,
                    color:
                        Color(0xFF7A2E6E),
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}