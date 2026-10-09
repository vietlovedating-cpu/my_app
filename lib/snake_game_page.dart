import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class SnakeGamePage extends StatefulWidget {
  final String languageCode;

  const SnakeGamePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<SnakeGamePage> createState() => _SnakeGamePageState();
}

enum _Dir { up, down, left, right }

class _SnakeGamePageState extends State<SnakeGamePage> {
  static const int cols = 18;
  static const int rows = 28;

  final math.Random _random = math.Random();

  Timer? _timer;

  List<math.Point<int>> snake = [];

  math.Point<int> food = const math.Point(5, 8);

  _Dir direction = _Dir.right;
  _Dir nextDirection = _Dir.right;

  int score = 0;

  bool started = false;
  bool gameOver = false;

  // ============================================================
  // LANGUAGE
  // ============================================================

  bool get isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) {
    return isVi ? vi : en;
  }
  
void _showHowToPlay() {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0B1713),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: Color(0xFF39FF88),
          ),
        ),
        title: Text(
          _tr(
            '🐍 Cách chơi Snake',
            '🐍 How to Play Snake',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB8FF00),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          _tr(
            'Vuốt lên, xuống, trái hoặc phải để điều khiển rắn.\n\n'
            'Bạn cũng có thể dùng các nút mũi tên bên dưới.\n\n'
            'Ăn thức ăn màu hồng để được 10 điểm. '
            'Tránh đâm vào tường hoặc thân rắn!',
            'Swipe up, down, left or right to steer the snake.\n\n'
            'You can also use the arrow buttons below.\n\n'
            'Eat the pink food to score 10 points. '
            'Avoid the walls and your own tail!',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF39FF88),
              foregroundColor: const Color(0xFF07100C),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              _tr('Bắt đầu chơi', 'Let’s Play'),
            ),
          ),
        ],
      );
    },
  );
}


  // ============================================================
  // INIT
  // ============================================================

 
