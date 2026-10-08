import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class NeonPongPage extends StatefulWidget {
  final String languageCode;

  const NeonPongPage({
    super.key,
    required this.languageCode,
  });

  @override
  State<NeonPongPage> createState() => _NeonPongPageState();
}

class _NeonPongPageState extends State<NeonPongPage> {
  Timer? _timer;
  final math.Random _random = math.Random();

  double playerY = 0.5;
  double cpuY = 0.5;
  double ballX = 0.5;
  double ballY = 0.5;
  double velocityX = 0.007;
  double velocityY = 0.0045;

  int playerScore = 0;
  int cpuScore = 0;

  bool started = false;
  bool gameOver = false;

  // ============================================================
  // LANGUAGE
  // ============================================================

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) {
    return isVi ? vi : en;
  }

  // ============================================================
  // START GAME
  // ============================================================

  void _startGame() {
    if (gameOver) {
      playerScore = 0;
      cpuScore = 0;
      gameOver = false;

      _resetBall(
        _random.nextBool() ? 1 : -1,
      );
    }

    if (started) return;

    started = true;

    _timer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _updateGame(),
    );

    setState(() {});
  }

  // ============================================================
  // RESET BALL
  // ============================================================

  void _resetBall(int direction) {
    ballX = 0.5;
    ballY = 0.5;

    velocityX = 0.007 * direction;

    velocityY =
        (_random.nextDouble() - 0.5) * 0.008;
  }

  // ============================================================
  // MOVE PLAYER
  // ============================================================

  void _movePlayer(
    double localY,
    double height,
  ) {
    if (height <= 0) return;

    playerY =
        (localY / height).clamp(0.12, 0.88);

    if (!started) {
      _startGame();
    } else {
      setState(() {});
    }
  }

  // ============================================================
  // UPDATE GAME
  // ============================================================

  void _updateGame() {
    if (!mounted ||
        !started ||
        gameOver) {
      return;
    }

    setState(() {
      // ----------------------------------------------------------
      // MOVE BALL
      // ----------------------------------------------------------

      ballX += velocityX;
      ballY += velocityY;

      // ----------------------------------------------------------
      // TOP / BOTTOM WALL
      // ----------------------------------------------------------

      if (ballY <= 0.025 ||
          ballY >= 0.975) {
        velocityY = -velocityY;

        ballY =
            ballY.clamp(0.025, 0.975);
      }

      // ----------------------------------------------------------
      // CPU FOLLOWS BALL
      // ----------------------------------------------------------

      cpuY +=
          (ballY - cpuY) * 0.045;

      cpuY =
          cpuY.clamp(0.12, 0.88);

      const playerX = 0.075;
      const cpuX = 0.925;
      const paddleHalfHeight = 0.115;

      // ----------------------------------------------------------
      // PLAYER PADDLE
      // ----------------------------------------------------------

      if (velocityX < 0 &&
          ballX <= playerX + 0.028 &&
          ballX >= playerX - 0.01 &&
          (ballY - playerY).abs() <=
              paddleHalfHeight) {
        final hit =
            ((ballY - playerY) /
                    paddleHalfHeight)
                .clamp(-1.0, 1.0);

        velocityX =
            velocityX.abs();

        velocityY =
            hit * 0.008;

        if (velocityY.abs() < 0.002) {
          velocityY =
              0.002 *
                  (hit >= 0
                      ? 1
                      : -1);
        }
      }

      // ----------------------------------------------------------
      // CPU PADDLE
      // ----------------------------------------------------------

      if (velocityX > 0 &&
          ballX >= cpuX - 0.028 &&
          ballX <= cpuX + 0.01 &&
          (ballY - cpuY).abs() <=
              paddleHalfHeight) {
        final hit =
            ((ballY - cpuY) /
                    paddleHalfHeight)
                .clamp(-1.0, 1.0);

        velocityX =
            -velocityX.abs();

        velocityY =
            hit * 0.008;

        if (velocityY.abs() < 0.002) {
          velocityY =
              0.002 *
                  (hit >= 0
                      ? 1
                      : -1);
        }
      }

      // ----------------------------------------------------------
      // CPU SCORES
      // ----------------------------------------------------------

      if (ballX < -0.03) {
        cpuScore++;

        if (cpuScore >= 7) {
          gameOver = true;
          _timer?.cancel();
        } else {
          _resetBall(1);
        }
      }

      // ----------------------------------------------------------
      // PLAYER SCORES
      // ----------------------------------------------------------

      if (ballX > 1.03) {
        playerScore++;

        if (playerScore >= 7) {
          gameOver = true;
          _timer?.cancel();
        } else {
          _resetBall(-1);
        }
      }
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF050912),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: Text(
          _tr(
            '🏓 Neon Pong',
            '🏓 Neon Pong',
          ),
        ),
        backgroundColor:
            const Color(0xFF071426),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // GAME AREA
      // ========================================================

      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            return GestureDetector(
              behavior:
                  HitTestBehavior.opaque,

              // ------------------------------------------------
              // TAP TO START
              // ------------------------------------------------

              onTap: _startGame,

              // ------------------------------------------------
              // DRAG PLAYER PADDLE
              // ------------------------------------------------

              onVerticalDragStart:
                  (details) {
                _movePlayer(
                  details.localPosition.dy,
                  constraints.maxHeight,
                );
              },

              onVerticalDragUpdate:
                  (details) {
                _movePlayer(
                  details.localPosition.dy,
                  constraints.maxHeight,
                );
              },

              child: Stack(
                children: [

                  // ============================================
                  // GAME PAINTER
                  // ============================================

                  Positioned.fill(
                    child: CustomPaint(
                      painter:
                          _NeonPongPainter(
                        playerY: playerY,
                        cpuY: cpuY,
                        ballX: ballX,
                        ballY: ballY,
                        playerScore:
                            playerScore,
                        cpuScore:
                            cpuScore,
                      ),
                    ),
                  ),

                  // ============================================
                  // START / GAME OVER PANEL
                  // ============================================

                  if (!started || gameOver)
                    Center(
                      child: Container(
                        margin:
                            const EdgeInsets.all(
                          28,
                        ),

                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xF0141A2B,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            24,
                          ),
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFF00F5FF,
                            ),
                          ),
                        ),

                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [

                            // ==================================
                            // TITLE
                            // ==================================

                            Text(
                              gameOver
                                  ? (
                                      playerScore >
                                              cpuScore
                                          ? _tr(
                                              'BẠN THẮNG!',
                                              'YOU WIN!',
                                            )
                                          : _tr(
                                              'MÁY THẮNG',
                                              'CPU WINS',
                                            )
                                    )
                                  : _tr(
                                      'NEON PONG',
                                      'NEON PONG',
                                    ),
                              textAlign:
                                  TextAlign.center,
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
                              height: 10,
                            ),

                            // ==================================
                            // SCORE / INSTRUCTION
                            // ==================================

                            Text(
                              gameOver
                                  ? '$playerScore  -  $cpuScore'
                                  : _tr(
                                      'Vuốt ngón tay lên xuống ở phía bên trái để di chuyển thanh chắn.',
                                      'Swipe your finger up and down on the left side to move the paddle.',
                                    ),
                              textAlign:
                                  TextAlign.center,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            // ==================================
                            // BUTTON
                            // ==================================

                            ElevatedButton(
                              onPressed:
                                  _startGame,
                              child: Text(
                                gameOver
                                    ? _tr(
                                        'Chơi lại',
                                        'Play Again',
                                      )
                                    : _tr(
                                        'Bắt đầu',
                                        'Start',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================================================================
// NEON PONG PAINTER
// ==================================================================

class _NeonPongPainter
    extends CustomPainter {
  final double playerY;
  final double cpuY;
  final double ballX;
  final double ballY;

  final int playerScore;
  final int cpuScore;

  const _NeonPongPainter({
    required this.playerY,
    required this.cpuY,
    required this.ballX,
    required this.ballY,
    required this.playerScore,
    required this.cpuScore,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    // ==========================================================
    // BACKGROUND
    // ==========================================================

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color =
            const Color(0xFF050912),
    );

    // ==========================================================
    // CENTER LINE
    // ==========================================================

    final linePaint = Paint()
      ..color =
          const Color(0xFF1D3048)
      ..strokeWidth = 2;

    for (
      double y = 0;
      y < size.height;
      y += 26
    ) {
      canvas.drawLine(
        Offset(
          size.width / 2,
          y,
        ),
        Offset(
          size.width / 2,
          y + 13,
        ),
        linePaint,
      );
    }

    // ==========================================================
    // PADDLE COLORS
    // ==========================================================

    final playerPaint =
        Paint()
          ..color =
              const Color(0xFF00F5FF);

    final cpuPaint =
        Paint()
          ..color =
              const Color(0xFFFF3CAC);

    // ==========================================================
    // PLAYER PADDLE
    // ==========================================================

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(
            size.width * 0.075,
            playerY * size.height,
          ),
          width: 13,
          height:
              size.height * 0.23,
        ),
        const Radius.circular(8),
      ),
      playerPaint,
    );

    // ==========================================================
    // CPU PADDLE
    // ==========================================================

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(
            size.width * 0.925,
            cpuY * size.height,
          ),
          width: 13,
          height:
              size.height * 0.23,
        ),
        const Radius.circular(8),
      ),
      cpuPaint,
    );

    // ==========================================================
    // BALL
    // ==========================================================

    canvas.drawCircle(
      Offset(
        ballX * size.width,
        ballY * size.height,
      ),
      8,
      Paint()
        ..color = Colors.white,
    );

    // ==========================================================
    // SCORE
    // ==========================================================

    final score =
        TextPainter(
      text: TextSpan(
        text:
            '$playerScore   :   $cpuScore',
        style:
            const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight:
              FontWeight.w900,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    )..layout();

    score.paint(
      canvas,
      Offset(
        size.width / 2 -
            score.width / 2,
        22,
      ),
    );
  }

  @override
  bool shouldRepaint(
    covariant _NeonPongPainter
        oldDelegate,
  ) {
    return true;
  }
}