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
  State<BreakoutGamePage> createState() => _BreakoutGamePageState();
}

class _BreakoutGamePageState extends State<BreakoutGamePage> {
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
  int _level = 1;

  bool _started = false;
  bool _gameOver = false;
  bool _won = false;

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => isVi ? vi : en;

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10091F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: Color(0xFF00F5FF),
              width: 1.5,
            ),
          ),
          title: Text(
            _tr(
              '🧱 Cách chơi Breakout',
              '🧱 How to Play Breakout',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB8FF00),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            _tr(
              'Vuốt ngang trên màn hình để di chuyển thanh đỡ bóng.\n\n'
              'Chạm màn hình hoặc vuốt để bắt đầu chơi.\n\n'
              'Phá các viên gạch để ghi điểm. Mỗi viên gạch được 10 điểm.\n\n'
              'Đừng để bóng rơi xuống dưới thanh đỡ. Bạn có 3 mạng. '
              'Phá hết gạch để qua màn tiếp theo!',
              'Swipe horizontally across the screen to move the paddle.\n\n'
              'Tap the screen or swipe to start playing.\n\n'
              'Break the bricks to score points. Each brick is worth 10 points.\n\n'
              'Do not let the ball fall below the paddle. You have 3 lives. '
              'Break all the bricks to reach the next level!',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              height: 1.45,
              fontSize: 14,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F5FF),
                foregroundColor: const Color(0xFF080512),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                _tr('Bắt đầu chơi', 'Let’s Play'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Every brick breaks with one hit. Only the layout changes by level.
  bool _shouldCreateBrick(int row, int column) {
    if (_level == 1) return true;

    if (_level == 2) {
      return (row + column) % 4 != 0;
    }

    if (_level == 3) {
      return column % 3 != 1 || row.isEven;
    }

    if (_level == 4) {
      return (row + column).isEven;
    }

    final stage = _level - 5;

    switch (stage % 5) {
      case 0:
        return (row + column + stage).isEven &&
            (row + column) % 3 != 0;
      case 1:
        return (column + stage) % 3 != 1 || row.isEven;
      case 2:
        final zigzagColumn = (row + stage) % columns;
        return column == zigzagColumn ||
            column == (zigzagColumn + 1) % columns ||
            (row + column) % 4 == 0;
      case 3:
        return (column - row - stage) % 3 == 0 ||
            ((row + column + stage).isEven &&
                column % 3 == 0);
      default:
        final offsetColumn = (row * 2 + stage) % columns;
        return column == offsetColumn ||
            column == (offsetColumn + 1) % columns ||
            (row + column + stage) % 5 == 0;
    }
  }

  void _prepareLevel({bool resetProgress = false}) {
    _timer?.cancel();

    if (resetProgress) {
      _level = 1;
      _score = 0;
      _lives = 3;
    }

    _bricks
      ..clear()
      ..addAll(
        List.generate(
          rows * columns,
          (index) {
            final row = index ~/ columns;
            final column = index % columns;
            return _Brick(
              row: row,
              column: column,
              alive: _shouldCreateBrick(row, column),
            );
          },
        ).where((brick) => brick.alive),
      );

    _paddleX = 0.5;
    _ballX = 0.5;
    _ballY = 0.72;
    _velocityX = 0.006;
    _velocityY = -0.0075;
    _lives = 3;
    _started = false;
    _gameOver = false;
    _won = false;
  }

  void _startGame() {
    // After losing, replay the level immediately before the one where the
    // player lost. If they lost Level 1, restart Level 1.
    if (_gameOver) {
      if (_level > 1) {
        _level--;
      }
      _prepareLevel();
    } else if (_won) {
      // Only move to the next level after all bricks have actually been cleared.
      _level++;
      _prepareLevel();
    }

    if (_started) return;

    _started = true;
    _timer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _updateGame(),
    );

    setState(() {});
  }

  void _movePaddle(double localX, double width) {
    if (width <= 0 || _gameOver || _won) return;

    _paddleX = (localX / width).clamp(0.10, 0.90);

    if (!_started) {
      _startGame();
    } else {
      setState(() {});
    }
  }

  void _updateGame() {
    if (!mounted || !_started || _gameOver || _won) return;

    setState(() {
      _ballX += _velocityX;
      _ballY += _velocityY;

      if (_ballX <= 0.018 || _ballX >= 0.982) {
        _velocityX = -_velocityX;
        _ballX = _ballX.clamp(0.018, 0.982);
      }

      if (_ballY <= 0.045) {
        _velocityY = _velocityY.abs();
        _ballY = 0.045;
      }

      final paddleLeft = _paddleX - 0.115;
      final paddleRight = _paddleX + 0.115;

      if (_ballY >= 0.855 &&
          _ballY <= 0.925 &&
          _ballX >= paddleLeft &&
          _ballX <= paddleRight &&
          _velocityY > 0) {
        final hitPosition =
            ((_ballX - _paddleX) / 0.115).clamp(-1.0, 1.0);

        _velocityX = hitPosition * 0.009;
        _velocityY = -_velocityY.abs();

        if (_velocityX.abs() < 0.0015) {
          _velocityX =
              _velocityX.isNegative ? -0.0025 : 0.0025;
        }
      }

      // Every brick takes one hit.
      for (final brick in _bricks) {
        if (!brick.alive) continue;

        final left = 0.055 + brick.column * 0.128;
        final right = left + 0.112;
        final top = 0.105 + brick.row * 0.058;
        final bottom = top + 0.040;

        if (_ballX >= left &&
            _ballX <= right &&
            _ballY >= top &&
            _ballY <= bottom) {
          brick.alive = false;
          _score += 10;
          _velocityY = -_velocityY;
          break;
        }
      }

      if (_bricks.every((brick) => !brick.alive)) {
        _won = true;
        _timer?.cancel();
        return;
      }

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

  @override
  void initState() {
    super.initState();

    // Build the Level 1 bricks before the first game tick.
    // Without this, _bricks is empty and every() returns true,
    // so the game can incorrectly show "Level Complete" immediately.
    _prepareLevel(resetProgress: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showHowToPlay();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080512),
      appBar: AppBar(
        title: const Text('🧱 Breakout'),
        backgroundColor: const Color(0xFF10091F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _startGame,
              onHorizontalDragStart: (details) {
                _movePaddle(
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
              },
              onHorizontalDragUpdate: (details) {
                _movePaddle(
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BreakoutPainter(
                        bricks: _bricks,
                        paddleX: _paddleX,
                        ballX: _ballX,
                        ballY: _ballY,
                        score: _score,
                        lives: _lives,
                        level: _level,
                        scoreLabel: _tr('ĐIỂM', 'SCORE'),
                        levelLabel: _tr('MÀN', 'LEVEL'),
                        livesLabel: _tr('MẠNG', 'LIVES'),
                      ),
                    ),
                  ),
                  if (!_started || _gameOver || _won)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.all(28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xF0161025),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _won
                                ? const Color(0xFFB8FF00)
                                : const Color(0xFF00F5FF),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _won
                                  ? _tr('BẠN THẮNG!', 'LEVEL COMPLETE!')
                                  : _gameOver
                                      ? _tr('KẾT THÚC', 'GAME OVER')
                                      : 'BREAKOUT',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _won
                                  ? _tr(
                                      'Bạn đã vượt qua Level $_level!\nĐiểm: $_score',
                                      'You completed Level $_level!\nScore: $_score',
                                    )
                                  : _gameOver
                                      ? _tr(
                                          'Bạn đã đạt Level $_level.\nTổng điểm: $_score',
                                          'You reached Level $_level.\nTotal score: $_score',
                                        )
                                      : _tr(
                                          'Level $_level\nPhá hết gạch để chiến thắng!',
                                          'Level $_level\nBreak all the bricks to win!',
                                        ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: _startGame,
                              child: Text(
                                _won
                                    ? _tr('Level tiếp theo', 'Next Level')
                                    : _gameOver
                                        ? _tr(
                                            'Chơi lại từ Level 1',
                                            'Play Again',
                                          )
                                        : _tr('Bắt đầu', 'Start'),
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

class _Brick {
  final int row;
  final int column;
  bool alive;

  _Brick({
    required this.row,
    required this.column,
    this.alive = true,
  });
}

class _BreakoutPainter extends CustomPainter {
  final List<_Brick> bricks;
  final double paddleX;
  final double ballX;
  final double ballY;
  final int score;
  final int lives;
  final int level;
  final String scoreLabel;
  final String levelLabel;
  final String livesLabel;

  _BreakoutPainter({
    required this.bricks,
    required this.paddleX,
    required this.ballX,
    required this.ballY,
    required this.score,
    required this.lives,
    required this.level,
    required this.scoreLabel,
    required this.levelLabel,
    required this.livesLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080512),
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF19132C)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (final brick in bricks) {
      if (!brick.alive) continue;

      final left =
          size.width * (0.055 + brick.column * 0.128);
      final top =
          size.height * (0.105 + brick.row * 0.058);

      final rect = Rect.fromLTWH(
        left,
        top,
        size.width * 0.112,
        size.height * 0.040,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(6),
        ),
        Paint()..color = _brickColor(brick.row),
      );
    }

    final paddleRect = Rect.fromCenter(
      center: Offset(
        paddleX * size.width,
        size.height * 0.90,
      ),
      width: size.width * 0.23,
      height: 14,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        paddleRect,
        const Radius.circular(9),
      ),
      Paint()..color = const Color(0xFF00E5FF),
    );

    canvas.drawCircle(
      Offset(
        ballX * size.width,
        ballY * size.height,
      ),
      math.min(size.width, size.height) * 0.014,
      Paint()..color = Colors.white,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text:
            '$levelLabel $level   $scoreLabel $score   ♥ $livesLabel $lives',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width - 36);

    textPainter.paint(canvas, const Offset(18, 18));
  }

  Color _brickColor(int row) {
    const colors = [
      Color(0xFFFF3CAC),
      Color(0xFFFF6B6B),
      Color(0xFFFFB84D),
      Color(0xFFB8FF00),
      Color(0xFF39FF88),
      Color(0xFF7C4DFF),
    ];

    return colors[row % colors.length];
  }

  @override
  bool shouldRepaint(covariant _BreakoutPainter oldDelegate) => true;
}
