import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class TetrisGamePage extends StatefulWidget {
  final String languageCode;

  const TetrisGamePage({
    super.key,
    required this.languageCode,
  });

  @override
  State<TetrisGamePage> createState() => _TetrisGamePageState();
}

class _TetrisGamePageState extends State<TetrisGamePage> {
  static const int _boardWidth = 10;
  static const int _boardHeight = 20;

  static const List<List<List<int>>> _shapes = [
    // I
    [
      [1, 1, 1, 1],
    ],
    // O
    [
      [1, 1],
      [1, 1],
    ],
    // T
    [
      [0, 1, 0],
      [1, 1, 1],
    ],
    // L
    [
      [0, 0, 1],
      [1, 1, 1],
    ],
    // J
    [
      [1, 0, 0],
      [1, 1, 1],
    ],
    // S
    [
      [0, 1, 1],
      [1, 1, 0],
    ],
    // Z
    [
      [1, 1, 0],
      [0, 1, 1],
    ],
  ];

  static const List<Color> _pieceColors = [
    Color(0xFF00E5FF),
    Color(0xFFFFD740),
    Color(0xFFB388FF),
    Color(0xFFFF9100),
    Color(0xFF448AFF),
    Color(0xFF69F0AE),
    Color(0xFFFF5252),
  ];

  late List<List<int>> _board;
  Timer? _timer;

  List<List<int>> _piece = [];
  int _pieceType = 0;
  int _pieceX = 3;
  int _pieceY = 0;

  // Accumulates horizontal finger movement so one long swipe can move
  // the piece across multiple cells smoothly.
  double _horizontalDragAccumulator = 0;

  int _score = 0;
  int _lines = 0;
  int _level = 1;

  bool _started = false;
  bool _paused = false;
  bool _gameOver = false;

  bool get _isVi => widget.languageCode == 'vi';

  String _tr(String vi, String en) => _isVi ? vi : en;

  // Starts at a normal, playable speed and gets faster every 10 cleared lines.
  Duration get _dropInterval {
    // Approximately twice as fast as the previous version.
    // It still gets faster as the player clears more lines.
    final milliseconds = math.max(55, 260 - ((_level - 1) * 21)).toInt();
    return Duration(milliseconds: milliseconds);
  }

