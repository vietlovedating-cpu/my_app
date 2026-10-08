import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class BreakoutGamePage extends StatefulWidget {
  final String languageCode;

  const BreakoutGamePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<BreakoutGamePage> createState() =>
      _BreakoutGamePageState();
}

class _BreakoutGamePageState
    extends State<BreakoutGamePage> {
  Timer? _timer;

  static const int rows = 6;
  static const int columns = 7;

  final List<_Brick> _bricks = [];

  double _paddleX = 0.5;
  double _ballX = 0.5;
  double _ballY = 0.72;

  double _velocityX = 0.006;
  double _velocityY = -0.0075;

  int _score = 0;
  int _lives = 3;

  bool _started = false;
  bool _gameOver = false;
  bool _won = false;

  // ============================================================
  // LANGUAGE
  // ============================================================

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) {
    return isVi ? vi : en;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  // ============================================================
  // RESET GAME
  // ============================================================

  void _resetGame() {
    _timer?.cancel();

    _bricks
      ..clear()
      ..addAll(
        List.generate(
          rows * columns,
          (index) => _Brick(
            row: index ~/ columns,
            column: index % columns,
          ),
        ),
      );

    _paddleX = 0.5;

    _ballX = 0.5;
    _ballY = 0.72;

    _velocityX = 0.006;
    _velocityY = -0.0075;

    _score = 0;
    _lives = 3;

    _started = false;
    _gameOver = false;
    _won = false;

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // START GAME
  // ============================================================

  void _startGame() {
    if (_gameOver || _won) {
      _resetGame();
    }

    if (_started) return;

    _started = true;

    _timer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _updateGame(),
    );

    setState(() {});
  }

  // ============================================================
  // MOVE PADDLE
  // ============================================================

  void _movePaddle(
    double localX,
    double width,
  ) {
    if (width <= 0) return;

    _paddleX =
        (localX / width).clamp(0.10, 0.90);

    if (!_started) {
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
        !_started ||
        _gameOver ||
        _won) {
      return;
    }

    setState(() {
      _ballX += _velocityX;
      _ballY += _velocityY;

      // --------------------------------------------------------
      // LEFT / RIGHT WALLS
      // --------------------------------------------------------

      if (_ballX <= 0.018 ||
          _ballX >= 0.982) {
        _velocityX = -_velocityX;

        _ballX =
            _ballX.clamp(0.018, 0.982);
      }

      // --------------------------------------------------------
      // TOP WALL
      // --------------------------------------------------------

      if (_ballY <= 0.045) {
        _velocityY =
            _velocityY.abs();

        _ballY = 0.045;
      }

      // --------------------------------------------------------
      // PADDLE COLLISION
      // --------------------------------------------------------

      final paddleLeft =
          _paddleX - 0.115;

      final paddleRight =
          _paddleX + 0.115;

      if (_ballY >= 0.855 &&
          _ballY <= 0.925 &&
          _ballX >= paddleLeft &&
          _ballX <= paddleRight &&
          _velocityY > 0) {
        final hitPosition =
            ((_ballX - _paddleX) /
                    0.115)
                .clamp(-1.0, 1.0);

        _velocityX =
            hitPosition * 0.009;

        _velocityY =
            -_velocityY.abs();

        // Prevent an almost vertical
        // ball from becoming boring.
        if (_velocityX.abs() < 0.0015) {
          _velocityX =
              _velocityX.isNegative
                  ? -0.0025
                  : 0.0025;
        }
      }

      // --------------------------------------------------------
      // BRICK COLLISION
      // --------------------------------------------------------

      for (final brick in _bricks) {
        if (!brick.alive) continue;

        final left =
            0.055 +
            brick.column * 0.128;

        final right =
            left + 0.112;

        final top =
            0.105 +
            brick.row * 0.058;

        final bottom =
            top + 0.040;

        if (_ballX >= left &&
            _ballX <= right &&
            _ballY >= top &&
            _ballY <= bottom) {
          brick.alive = false;

          _score += 10;

          _velocityY =
              -_velocityY;

          break;
        }
      }

      // --------------------------------------------------------
      // WIN
      // --------------------------------------------------------

      if (_bricks.every(
        (brick) => !brick.alive,
      )) {
        _won = true;
        _timer?.cancel();
        return;
      }

      // --------------------------------------------------------
      // BALL MISSED THE PADDLE
      // --------------------------------------------------------

      if (_ballY > 1.03) {
        _lives--;

        if (_lives <= 0) {
          _gameOver = true;
          _timer?.cancel();
        } else {
          _ballX = 0.5;
          _ballY = 0.72;

          _velocityX = 0.006;
          _velocityY = -0.0075;
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
          const Color(0xFF080512),

      appBar: AppBar(
        title: const Text(
          '🧱 Breakout',
        ),
        backgroundColor:
            const Color(0xFF10091F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            return GestureDetector(
              behavior:
                  HitTestBehavior.opaque,

              onTap: _startGame,

              onHorizontalDragStart:
                  (details) {
                _movePaddle(
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
              },

              onHorizontalDragUpdate:
                  (details) {
                _movePaddle(
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
              },

              child: Stack(
                children: [

                  // ==================================================
                  // GAME
                  // ==================================================

                  Positioned.fill(
                    child: CustomPaint(
                      painter:
                          _BreakoutPainter(
                        bricks: _bricks,
                        paddleX: _paddleX,
                        ballX: _ballX,
                        ballY: _ballY,
                        score: _score,
                        lives: _lives,
                      ),
                    ),
                  ),

                  // ==================================================
                  // START / WIN / GAME OVER
                  // ==================================================

                  if (!_started ||
                      _gameOver ||
                      _won)
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
                            0xF0161025,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            24,
                          ),
                          border:
                              Border.all(
                            color: _won
                                ? const Color(
                                    0xFFB8FF00,
                                  )
                                : const Color(
                                    0xFF00F5FF,
                                  ),
                            width: 1.5,
                          ),
                        ),

                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [

                            // ==================================================
                            // TITLE
                            // ==================================================

                            Text(
                              _won
                                  ? _tr(
                                      'BẠN THẮNG!',
                                      'YOU WIN!',
                                    )
                                  : _gameOver
                                      ? _tr(
                                          'KẾT THÚC',
                                          'GAME OVER',
                                        )
                                      : 'BREAKOUT',

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

                            // ==================================================
                            // SCORE / INSTRUCTION
                            // ==================================================

                            Text(
                              _won || _gameOver
                                  ? _tr(
                                      'Điểm: $_score',
                                      'Score: $_score',
                                    )
                                  : _tr(
                                      'Kéo ngón tay sang trái và phải để di chuyển thanh chắn.',
                                      'Drag your finger left and right to move the paddle.',
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

                            // ==================================================
                            // BUTTON
                            // ==================================================

                            ElevatedButton(
                              onPressed:
                                  _startGame,

                              child: Text(
                                _won ||
                                        _gameOver
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
// BRICK
// ==================================================================

class _Brick {
  final int row;
  final int column;

  bool alive = true;

  _Brick({
    required this.row,
    required this.column,
  });
}

// ==================================================================
// BREAKOUT PAINTER
// ==================================================================

class _BreakoutPainter
    extends CustomPainter {
  final List<_Brick> bricks;

  final double paddleX;
  final double ballX;
  final double ballY;

  final int score;
  final int lives;

  _BreakoutPainter({
    required this.bricks,
    required this.paddleX,
    required this.ballX,
    required this.ballY,
    required this.score,
    required this.lives,
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
            const Color(0xFF080512),
    );

    // ==========================================================
    // BACKGROUND GRID
    // ==========================================================

    final gridPaint = Paint()
      ..color =
          const Color(0xFF19132C)
      ..strokeWidth = 1;

    for (
      double y = 0;
      y < size.height;
      y += 32
    ) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    for (
      double x = 0;
      x < size.width;
      x += 32
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // ==========================================================
    // BRICKS
    // ==========================================================

    for (final brick in bricks) {
      if (!brick.alive) continue;

      final left =
          size.width *
              (0.055 +
                  brick.column * 0.128);

      final top =
          size.height *
              (0.105 +
                  brick.row * 0.058);

      final rect =
          Rect.fromLTWH(
        left,
        top,
        size.width * 0.112,
        size.height * 0.040,
      );

      final paint = Paint()
        ..color =
            _brickColor(brick.row);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(6),
        ),
        paint,
      );
    }

    // ==========================================================
    // PADDLE
    // ==========================================================

    final paddleRect =
        Rect.fromCenter(
      center: Offset(
        paddleX * size.width,
        size.height * 0.90,
      ),
      width:
          size.width * 0.23,
      height: 14,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        paddleRect,
        const Radius.circular(9),
      ),
      Paint()
        ..color =
            const Color(0xFF00E5FF),
    );

    // ==========================================================
    // BALL
    // ==========================================================

    canvas.drawCircle(
      Offset(
        ballX * size.width,
        ballY * size.height,
      ),
      math.min(
            size.width,
            size.height,
          ) *
          0.014,
      Paint()
        ..color = Colors.white,
    );

    // ==========================================================
    // SCORE / LIVES
    // ==========================================================

    final textPainter =
        TextPainter(
      text: TextSpan(
        text:
            'SCORE  $score     ♥  $lives',
        style:
            const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight:
              FontWeight.w800,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      const Offset(18, 18),
    );
  }

  // ============================================================
  // BRICK COLOR
  // ============================================================

  Color _brickColor(int row) {
    const colors = [
      Color(0xFFFF3CAC),
      Color(0xFFFF6B6B),
      Color(0xFFFFB84D),
      Color(0xFFB8FF00),
      Color(0xFF39FF88),
      Color(0xFF7C4DFF),
    ];

    return colors[
      row % colors.length
    ];
  }

  @override
  bool shouldRepaint(
    covariant _BreakoutPainter
        oldDelegate,
  ) {
    return true;
  }
}