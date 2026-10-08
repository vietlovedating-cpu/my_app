import 'dart:math' as math;

import 'package:flutter/material.dart';

/// VietLove - Saigon Race
///
/// This page is completely independent from Lucky Spin.
/// It does NOT write game data to Firebase and does NOT use Flowers,
/// coins, XP, rewards, or betting.
///
/// Add this file as:
/// lib/pages/saigon_race_page.dart
///
/// Example navigation:
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => const SaigonRacePage(),
///   ),
/// );
class SaigonRacePage extends StatefulWidget {
  const SaigonRacePage({
    super.key,
    this.playerName = 'Kate',
    this.playerCountryCode = 'AU',
    this.startLevel = 1,
  });

  final String playerName;
  final String playerCountryCode;
  final int startLevel;

  @override
  State<SaigonRacePage> createState() => _SaigonRacePageState();
}

class _SaigonRacePageState extends State<SaigonRacePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gameController;

  final math.Random _random = math.Random();
  final Stopwatch _stopwatch = Stopwatch();

  int _level = 1;
  bool _showLobby = true;
  bool _showResult = false;
  bool _gameRunning = false;
  bool _playerFinished = false;
  bool _playerCrashed = false;

  double _worldDistance = 0;
  double _playerVertical = 0;
  double _playerVerticalVelocity = 0;
  double _cameraDistance = 0;
  double _elapsedSeconds = 0;
  DateTime? _lastTick;

  int _nextObstacleIndex = 0;
  final List<RaceObstacle> _obstacles = <RaceObstacle>[];
  final List<Racer> _racers = <Racer>[];

  List<Racer> get _computerRacers =>
      _racers.where((Racer racer) => !racer.isHuman).toList();

  Racer? get _humanRacer {
    for (final Racer racer in _racers) {
      if (racer.isHuman) return racer;
    }
    return null;
  }

  LevelConfig get _config => levelConfigs[_level - 1];

  @override
  void initState() {
    super.initState();
    _level = widget.startLevel.clamp(1, 20).toInt();

    _gameController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);
  }

  @override
  void dispose() {
    _stopGame();
    _gameController.dispose();
    super.dispose();
  }

  void _tick() {
    if (!_gameRunning || !mounted) return;

    final DateTime now = DateTime.now();
    final DateTime previous = _lastTick ?? now;
    _lastTick = now;

    double dt = now.difference(previous).inMicroseconds / 1000000.0;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;

    _elapsedSeconds += dt;

    _updatePlayer(dt);
    _updateComputerRacers(dt);
    _updateObstacles();
    _checkCollision();
    _checkFinish();

    if (mounted) setState(() {});
  }

  void _updatePlayer(double dt) {
    if (_playerCrashed) return;

    final double speed = _config.playerSpeed;
    _worldDistance += speed * dt;
    _cameraDistance = _worldDistance;

    if (_playerVertical > 0 || _playerVerticalVelocity > 0) {
      _playerVertical += _playerVerticalVelocity * dt;
      _playerVerticalVelocity -= _config.gravity * dt;

      if (_playerVertical <= 0) {
        _playerVertical = 0;
        _playerVerticalVelocity = 0;
      }
    }
  }

  void _updateComputerRacers(double dt) {
    for (final Racer racer in _computerRacers) {
      if (racer.finished) continue;

      racer.progress += racer.speed * dt;

      // Simple local AI: automatically jumps when an obstacle is nearby.
      final RaceObstacle? obstacle = _nearestObstacleForProgress(racer.progress);
      if (obstacle != null &&
          obstacle.distance - racer.progress < 90 &&
          obstacle.distance - racer.progress > 0) {
        racer.jumpTimer = 0.45;
      }

      if (racer.jumpTimer > 0) {
        racer.jumpTimer -= dt;
      }

      if (racer.progress >= _config.finishDistance) {
        racer.progress = _config.finishDistance;
        racer.finished = true;
        racer.finishTime = _elapsedSeconds + racer.startDelay;
      }
    }
  }

  RaceObstacle? _nearestObstacleForProgress(double progress) {
    RaceObstacle? nearest;
    double best = double.infinity;

    for (final RaceObstacle obstacle in _obstacles) {
      final double delta = obstacle.distance - progress;
      if (delta >= 0 && delta < best) {
        best = delta;
        nearest = obstacle;
      }
    }
    return nearest;
  }

  void _updateObstacles() {
    final double visibleUntil = _cameraDistance + 1000;

    while (_nextObstacleIndex < _config.obstacleDistances.length &&
        _config.obstacleDistances[_nextObstacleIndex] < visibleUntil) {
      final double distance =
          _config.obstacleDistances[_nextObstacleIndex].toDouble();

      _obstacles.add(
        RaceObstacle(
          distance: distance,
          type: _config.obstacleTypes[
              _nextObstacleIndex % _config.obstacleTypes.length],
        ),
      );
      _nextObstacleIndex++;
    }
  }

  void _checkCollision() {
    if (_playerCrashed || _playerFinished) return;

    for (final RaceObstacle obstacle in _obstacles) {
      final double distance = obstacle.distance - _worldDistance;

      if (distance.abs() < 48 && _playerVertical < obstacle.requiredJump) {
        _playerCrashed = true;

        // A collision slows the player but does not eliminate them.
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (!mounted || !_gameRunning || _playerFinished) return;
          setState(() {
            _playerCrashed = false;
          });
        });
        break;
      }
    }
  }

  void _checkFinish() {
    if (_playerFinished) return;

    if (_worldDistance >= _config.finishDistance) {
      _worldDistance = _config.finishDistance;
      _playerFinished = true;
      _gameRunning = false;
      _stopwatch.stop();
      _showResult = true;
      _gameController.stop();

      final Racer? player = _humanRacer;
      if (player != null) {
        player.progress = _config.finishDistance;
        player.finished = true;
        player.finishTime = _elapsedSeconds;
      }
    }
  }

  void _jump() {
    if (!_gameRunning || _playerCrashed || _showResult) return;
    if (_playerVertical > 1) return;

    setState(() {
      _playerVerticalVelocity = _config.jumpStrength;
      _playerVertical = 1;
    });
  }

  void _startRace() {
    _stopGame();

    _showLobby = false;
    _showResult = false;
    _gameRunning = true;
    _playerFinished = false;
    _playerCrashed = false;

    _worldDistance = 0;
    _cameraDistance = 0;
    _playerVertical = 0;
    _playerVerticalVelocity = 0;
    _elapsedSeconds = 0;
    _nextObstacleIndex = 0;
    _obstacles.clear();

    _racers.clear();
    _racers.add(
      Racer(
        name: widget.playerName.trim().isEmpty ? 'You' : widget.playerName,
        countryCode: widget.playerCountryCode,
        isHuman: true,
        speed: _config.playerSpeed,
        startDelay: 0,
      ),
    );

    // Exactly 6 computer racers when the room has only one real player.
    final List<String> names = <String>[
      'Minh',
      'Linh',
      'Jason',
      'Trang',
      'David',
      'Kevin',
    ];

    for (int i = 0; i < names.length; i++) {
      final double speedFactor = 0.94 + (_random.nextDouble() * 0.13);
      _racers.add(
        Racer(
          name: names[i],
          countryCode: '',
          isHuman: false,
          speed: _config.playerSpeed * speedFactor,
          startDelay: 0.15 + (_random.nextDouble() * 0.8),
        ),
      );
    }

    _lastTick = DateTime.now();
    _stopwatch
      ..reset()
      ..start();

    _gameController
      ..reset()
      ..repeat();

    setState(() {});
  }

  void _stopGame() {
    _gameRunning = false;
    _stopwatch.stop();
    if (_gameController.isAnimating) {
      _gameController.stop();
    }
  }

  void _backToLobby() {
    _stopGame();
    setState(() {
      _showLobby = true;
      _showResult = false;
      _playerFinished = false;
      _playerCrashed = false;
      _obstacles.clear();
      _racers.clear();
      _worldDistance = 0;
      _cameraDistance = 0;
    });
  }

  void _nextLevel() {
    if (_level >= 20) {
      _backToLobby();
      return;
    }

    setState(() {
      _level++;
      _showResult = false;
      _showLobby = true;
    });
  }

  void _restartLevel() {
    _startRace();
  }

  List<Racer> get _finalRanking {
    final List<Racer> result = List<Racer>.from(_racers);
    result.sort((Racer a, Racer b) {
      if (a.finished != b.finished) return a.finished ? -1 : 1;
      if (a.finished && b.finished) {
        return (a.finishTime ?? 999999).compareTo(b.finishTime ?? 999999);
      }
      return b.progress.compareTo(a.progress);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🏍️', style: TextStyle(fontSize: 21)),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Saigon Race',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  'A fun race through Saigon',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _showLobby
            ? _buildLobby()
            : _showResult
                ? _buildResult()
                : _buildGame(),
      ),
    );
  }

  Widget _buildLobby() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFF0F3), Color(0xFFFFF8EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: <Widget>[
                const Text('🏍️', style: TextStyle(fontSize: 54)),
                const SizedBox(height: 8),
                Text(
                  _config.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _config.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(child: _infoCard('LEVEL', '$_level / 20', '🎯')),
              const SizedBox(width: 10),
              Expanded(child: _infoCard('RACERS', '7', '🏁')),
              const SizedBox(width: 10),
              Expanded(child: _infoCard('MODE', 'FUN', '😄')),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'You are the only player here',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                const Text(
                  'You can race with computer racers now, or wait for more players to join.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                _playerPreview(
                  name: widget.playerName.trim().isEmpty
                      ? 'You'
                      : widget.playerName,
                  countryCode: widget.playerCountryCode,
                  isHuman: true,
                ),
                const SizedBox(height: 9),
                for (final String name in <String>[
                  'Minh',
                  'Linh',
                  'Jason',
                  'Trang',
                  'David',
                  'Kevin',
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: _playerPreview(
                      name: name,
                      countryCode: '',
                      isHuman: false,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _startRace,
              icon: const Icon(Icons.sports_motorsports_rounded),
              label: Text(
                'Race Level $_level',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: Color(0xFFD8D8D8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'Just for fun • No prizes • No coins • No Flowers',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _playerPreview({
    required String name,
    required String countryCode,
    required bool isHuman,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isHuman ? const Color(0xFFFFF0F4) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 17,
            backgroundColor:
                isHuman ? const Color(0xFFE91E63) : const Color(0xFFE0E0E0),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                color: isHuman ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isHuman
                  ? '🌸 $name ${_countryFlag(countryCode)}'
                  : name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isHuman)
            const Text(
              'YOU',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE91E63),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    final double progress = (_worldDistance / _config.finishDistance)
        .clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _jump,
      onPanDown: (_) => _jump(),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            color: Colors.white,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE7EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'LEVEL $_level',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _config.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${(_config.finishDistance - _worldDistance).ceil()} m',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress,
                    backgroundColor: const Color(0xFFEDEDED),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE91E63),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: SaigonRacePainter(
                      config: _config,
                      worldDistance: _worldDistance,
                      obstacles: _obstacles,
                      playerVertical: _playerVertical,
                      playerCrashed: _playerCrashed,
                      elapsedSeconds: _elapsedSeconds,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: _raceTimePill(),
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: _jumpHint(),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: _miniRacerProgress(),
                ),
                if (_playerCrashed)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withOpacity(0.12),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Watch out! Keep racing! 🏍️',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: const SafeArea(
              top: false,
              child: Center(
                child: Text(
                  'TAP THE SCREEN TO JUMP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.black45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _raceTimePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '${_elapsedSeconds.toStringAsFixed(1)}s',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _jumpHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.touch_app_rounded, size: 15),
          SizedBox(width: 5),
          Text(
            'JUMP',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _miniRacerProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: <Widget>[
          const Text('🏁', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: (_worldDistance / _config.finishDistance)
                    .clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE8E8E8),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF43A047),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'FINISH',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final List<Racer> ranking = _finalRanking;
    final int playerPosition = ranking.indexWhere((Racer racer) => racer.isHuman) + 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFF1F5), Color(0xFFFFF8E9)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: <Widget>[
                const Text('🏁', style: TextStyle(fontSize: 54)),
                const SizedBox(height: 7),
                const Text(
                  'Race Finished!',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'Level $_level • ${_config.name}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Text(
                  playerPosition == 1
                      ? 'You finished 1st! 🎉'
                      : 'You finished $playerPosition${_ordinalSuffix(playerPosition)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE91E63),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            child: Column(
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Results',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < ranking.length; i++)
                  _rankingRow(i + 1, ranking[i]),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_level < 20)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _nextLevel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: Text(
                  'Next Level  →',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _restartLevel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: Color(0xFFD8D8D8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text('Race Level $_level Again'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: _backToLobby,
              child: const Text('Back to Race Lobby'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Just for fun • No prizes or rewards',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _rankingRow(int position, Racer racer) {
    final String medal = switch (position) {
      1 => '🏆',
      2 => '🥈',
      3 => '🥉',
      _ => '$position.',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: racer.isHuman ? const Color(0xFFFFF0F4) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 35,
            child: Text(
              medal,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              racer.isHuman
                  ? '🌸 ${racer.name} ${_countryFlag(racer.countryCode)}'
                  : racer.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            racer.finished
                ? '${(racer.finishTime ?? 0).toStringAsFixed(1)}s'
                : 'Still racing',
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  String _ordinalSuffix(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _countryFlag(String code) {
    final String normalized = code.trim().toUpperCase();
    if (normalized.length != 2) return '';

    final int first = normalized.codeUnitAt(0);
    final int second = normalized.codeUnitAt(1);

    if (first < 65 || first > 90 || second < 65 || second > 90) return '';

    return String.fromCharCodes(<int>[
      0x1F1E6 + first - 65,
      0x1F1E6 + second - 65,
    ]);
  }
}

class Racer {
  Racer({
    required this.name,
    required this.countryCode,
    required this.isHuman,
    required this.speed,
    required this.startDelay,
  });

  final String name;
  final String countryCode;
  final bool isHuman;
  final double speed;
  final double startDelay;

  double progress = 0;
  double jumpTimer = 0;
  bool finished = false;
  double? finishTime;
}

class RaceObstacle {
  RaceObstacle({
    required this.distance,
    required this.type,
  });

  final double distance;
  final ObstacleType type;

  double get requiredJump {
    switch (type) {
      case ObstacleType.cone:
        return 12;
      case ObstacleType.box:
        return 22;
      case ObstacleType.puddle:
        return 8;
      case ObstacleType.barrier:
        return 30;
      case ObstacleType.traffic:
        return 24;
      case ObstacleType.roadwork:
        return 34;
      case ObstacleType.marketCart:
        return 28;
      case ObstacleType.busStop:
        return 30;
    }
  }
}

enum ObstacleType {
  cone,
  box,
  puddle,
  barrier,
  traffic,
  roadwork,
  marketCart,
  busStop,
}

class LevelConfig {
  const LevelConfig({
    required this.name,
    required this.description,
    required this.playerSpeed,
    required this.finishDistance,
    required this.gravity,
    required this.jumpStrength,
    required this.obstacleDistances,
    required this.obstacleTypes,
    required this.sky,
    required this.ground,
    required this.accent,
    required this.landmark,
  });

  final String name;
  final String description;
  final double playerSpeed;
  final double finishDistance;
  final double gravity;
  final double jumpStrength;
  final List<int> obstacleDistances;
  final List<ObstacleType> obstacleTypes;
  final Color sky;
  final Color ground;
  final Color accent;
  final String landmark;
}

final List<LevelConfig> levelConfigs = <LevelConfig>[
  LevelConfig(
    name: 'Saigon Morning',
    description: 'A relaxed ride to learn the race.',
    playerSpeed: 250,
    finishDistance: 2200,
    gravity: 760,
    jumpStrength: 420,
    obstacleDistances: <int>[420, 700, 980, 1260, 1570, 1880],
    obstacleTypes: <ObstacleType>[
      ObstacleType.cone,
      ObstacleType.box,
    ],
    sky: Color(0xFFDFF4FF),
    ground: Color(0xFFB8D99A),
    accent: Color(0xFF4CAF50),
    landmark: '🌴',
  ),
  LevelConfig(
    name: 'Nguyen Hue Walk',
    description: 'More obstacles appear along the boulevard.',
    playerSpeed: 265,
    finishDistance: 2350,
    gravity: 780,
    jumpStrength: 425,
    obstacleDistances: <int>[380, 610, 850, 1100, 1370, 1640, 1940, 2180],
    obstacleTypes: <ObstacleType>[
      ObstacleType.cone,
      ObstacleType.puddle,
      ObstacleType.box,
    ],
    sky: Color(0xFFD9F1FF),
    ground: Color(0xFFB8D49D),
    accent: Color(0xFF43A047),
    landmark: '🏙️',
  ),
  LevelConfig(
    name: 'Ben Thanh Street',
    description: 'Watch the busy market-side road.',
    playerSpeed: 280,
    finishDistance: 2500,
    gravity: 800,
    jumpStrength: 430,
    obstacleDistances: <int>[350, 580, 820, 1030, 1270, 1510, 1770, 2010, 2280],
    obstacleTypes: <ObstacleType>[
      ObstacleType.box,
      ObstacleType.marketCart,
      ObstacleType.cone,
    ],
    sky: Color(0xFFFFE8C7),
    ground: Color(0xFFC8B27B),
    accent: Color(0xFFFF9800),
    landmark: '🏪',
  ),
  LevelConfig(
    name: 'Street Market',
    description: 'Carts and boxes make the road trickier.',
    playerSpeed: 292,
    finishDistance: 2600,
    gravity: 810,
    jumpStrength: 435,
    obstacleDistances: <int>[330, 540, 760, 960, 1190, 1420, 1650, 1880, 2130, 2380],
    obstacleTypes: <ObstacleType>[
      ObstacleType.marketCart,
      ObstacleType.box,
      ObstacleType.barrier,
    ],
    sky: Color(0xFFFFE1B8),
    ground: Color(0xFFBCA56F),
    accent: Color(0xFFEF6C00),
    landmark: '🧺',
  ),
  LevelConfig(
    name: 'District 1 Rush',
    description: 'The streets get faster and busier.',
    playerSpeed: 305,
    finishDistance: 2700,
    gravity: 820,
    jumpStrength: 440,
    obstacleDistances: <int>[310, 500, 700, 910, 1110, 1330, 1550, 1770, 2010, 2250, 2500],
    obstacleTypes: <ObstacleType>[
      ObstacleType.traffic,
      ObstacleType.cone,
      ObstacleType.barrier,
    ],
    sky: Color(0xFFE1F0FF),
    ground: Color(0xFF9EBB8B),
    accent: Color(0xFF1976D2),
    landmark: '🚦',
  ),
  LevelConfig(
    name: 'Saigon Bridge',
    description: 'A longer run with narrow traffic barriers.',
    playerSpeed: 318,
    finishDistance: 2850,
    gravity: 830,
    jumpStrength: 445,
    obstacleDistances: <int>[300, 480, 660, 850, 1050, 1240, 1450, 1660, 1880, 2110, 2350, 2620],
    obstacleTypes: <ObstacleType>[
      ObstacleType.barrier,
      ObstacleType.traffic,
      ObstacleType.cone,
    ],
    sky: Color(0xFFCFEAFF),
    ground: Color(0xFF8CB3C7),
    accent: Color(0xFF0288D1),
    landmark: '🌉',
  ),
  LevelConfig(
    name: 'Rush Hour Saigon',
    description: 'Motorbike traffic is everywhere.',
    playerSpeed: 330,
    finishDistance: 2950,
    gravity: 840,
    jumpStrength: 450,
    obstacleDistances: <int>[290, 450, 610, 790, 960, 1140, 1320, 1510, 1700, 1900, 2110, 2330, 2570, 2800],
    obstacleTypes: <ObstacleType>[
      ObstacleType.traffic,
      ObstacleType.traffic,
      ObstacleType.barrier,
      ObstacleType.cone,
    ],
    sky: Color(0xFFE5E5E5),
    ground: Color(0xFF909B83),
    accent: Color(0xFF546E7A),
    landmark: '🏍️',
  ),
  LevelConfig(
    name: 'Little Alley',
    description: 'Tight spaces leave less time to react.',
    playerSpeed: 342,
    finishDistance: 3050,
    gravity: 850,
    jumpStrength: 455,
    obstacleDistances: <int>[275, 430, 585, 750, 910, 1080, 1240, 1410, 1590, 1770, 1950, 2140, 2330, 2520, 2750, 2930],
    obstacleTypes: <ObstacleType>[
      ObstacleType.box,
      ObstacleType.barrier,
      ObstacleType.marketCart,
    ],
    sky: Color(0xFFD9E9E0),
    ground: Color(0xFF8BAA86),
    accent: Color(0xFF388E3C),
    landmark: '🏘️',
  ),
  LevelConfig(
    name: 'Canal Road',
    description: 'Puddles and barriers appear closer together.',
    playerSpeed: 354,
    finishDistance: 3150,
    gravity: 860,
    jumpStrength: 460,
    obstacleDistances: <int>[260, 410, 560, 720, 880, 1030, 1190, 1350, 1510, 1680, 1850, 2030, 2210, 2400, 2590, 2800, 3000],
    obstacleTypes: <ObstacleType>[
      ObstacleType.puddle,
      ObstacleType.barrier,
      ObstacleType.puddle,
      ObstacleType.box,
    ],
    sky: Color(0xFFCDE7EF),
    ground: Color(0xFF7EA6A0),
    accent: Color(0xFF00838F),
    landmark: '🌊',
  ),
  LevelConfig(
    name: 'Rainy Saigon',
    description: 'Rain makes the road feel slippery and unpredictable.',
    playerSpeed: 366,
    finishDistance: 3250,
    gravity: 875,
    jumpStrength: 465,
    obstacleDistances: <int>[250, 395, 540, 690, 845, 1000, 1155, 1310, 1470, 1630, 1800, 1970, 2140, 2310, 2490, 2680, 2870, 3070],
    obstacleTypes: <ObstacleType>[
      ObstacleType.puddle,
      ObstacleType.puddle,
      ObstacleType.traffic,
      ObstacleType.barrier,
    ],
    sky: Color(0xFFB8C9D9),
    ground: Color(0xFF718C91),
    accent: Color(0xFF455A64),
    landmark: '🌧️',
  ),
  LevelConfig(
    name: 'Saigon After Rain',
    description: 'Reflections and tight traffic create a faster challenge.',
    playerSpeed: 378,
    finishDistance: 3350,
    gravity: 885,
    jumpStrength: 470,
    obstacleDistances: <int>[240, 380, 520, 670, 820, 970, 1120, 1270, 1420, 1580, 1740, 1910, 2080, 2250, 2430, 2610, 2790, 2980, 3180],
    obstacleTypes: <ObstacleType>[
      ObstacleType.puddle,
      ObstacleType.traffic,
      ObstacleType.box,
      ObstacleType.barrier,
    ],
    sky: Color(0xFFC4D8E2),
    ground: Color(0xFF66837E),
    accent: Color(0xFF00695C),
    landmark: '💧',
  ),
  LevelConfig(
    name: 'Night Market',
    description: 'Neon lights, stalls and surprise barriers.',
    playerSpeed: 390,
    finishDistance: 3450,
    gravity: 900,
    jumpStrength: 475,
    obstacleDistances: <int>[235, 370, 505, 645, 790, 935, 1080, 1230, 1380, 1530, 1690, 1850, 2010, 2180, 2350, 2520, 2690, 2870, 3050, 3260],
    obstacleTypes: <ObstacleType>[
      ObstacleType.marketCart,
      ObstacleType.box,
      ObstacleType.barrier,
      ObstacleType.traffic,
    ],
    sky: Color(0xFF20243A),
    ground: Color(0xFF30343B),
    accent: Color(0xFFFFC107),
    landmark: '🏮',
  ),
  LevelConfig(
    name: 'Lantern Street',
    description: 'A colorful night route with very little breathing room.',
    playerSpeed: 402,
    finishDistance: 3550,
    gravity: 910,
    jumpStrength: 480,
    obstacleDistances: <int>[225, 355, 485, 620, 755, 895, 1035, 1175, 1315, 1460, 1605, 1750, 1900, 2050, 2200, 2360, 2520, 2680, 2850, 3020, 3200, 3400],
    obstacleTypes: <ObstacleType>[
      ObstacleType.marketCart,
      ObstacleType.traffic,
      ObstacleType.barrier,
      ObstacleType.box,
    ],
    sky: Color(0xFF171A2B),
    ground: Color(0xFF292B36),
    accent: Color(0xFFFF7043),
    landmark: '🏮',
  ),
  LevelConfig(
    name: 'District 3 Night',
    description: 'Traffic comes faster through the darker streets.',
    playerSpeed: 414,
    finishDistance: 3650,
    gravity: 920,
    jumpStrength: 485,
    obstacleDistances: <int>[215, 340, 465, 595, 725, 855, 990, 1125, 1260, 1400, 1540, 1680, 1820, 1970, 2120, 2270, 2430, 2590, 2750, 2910, 3070, 3230, 3400, 3550],
    obstacleTypes: <ObstacleType>[
      ObstacleType.traffic,
      ObstacleType.barrier,
      ObstacleType.traffic,
      ObstacleType.cone,
    ],
    sky: Color(0xFF121827),
    ground: Color(0xFF252C32),
    accent: Color(0xFF42A5F5),
    landmark: '🌃',
  ),
  LevelConfig(
    name: 'Saigon Traffic Madness',
    description: 'Fast traffic and frequent obstacles.',
    playerSpeed: 426,
    finishDistance: 3750,
    gravity: 930,
    jumpStrength: 490,
    obstacleDistances: <int>[205, 325, 445, 565, 685, 805, 925, 1050, 1175, 1300, 1425, 1550, 1680, 1810, 1940, 2070, 2200, 2330, 2460, 2600, 2740, 2880, 3020, 3160, 3300, 3450, 3600],
    obstacleTypes: <ObstacleType>[
      ObstacleType.traffic,
      ObstacleType.barrier,
      ObstacleType.traffic,
      ObstacleType.roadwork,
    ],
    sky: Color(0xFF1C2027),
    ground: Color(0xFF2C3035),
    accent: Color(0xFFEF5350),
    landmark: '🚕',
  ),
  LevelConfig(
    name: 'Roadwork Saigon',
    description: 'Construction zones leave almost no easy path.',
    playerSpeed: 438,
    finishDistance: 3850,
    gravity: 940,
    jumpStrength: 495,
    obstacleDistances: <int>[195, 310, 425, 540, 655, 770, 890, 1010, 1130, 1250, 1370, 1490, 1610, 1730, 1850, 1970, 2090, 2210, 2340, 2470, 2600, 2730, 2860, 2990, 3120, 3250, 3380, 3510, 3640, 3770],
    obstacleTypes: <ObstacleType>[
      ObstacleType.roadwork,
      ObstacleType.barrier,
      ObstacleType.box,
      ObstacleType.roadwork,
    ],
    sky: Color(0xFFD7D3CB),
    ground: Color(0xFF8A8377),
    accent: Color(0xFFFFA000),
    landmark: '🚧',
  ),
  LevelConfig(
    name: 'Saigon Boulevard',
    description: 'A long high-speed boulevard with moving traffic.',
    playerSpeed: 450,
    finishDistance: 3950,
    gravity: 950,
    jumpStrength: 500,
    obstacleDistances: <int>[185, 295, 405, 515, 625, 735, 845, 955, 1070, 1185, 1300, 1415, 1530, 1645, 1760, 1875, 1990, 2110, 2230, 2350, 2470, 2590, 2710, 2830, 2950, 3070, 3190, 3310, 3430, 3550, 3670, 3800],
    obstacleTypes: <ObstacleType>[
      ObstacleType.traffic,
      ObstacleType.traffic,
      ObstacleType.barrier,
      ObstacleType.cone,
    ],
    sky: Color(0xFFB8D9EA),
    ground: Color(0xFF6F8F71),
    accent: Color(0xFF1565C0),
    landmark: '🌴',
  ),
  LevelConfig(
    name: 'Saigon Skyline',
    description: 'The city lights are beautiful, but the road is brutal.',
    playerSpeed: 462,
    finishDistance: 4050,
    gravity: 960,
    jumpStrength: 505,
    obstacleDistances: <int>[180, 285, 390, 495, 600, 705, 815, 925, 1035, 1145, 1255, 1365, 1475, 1585, 1695, 1805, 1915, 2025, 2140, 2255, 2370, 2485, 2600, 2715, 2830, 2945, 3060, 3175, 3290, 3405, 3520, 3635, 3750, 3865, 3980],
    obstacleTypes: <ObstacleType>[
      ObstacleType.traffic,
      ObstacleType.roadwork,
      ObstacleType.barrier,
      ObstacleType.marketCart,
    ],
    sky: Color(0xFF10182C),
    ground: Color(0xFF272E3A),
    accent: Color(0xFF7E57C2),
    landmark: '🏙️',
  ),
  LevelConfig(
    name: 'Saigon Final Sprint',
    description: 'No time to relax. Every jump matters.',
    playerSpeed: 474,
    finishDistance: 4150,
    gravity: 970,
    jumpStrength: 510,
    obstacleDistances: <int>[175, 275, 375, 475, 575, 675, 775, 875, 975, 1075, 1175, 1275, 1375, 1475, 1575, 1675, 1775, 1875, 1975, 2075, 2175, 2275, 2375, 2475, 2575, 2675, 2775, 2875, 2975, 3075, 3175, 3275, 3375, 3475, 3575, 3675, 3775, 3875, 3975, 4075],
    obstacleTypes: <ObstacleType>[
      ObstacleType.traffic,
      ObstacleType.barrier,
      ObstacleType.roadwork,
      ObstacleType.traffic,
      ObstacleType.box,
    ],
    sky: Color(0xFF17131E),
    ground: Color(0xFF252329),
    accent: Color(0xFFE91E63),
    landmark: '🏁',
  ),
  LevelConfig(
    name: 'Saigon Challenge',
    description: 'Level 20. The ultimate Saigon race.',
    playerSpeed: 488,
    finishDistance: 4300,
    gravity: 985,
    jumpStrength: 515,
    obstacleDistances: <int>[165, 260, 355, 450, 545, 640, 735, 830, 925, 1020, 1115, 1210, 1305, 1400, 1495, 1590, 1685, 1780, 1875, 1970, 2065, 2160, 2255, 2350, 2445, 2540, 2635, 2730, 2825, 2920, 3015, 3110, 3205, 3300, 3395, 3490, 3585, 3680, 3775, 3870, 3965, 4060, 4155, 4250],
    obstacleTypes: <ObstacleType>[
      ObstacleType.traffic,
      ObstacleType.barrier,
      ObstacleType.roadwork,
      ObstacleType.marketCart,
      ObstacleType.traffic,
      ObstacleType.box,
    ],
    sky: Color(0xFF100E16),
    ground: Color(0xFF202024),
    accent: Color(0xFFFF4081),
    landmark: '🏆',
  ),
];

class SaigonRacePainter extends CustomPainter {
  SaigonRacePainter({
    required this.config,
    required this.worldDistance,
    required this.obstacles,
    required this.playerVertical,
    required this.playerCrashed,
    required this.elapsedSeconds,
  });

  final LevelConfig config;
  final double worldDistance;
  final List<RaceObstacle> obstacles;
  final double playerVertical;
  final bool playerCrashed;
  final double elapsedSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Sky.
    paint.color = config.sky;
    canvas.drawRect(Offset.zero & size, paint);

    _drawSkyDetails(canvas, size, paint);
    _drawCity(canvas, size, paint);
    _drawRoad(canvas, size, paint);
    _drawObstacles(canvas, size, paint);
    _drawPlayer(canvas, size, paint);
    _drawFinishIfNear(canvas, size, paint);
  }

  void _drawSkyDetails(Canvas canvas, Size size, Paint paint) {
    final bool night = config.sky.computeLuminance() < 0.25;

    if (night) {
      paint.color = Colors.white.withOpacity(0.75);
      for (int i = 0; i < 36; i++) {
        final double x = ((i * 83.0) % size.width);
        final double y = 24 + ((i * 47.0) % (size.height * 0.28));
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    } else {
      paint.color = Colors.white.withOpacity(0.55);
      canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.16), 28, paint);

      paint.color = Colors.white.withOpacity(0.45);
      for (int i = 0; i < 4; i++) {
        final double x = 55 + i * 125.0 - (worldDistance * 0.035 % 125);
        final double y = 65 + (i % 2) * 35.0;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 88, height: 25),
          paint,
        );
      }
    }
  }

  void _drawCity(Canvas canvas, Size size, Paint paint) {
    final double cityBottom = size.height * 0.61;
    final double scroll = (worldDistance * 0.12) % 180;

    for (int i = -1; i < 9; i++) {
      final double x = i * 110.0 - scroll;
      final double height = 70.0 + ((i * 43) % 80).abs().toDouble();
      paint.color = config.sky.computeLuminance() < 0.3
          ? const Color(0xFF303342)
          : const Color(0xFFB7C5CB);
      canvas.drawRect(
        Rect.fromLTWH(x, cityBottom - height, 78, height),
        paint,
      );

      if (config.sky.computeLuminance() < 0.3) {
        paint.color = const Color(0xFFFFD54F).withOpacity(0.65);
        for (int w = 0; w < 3; w++) {
          for (int h = 0; h < 4; h++) {
            final double wx = x + 13 + w * 19;
            final double wy = cityBottom - height + 15 + h * 18;
            canvas.drawRect(Rect.fromLTWH(wx, wy, 7, 8), paint);
          }
        }
      }
    }

    final double landmarkX = size.width * 0.73 - (scroll * 0.4);
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: config.landmark,
        style: const TextStyle(fontSize: 38),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(landmarkX, cityBottom - 85));
  }

  void _drawRoad(Canvas canvas, Size size, Paint paint) {
    final double roadTop = size.height * 0.60;
    final double roadBottom = size.height;

    paint.color = config.ground;
    canvas.drawRect(
      Rect.fromLTRB(0, roadTop, size.width, roadBottom),
      paint,
    );

    paint.color = const Color(0xFF424242);
    canvas.drawRect(
      Rect.fromLTRB(0, roadTop + 34, size.width, roadBottom),
      paint,
    );

    paint.color = Colors.white.withOpacity(0.85);
    final double laneY = roadTop + 115;
    final double dashWidth = 70;
    final double gap = 48;
    final double offset = worldDistance % (dashWidth + gap);

    for (double x = -offset; x < size.width + dashWidth; x += dashWidth + gap) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, laneY, dashWidth, 5),
          const Radius.circular(4),
        ),
        paint,
      );
    }

    paint.color = const Color(0xFFE0E0E0);
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop + 8, size.width, 6),
      paint,
    );
  }

  void _drawObstacles(Canvas canvas, Size size, Paint paint) {
    final double roadTop = size.height * 0.60;
    final double playerX = size.width * 0.23;
    const double worldPixelsPerScreen = 1.0;

    for (final RaceObstacle obstacle in obstacles) {
      final double relative = obstacle.distance - worldDistance;
      if (relative < -100 || relative > size.width * 1.4) continue;

      final double x = playerX + relative * worldPixelsPerScreen;
      if (x < -80 || x > size.width + 80) continue;

      _drawObstacle(canvas, paint, obstacle.type, Offset(x, roadTop + 54));
    }
  }

  void _drawObstacle(
    Canvas canvas,
    Paint paint,
    ObstacleType type,
    Offset base,
  ) {
    switch (type) {
      case ObstacleType.cone:
        paint.color = const Color(0xFFFF6D00);
        final Path cone = Path()
          ..moveTo(base.dx, base.dy - 35)
          ..lineTo(base.dx - 19, base.dy)
          ..lineTo(base.dx + 19, base.dy)
          ..close();
        canvas.drawPath(cone, paint);
        paint.color = Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(base.dx - 11, base.dy - 16, 22, 5),
          paint,
        );
        break;
      case ObstacleType.box:
        paint.color = const Color(0xFF8D6E63);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(base.dx - 23, base.dy - 38, 46, 38),
            const Radius.circular(5),
          ),
          paint,
        );
        paint.color = const Color(0xFFD7CCC8);
        paint.strokeWidth = 4;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(base.dx - 18, base.dy - 33),
          Offset(base.dx + 18, base.dy - 5),
          paint,
        );
        paint.style = PaintingStyle.fill;
        break;
      case ObstacleType.puddle:
        paint.color = const Color(0xFF42A5F5).withOpacity(0.75);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(base.dx, base.dy - 4),
            width: 72,
            height: 18,
          ),
          paint,
        );
        break;
      case ObstacleType.barrier:
        paint.color = const Color(0xFFFF7043);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(base.dx - 34, base.dy - 30, 68, 30),
            const Radius.circular(4),
          ),
          paint,
        );
        paint.color = Colors.white;
        for (int i = -1; i <= 1; i++) {
          canvas.save();
          canvas.translate(base.dx + i * 22, base.dy - 15);
          canvas.rotate(-0.6);
          canvas.drawRect(const Rect.fromLTWH(-5, -15, 10, 30), paint);
          canvas.restore();
        }
        break;
      case ObstacleType.traffic:
        paint.color = const Color(0xFF1565C0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(base.dx - 25, base.dy - 47, 50, 47),
            const Radius.circular(8),
          ),
          paint,
        );
        paint.color = const Color(0xFF90CAF9);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(base.dx - 16, base.dy - 38, 32, 15),
            const Radius.circular(4),
          ),
          paint,
        );
        paint.color = const Color(0xFF212121);
        canvas.drawCircle(Offset(base.dx - 15, base.dy - 2), 6, paint);
        canvas.drawCircle(Offset(base.dx + 15, base.dy - 2), 6, paint);
        break;
      case ObstacleType.roadwork:
        paint.color = const Color(0xFFFFA000);
        canvas.drawRect(
          Rect.fromLTWH(base.dx - 25, base.dy - 50, 50, 50),
          paint,
        );
        paint.color = Colors.white;
        paint.strokeWidth = 7;
        for (int i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(base.dx - 22, base.dy - 15 + i * 16),
            Offset(base.dx + 22, base.dy - 15 + i * 16),
            paint,
          );
        }
        break;
      case ObstacleType.marketCart:
        paint.color = const Color(0xFF795548);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(base.dx - 30, base.dy - 35, 60, 35),
            const Radius.circular(5),
          ),
          paint,
        );
        paint.color = const Color(0xFFFFCC80);
        canvas.drawCircle(Offset(base.dx - 19, base.dy + 1), 7, paint);
        canvas.drawCircle(Offset(base.dx + 19, base.dy + 1), 7, paint);
        paint.color = const Color(0xFFEF5350);
        canvas.drawRect(
          Rect.fromLTWH(base.dx - 34, base.dy - 49, 68, 13),
          paint,
        );
        break;
      case ObstacleType.busStop:
        paint.color = const Color(0xFF00897B);
        canvas.drawRect(
          Rect.fromLTWH(base.dx - 28, base.dy - 58, 56, 58),
          paint,
        );
        paint.color = Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(base.dx - 18, base.dy - 45, 36, 17),
          paint,
        );
        break;
    }
  }

  void _drawPlayer(
    Canvas canvas,
    Size size,
    Paint paint,
  ) {
    final double roadTop = size.height * 0.60;
    final double x = size.width * 0.23;
    final double y = roadTop + 47 - playerVertical;

    if (playerCrashed) {
      paint.color = Colors.black.withOpacity(0.28);
      canvas.drawCircle(Offset(x, y + 2), 34, paint);
    }

    // Shadow.
    paint.color = Colors.black.withOpacity(0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, roadTop + 53),
        width: 60,
        height: 13,
      ),
      paint,
    );

    // Rider head.
    paint.color = const Color(0xFFFFCCBC);
    canvas.drawCircle(Offset(x, y - 34), 10, paint);

    // Helmet.
    paint.color = const Color(0xFFE91E63);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(x, y - 36), width: 23, height: 21),
      math.pi,
      math.pi,
      true,
      paint,
    );

    // Body.
    paint.color = const Color(0xFFE91E63);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 12, y - 25, 24, 27),
        const Radius.circular(8),
      ),
      paint,
    );

    // Bike.
    paint.color = const Color(0xFF212121);
    canvas.drawCircle(Offset(x - 15, y + 6), 9, paint);
    canvas.drawCircle(Offset(x + 15, y + 6), 9, paint);

    paint.color = const Color(0xFF616161);
    paint.strokeWidth = 4;
    canvas.drawLine(Offset(x - 15, y + 6), Offset(x, y - 8), paint);
    canvas.drawLine(Offset(x, y - 8), Offset(x + 15, y + 6), paint);
    canvas.drawLine(Offset(x - 15, y + 6), Offset(x + 5, y + 6), paint);

    // Small flag marker above player.
    paint.color = Colors.white.withOpacity(0.95);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 30, y - 78, 60, 22),
        const Radius.circular(11),
      ),
      paint,
    );

    final TextPainter namePainter = TextPainter(
      text: const TextSpan(
        text: 'YOU',
        style: TextStyle(
          color: Color(0xFFE91E63),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    namePainter.paint(
      canvas,
      Offset(x - namePainter.width / 2, y - 73),
    );
  }

  void _drawFinishIfNear(Canvas canvas, Size size, Paint paint) {
    final double remaining = config.finishDistance - worldDistance;
    if (remaining < -200 || remaining > 600) return;

    final double roadTop = size.height * 0.60;
    final double playerX = size.width * 0.23;
    final double x = playerX + remaining;

    if (x < -100 || x > size.width + 100) return;

    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(x - 7, roadTop - 90, 7, 90),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + 62, roadTop - 90, 7, 90),
      paint,
    );

    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        paint.color = (row + col).isEven ? Colors.black : Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(
            x - 7 + col * 17,
            roadTop - 90 + row * 15,
            17,
            15,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SaigonRacePainter oldDelegate) {
    return oldDelegate.worldDistance != worldDistance ||
        oldDelegate.playerVertical != playerVertical ||
        oldDelegate.playerCrashed != playerCrashed ||
        oldDelegate.obstacles.length != obstacles.length ||
        oldDelegate.elapsedSeconds != elapsedSeconds;
  }
}