@override
void initState() {
  super.initState();
  _reset();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _showHowToPlay();
  });
}


  // ============================================================
  // RESET
  // ============================================================

  void _reset() {
    _timer?.cancel();

    snake = [
      const math.Point(8, 14),
      const math.Point(7, 14),
      const math.Point(6, 14),
    ];

    direction = _Dir.right;
    nextDirection = _Dir.right;

    score = 0;

    started = false;
    gameOver = false;

    _placeFood();

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // START
  // ============================================================

  void _start() {
    if (gameOver) {
      _reset();
    }

    if (started) return;

    started = true;

    _timer = Timer.periodic(
      const Duration(milliseconds: 115),
      (_) => _tick(),
    );

    setState(() {});
  }

  // ============================================================
  // DIRECTION
  // ============================================================

  void _setDirection(_Dir d) {
    if (!started) {
      _start();
    }

    if (gameOver) return;

    final opposite = {
      _Dir.up: _Dir.down,
      _Dir.down: _Dir.up,
      _Dir.left: _Dir.right,
      _Dir.right: _Dir.left,
    };

    if (opposite[direction] != d) {
      nextDirection = d;
    }
  }

  // ============================================================
  // GAME TICK
  // ============================================================

  void _tick() {
    if (!mounted || gameOver) return;

    direction = nextDirection;

    final head = snake.first;

    math.Point<int> next = head;

    switch (direction) {
      case _Dir.up:
        next = math.Point(
          head.x,
          head.y - 1,
        );
        break;

      case _Dir.down:
        next = math.Point(
          head.x,
          head.y + 1,
        );
        break;

      case _Dir.left:
        next = math.Point(
          head.x - 1,
          head.y,
        );
        break;

      case _Dir.right:
        next = math.Point(
          head.x + 1,
          head.y,
        );
        break;
    }

    // ==========================================================
    // COLLISION
    // ==========================================================

    if (next.x < 0 ||
        next.x >= cols ||
        next.y < 0 ||
        next.y >= rows ||
        snake.contains(next)) {
      setState(() {
        gameOver = true;
      });

      _timer?.cancel();

      return;
    }

    // ==========================================================
    // MOVE
    // ==========================================================

    setState(() {
      snake.insert(0, next);

      // Eat food
      if (next == food) {
        score += 10;
        _placeFood();
      } else {
        snake.removeLast();
      }
    });
  }

  // ============================================================
  // PLACE FOOD
  // ============================================================

  void _placeFood() {
    do {
      food = math.Point(
        _random.nextInt(cols),
        _random.nextInt(rows),
      );
    } while (snake.contains(food));
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
      backgroundColor: const Color(0xFF070B0D),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: Text(
          _tr(
            '🐍 Rắn Neon',
            '🐍 Neon Snake',
          ),
        ),
        backgroundColor: const Color(0xFF0B1713),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Column(
        children: [

          // ======================================================
          // SCORE
          // ======================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              10,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [

                Text(
                  _tr(
                    'ĐIỂM  $score',
                    'SCORE  $score',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF39FF88),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),

                // ==================================================
                // RESET / PLAY AGAIN
                // ==================================================

                if (!started || gameOver)
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      gameOver
                          ? _tr(
                              'Chơi lại',
                              'Play Again',
                            )
                          : _tr(
                              'Đặt lại',
                              'Reset',
                            ),
                    ),
                  ),
              ],
            ),
          ),

          // ======================================================
          // GAME BOARD
          // ======================================================

          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: cols / rows,

                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,

                  // =================================================
                  // TAP TO START
                  // =================================================

                  onTap: _start,

                  // =================================================
                  // SWIPE UP / DOWN
                  // =================================================

                  onVerticalDragEnd: (d) {
                    final velocity =
                        d.primaryVelocity ?? 0;

                    if (velocity < -40) {
                      _setDirection(_Dir.up);
                    } else if (velocity > 40) {
                      _setDirection(_Dir.down);
                    }
                  },

                  // =================================================
                  // SWIPE LEFT / RIGHT
                  // =================================================

                  onHorizontalDragEnd: (d) {
                    final velocity =
                        d.primaryVelocity ?? 0;

                    if (velocity < -40) {
                      _setDirection(_Dir.left);
                    } else if (velocity > 40) {
                      _setDirection(_Dir.right);
                    }
                  },

                  // =================================================
                  // PAINTER
                  // =================================================

                  child: CustomPaint(
                    painter: _SnakePainter(
                      snake: snake,
                      food: food,
                      cols: cols,
                      rows: rows,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // DIRECTION BUTTONS
          // ======================================================

          Padding(
            padding: const EdgeInsets.only(
              bottom: 22,
            ),
            child: Column(
              children: [

                // UP
                _control(
                  Icons.keyboard_arrow_up_rounded,
                  () {
                    _setDirection(_Dir.up);
                  },
                ),

                // LEFT + RIGHT
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [

                    _control(
                      Icons.keyboard_arrow_left_rounded,
                      () {
                        _setDirection(_Dir.left);
                      },
                    ),

                    const SizedBox(width: 60),

                    _control(
                      Icons.keyboard_arrow_right_rounded,
                      () {
                        _setDirection(_Dir.right);
                      },
                    ),
                  ],
                ),

                // DOWN
                _control(
                  Icons.keyboard_arrow_down_rounded,
                  () {
                    _setDirection(_Dir.down);
                  },
                ),
              ],
            ),
          ),

          // ======================================================
          // INSTRUCTION
          // ======================================================

          if (!started && !gameOver)
            Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: Text(
                _tr(
                  'Vuốt trên màn hình hoặc sử dụng các nút điều khiển',
                  'Swipe on the game screen or use the buttons',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTROL BUTTON
  // ============================================================

  Widget _control(
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 52,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF12221A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF39FF88),
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF39FF88),
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// SNAKE PAINTER
// ==================================================================

class _SnakePainter extends CustomPainter {
  final List<math.Point<int>> snake;
  final math.Point<int> food;
  final int cols;
  final int rows;

  _SnakePainter({
    required this.snake,
    required this.food,
    required this.cols,
    required this.rows,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    // ============================================================
    // BACKGROUND
    // ============================================================

    final bg = Paint()
      ..color = const Color(0xFF07100C);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(22),
      ),
      bg,
    );

    // ============================================================
    // CELL SIZE
    // ============================================================

    final cw = size.width / cols;
    final ch = size.height / rows;

    // ============================================================
    // GRID
    // ============================================================

    final grid = Paint()
      ..color = const Color(0xFF10231A)
      ..strokeWidth = 0.7;

    for (int x = 0; x <= cols; x++) {
      canvas.drawLine(
        Offset(
          x * cw,
          0,
        ),
        Offset(
          x * cw,
          size.height,
        ),
        grid,
      );
    }

    for (int y = 0; y <= rows; y++) {
      canvas.drawLine(
        Offset(
          0,
          y * ch,
        ),
        Offset(
          size.width,
          y * ch,
        ),
        grid,
      );
    }

    // ============================================================
    // FOOD
    // ============================================================

    final foodPaint = Paint()
      ..color = const Color(0xFFFF3D81);

    canvas.drawCircle(
      Offset(
        (food.x + .5) * cw,
        (food.y + .5) * ch,
      ),
      math.min(cw, ch) * .34,
      foodPaint,
    );

    // ============================================================
    // SNAKE
    // ============================================================

    for (int i = snake.length - 1; i >= 0; i--) {
      final p = snake[i];

      final paint = Paint()
        ..color = i == 0
            ? const Color(0xFFB8FF00)
            : const Color(0xFF39FF88);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            p.x * cw + 1.5,
            p.y * ch + 1.5,
            cw - 3,
            ch - 3,
          ),
          const Radius.circular(5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _SnakePainter oldDelegate,
  ) {
    return true;
  }
}