  @override
  void initState() {
    super.initState();
    _board = _emptyBoard();
    _spawnPiece();

    // Show a short bilingual guide when the player first opens the game.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showHowToPlay();
    });
  }

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171027),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: Color(0xFF6A35D4),
              width: 1.5,
            ),
          ),
          title: Text(
            _tr('🧩 Sẵn sàng xếp gạch?', '🧩 Ready to stack?'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr(
                  'Chạm vào màn hình để xoay khối gạch.\n'
                  'Vuốt trái hoặc phải để di chuyển.\n'
                  'Vuốt xuống để thả gạch nhanh.\n\n'
                  'Bạn cũng có thể dùng các nút điều khiển bên dưới.',
                  'Tap the board to rotate a block.\n'
                  'Swipe left or right to move it.\n'
                  'Swipe down to drop it quickly.\n\n'
                  'You can also use the control buttons below.',
                ),
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.55,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _startGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB388FF),
                foregroundColor: const Color(0xFF160D24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _tr('Bắt đầu chơi', 'Let’s Play'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  List<List<int>> _emptyBoard() =>
      List.generate(_boardHeight, (_) => List.filled(_boardWidth, 0));

  List<List<int>> _copyShape(List<List<int>> shape) =>
      shape.map((row) => List<int>.from(row)).toList();

  void _newGame() {
    _timer?.cancel();
    setState(() {
      _board = _emptyBoard();
      _score = 0;
      _lines = 0;
      _level = 1;
      _started = true;
      _paused = false;
      _gameOver = false;
      _spawnPiece();
    });
    _startTimer();
  }

  void _startGame() {
    if (_gameOver) {
      _newGame();
      return;
    }
    if (_paused) {
      setState(() => _paused = false);
      _startTimer();
      return;
    }
    if (!_started) {
      setState(() => _started = true);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_started || _paused || _gameOver) return;
    _timer = Timer.periodic(_dropInterval, (_) {
      if (!mounted || _paused || _gameOver) return;
      _stepDown();
    });
  }

  void _spawnPiece() {
    final random = math.Random();
    _pieceType = random.nextInt(_shapes.length);
    _piece = _copyShape(_shapes[_pieceType]);
    _pieceX = (_boardWidth - _piece[0].length) ~/ 2;
    _pieceY = 0;

    if (_collides(_piece, _pieceX, _pieceY)) {
      _gameOver = true;
      _started = false;
      _timer?.cancel();
    }
  }

  bool _collides(List<List<int>> shape, int x, int y) {
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 0) continue;
        final boardX = x + c;
        final boardY = y + r;

        if (boardX < 0 || boardX >= _boardWidth || boardY >= _boardHeight) {
          return true;
        }
        if (boardY >= 0 && _board[boardY][boardX] != 0) {
          return true;
        }
      }
    }
    return false;
  }

  void _moveHorizontal(int direction) {
    if (!_started || _paused || _gameOver) return;
    final nextX = _pieceX + direction;
    if (!_collides(_piece, nextX, _pieceY)) {
      setState(() => _pieceX = nextX);
    }
  }

  void _rotatePiece() {
    if (!_started || _paused || _gameOver) return;

    final rotated = List.generate(
      _piece[0].length,
      (row) => List.generate(
        _piece.length,
        (col) => _piece[_piece.length - 1 - col][row],
      ),
    );

    // Small wall-kick attempts help pieces rotate near the board edges.
    for (final offset in [0, -1, 1, -2, 2]) {
      if (!_collides(rotated, _pieceX + offset, _pieceY)) {
        setState(() {
          _piece = rotated;
          _pieceX += offset;
        });
        return;
      }
    }
  }

  void _stepDown() {
    if (!_started || _paused || _gameOver) return;

    setState(() {
      if (!_collides(_piece, _pieceX, _pieceY + 1)) {
        _pieceY++;
      } else {
        _lockPiece();
        _clearLines();
        _spawnPiece();
      }
    });

    if (_gameOver) {
      _timer?.cancel();
    }
  }

  void _hardDrop() {
    if (!_started || _paused || _gameOver) return;

    setState(() {
      while (!_collides(_piece, _pieceX, _pieceY + 1)) {
        _pieceY++;
        _score += 2;
      }
      _lockPiece();
      _clearLines();
      _spawnPiece();
    });

    if (_gameOver) {
      _timer?.cancel();
    }
  }

  void _lockPiece() {
    for (int r = 0; r < _piece.length; r++) {
      for (int c = 0; c < _piece[r].length; c++) {
        if (_piece[r][c] == 0) continue;
        final x = _pieceX + c;
        final y = _pieceY + r;
        if (y >= 0 && y < _boardHeight && x >= 0 && x < _boardWidth) {
          _board[y][x] = _pieceType + 1;
        }
      }
    }
  }

  void _clearLines() {
    int cleared = 0;
    for (int row = _boardHeight - 1; row >= 0; row--) {
      if (_board[row].every((cell) => cell != 0)) {
        _board.removeAt(row);
        _board.insert(0, List.filled(_boardWidth, 0));
        cleared++;
        row++;
      }
    }

    if (cleared > 0) {
      _lines += cleared;
      final points = [0, 100, 300, 500, 800];
      _score += points[cleared.clamp(0, 4).toInt()];
      final newLevel = (_lines ~/ 10) + 1;
      if (newLevel != _level) {
        _level = newLevel;
        // Restart timer so the new level speed takes effect immediately.
        _startTimer();
      }
    }
  }

  void _togglePause() {
    if (_gameOver) return;
    if (!_started) {
      _startGame();
      return;
    }

    setState(() => _paused = !_paused);
    if (_paused) {
      _timer?.cancel();
    } else {
      _startTimer();
    }
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
        title: const Text('🧩 Tetris'),
        backgroundColor: const Color(0xFF10091F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _tr('Chơi mới', 'New game'),
            onPressed: _newGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _statCard(_tr('ĐIỂM', 'SCORE'), '$_score'),
                  const SizedBox(width: 8),
                  _statCard(_tr('HÀNG', 'LINES'), '$_lines'),
                  const SizedBox(width: 8),
                  _statCard(_tr('CẤP', 'LEVEL'), '$_level'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _boardWidth / _boardHeight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF100B20),
                      border: Border.all(
                        color: const Color(0xFF55436F),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Tap the board to rotate the falling block.
                        onTap: _rotatePiece,
                        // Let the piece follow the finger during a swipe.
                        // A long swipe can cross multiple cells without lifting.
                        onHorizontalDragStart: (_) {
                          _horizontalDragAccumulator = 0;
                        },
                        onHorizontalDragUpdate: (details) {
                          _horizontalDragAccumulator += details.delta.dx;

                          // Roughly one board cell of finger movement per step.
                          // This avoids requiring a separate swipe for each cell.
                          const dragThreshold = 20.0;

                          while (_horizontalDragAccumulator <= -dragThreshold) {
                            _moveHorizontal(-1);
                            _horizontalDragAccumulator += dragThreshold;
                          }

                          while (_horizontalDragAccumulator >= dragThreshold) {
                            _moveHorizontal(1);
                            _horizontalDragAccumulator -= dragThreshold;
                          }
                        },
                        // Swipe down to drop the block quickly.
                        // Swipe up rotates the block.
                        onVerticalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity > 100) {
                            _hardDrop();
                          } else if (velocity < -100) {
                            _rotatePiece();
                          }
                        },
                        child: CustomPaint(
                          painter: _TetrisPainter(
                            board: _board,
                            piece: _piece,
                            pieceX: _pieceX,
                            pieceY: _pieceY,
                            pieceType: _pieceType,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (!_started || _paused || _gameOver)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _gameOver
                      ? _tr('KẾT THÚC TRÒ CHƠI', 'GAME OVER')
                      : _paused
                          ? _tr('ĐÃ TẠM DỪNG', 'PAUSED')
                          : _tr(
                              'Nhấn Bắt đầu để chơi',
                              'Press Start to play',
                            ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlButton(
                    icon: Icons.arrow_left_rounded,
                    label: _tr('Trái', 'Left'),
                    onPressed: () => _moveHorizontal(-1),
                  ),
                  const SizedBox(width: 8),
                  _controlButton(
                    icon: Icons.rotate_right_rounded,
                    label: _tr('Xoay', 'Rotate'),
                    onPressed: _rotatePiece,
                  ),
                  const SizedBox(width: 8),
                  _controlButton(
                    icon: Icons.arrow_right_rounded,
                    label: _tr('Phải', 'Right'),
                    onPressed: () => _moveHorizontal(1),
                  ),
                  const SizedBox(width: 8),
                  _controlButton(
                    icon: Icons.arrow_downward_rounded,
                    label: _tr('Thả', 'Drop'),
                    onPressed: _hardDrop,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _gameOver ? _newGame : _togglePause,
                      icon: Icon(
                        _gameOver
                            ? Icons.replay_rounded
                            : _paused || !_started
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                      ),
                      label: Text(
                        _gameOver
                            ? _tr('Chơi lại', 'Play Again')
                            : _paused || !_started
                                ? _tr('Bắt đầu', 'Start')
                                : _tr('Tạm dừng', 'Pause'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB388FF),
                        foregroundColor: const Color(0xFF160D24),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
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

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF171027),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF392950)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1230),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF493760)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 25),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _TetrisPainter extends CustomPainter {
  final List<List<int>> board;
  final List<List<int>> piece;
  final int pieceX;
  final int pieceY;
  final int pieceType;

  static const List<Color> colors = [
    Color(0xFF00E5FF),
    Color(0xFFFFD740),
    Color(0xFFB388FF),
    Color(0xFFFF9100),
    Color(0xFF448AFF),
    Color(0xFF69F0AE),
    Color(0xFFFF5252),
  ];

  _TetrisPainter({
    required this.board,
    required this.piece,
    required this.pieceX,
    required this.pieceY,
    required this.pieceType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / 10;
    final cellHeight = size.height / 20;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF100B20),
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF292039)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (int row = 0; row < 20; row++) {
      for (int col = 0; col < 10; col++) {
        final rect = Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );

        canvas.drawRect(rect, gridPaint);

        final value = board[row][col];
        if (value != 0) {
          _drawBlock(
            canvas,
            rect,
            colors[(value - 1) % colors.length],
          );
        }
      }
    }

    for (int row = 0; row < piece.length; row++) {
      for (int col = 0; col < piece[row].length; col++) {
        if (piece[row][col] == 0) continue;
        final boardRow = pieceY + row;
        final boardCol = pieceX + col;
        if (boardRow < 0 || boardRow >= 20 || boardCol < 0 || boardCol >= 10) {
          continue;
        }

        final rect = Rect.fromLTWH(
          boardCol * cellWidth,
          boardRow * cellHeight,
          cellWidth,
          cellHeight,
        );
        _drawBlock(canvas, rect, colors[pieceType % colors.length]);
      }
    }
  }

  void _drawBlock(Canvas canvas, Rect rect, Color color) {
    final inset = math.max(1.0, rect.width * 0.045).toDouble();
    final blockRect = rect.deflate(inset);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        blockRect,
        Radius.circular(math.min(4.0, rect.width * 0.12).toDouble()),
      ),
      Paint()..color = color,
    );

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(blockRect.left + 2, blockRect.top + 2),
      Offset(blockRect.right - 2, blockRect.top + 2),
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _TetrisPainter oldDelegate) => true;
}
