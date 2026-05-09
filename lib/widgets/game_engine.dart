import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';

// =============================================================================
// Ball — physics body that rolls on the tilted bar
// =============================================================================
class Ball {
  Offset position;
  Offset velocity;
  double radius;

  Ball({
    required this.position,
    this.velocity = Offset.zero,
    this.radius   = GameConstants.ballRadius,
  });

  /// [barAngle] — bar angle in radians (from Bar.angle)
  /// [barY]    — bar surface Y at the ball's current X position (from Bar.getYatX)
  ///             This is already the correct interpolated value; do NOT recalculate.
  void update(double dt, double barAngle, double barY, Size screenSize) {
    // Sub-step physics 2× per frame to prevent tunnelling at high speeds
    const steps = 2;
    for (int i = 0; i < steps; i++) {
      _step(dt / steps, barAngle, barY, screenSize);
    }
  }

  void _step(double dt, double barAngle, double barY, Size screenSize) {
    // --- Gravity -------------------------------------------------------
    // Along-bar component makes the ball roll with the tilt
    final gravityAlong = GameConstants.gravity * sin(barAngle);
    velocity = Offset(
      velocity.dx + gravityAlong * dt,
      velocity.dy + GameConstants.gravity * 0.1 * dt, // gentle vertical fall
    );

    // --- Friction (air drag) ------------------------------------------
    velocity = Offset(
      velocity.dx * GameConstants.friction,
      velocity.dy * GameConstants.friction,
    );

    // --- Integrate position -------------------------------------------
    position = Offset(
      position.dx + velocity.dx * dt,
      position.dy + velocity.dy * dt,
    );

    // --- Bar surface collision ----------------------------------------
    final barHalfWidth = GameConstants.barWidth / 2;
    final barLeft  = screenSize.width / 2 - barHalfWidth;
    final barRight = screenSize.width / 2 + barHalfWidth;

    // barY is already the correct bar surface Y at ball's X — use it directly.
    final surfaceY = barY;

    // Only collide when ball is horizontally within bar bounds (+ small margin)
    final onBar = position.dx >= barLeft  - radius * 0.5 &&
                  position.dx <= barRight + radius * 0.5;

    if (onBar && position.dy + radius > surfaceY) {
      // 1. Push ball above bar surface
      position = Offset(position.dx, surfaceY - radius);

      // 2. Decompose velocity into components relative to bar surface.
      //    Bar unit vector (left → right along bar surface):
      //      bx = cos(barAngle), by = sin(barAngle)
      //    Outward normal (perpendicular, pointing away from bar toward ball):
      //      nx =  sin(barAngle)   (for angle=0 → 0, small rightward lean)
      //      ny = -cos(barAngle)   (for angle=0 → -1, i.e. pointing UP)
      final nx =  sin(barAngle);
      final ny = -cos(barAngle);

      // Component of velocity along the outward normal
      final vDotN = velocity.dx * nx + velocity.dy * ny;

      // Only respond when ball moves INTO the bar (vDotN < 0 = moving against normal)
      if (vDotN < 0) {
        // Reflect normal component with restitution, keep tangential with rolling friction
        final e = GameConstants.bounceDamping; // coefficient of restitution
        velocity = Offset(
          velocity.dx - (1.0 + e) * vDotN * nx,
          velocity.dy - (1.0 + e) * vDotN * ny,
        );
        // Rolling friction on remaining velocity
        velocity = Offset(velocity.dx * 0.92, velocity.dy * 0.92);
      }
    }

    // --- Bar edge walls -----------------------------------------------
    // Soft walls so the ball bounces at bar ends instead of clipping through
    if (position.dx < barLeft + radius) {
      position = Offset(barLeft + radius, position.dy);
      velocity = Offset(-velocity.dx.abs() * 0.5, velocity.dy);
    }
    if (position.dx > barRight - radius) {
      position = Offset(barRight - radius, position.dy);
      velocity = Offset(velocity.dx.abs() * -0.5, velocity.dy);
    }
  }

  Rect get bounds => Rect.fromCircle(center: position, radius: radius);
}

// =============================================================================
// Bar — the tiltable platform controlled by the two joysticks
// =============================================================================
class Bar {
  double leftY;
  double rightY;
  double targetLeftY;
  double targetRightY;

  Bar({
    this.leftY        = 0.5,
    this.rightY       = 0.5,
    this.targetLeftY  = 0.5,
    this.targetRightY = 0.5,
  });

  /// Angle of the bar in radians. Positive = right side lower (in screen coords).
  double get angle => atan2(rightY - leftY, GameConstants.barWidth);

  /// Bar surface Y at screen X position [x].
  /// Linear interpolation between the two endpoints.
  double getYatX(double x, Size screenSize) {
    final t = (x - (screenSize.width / 2 - GameConstants.barWidth / 2)) /
              GameConstants.barWidth;
    return leftY + (rightY - leftY) * t.clamp(0.0, 1.0);
  }

  void update(double dt) {
    // Smooth lag towards target positions
    leftY  += (targetLeftY  - leftY)  * min(1.0, dt * 10);
    rightY += (targetRightY - rightY) * min(1.0, dt * 10);
  }

  List<Offset> getEndpoints(Size screenSize) {
    final halfWidth = GameConstants.barWidth / 2;
    return [
      Offset(screenSize.width / 2 - halfWidth, leftY),
      Offset(screenSize.width / 2 + halfWidth, rightY),
    ];
  }
}

// =============================================================================
// GameEngine widget
// =============================================================================
class GameEngine extends StatefulWidget {
  final LevelData levelData;
  final Function(int score, int level, bool won) onGameEnd;
  final Function(int score, int timeLeft) onScoreUpdate;
  final VoidCallback onPause;

  const GameEngine({
    super.key,
    required this.levelData,
    required this.onGameEnd,
    required this.onScoreUpdate,
    required this.onPause,
  });

  @override
  State<GameEngine> createState() => GameEngineState();
}

class GameEngineState extends State<GameEngine> with TickerProviderStateMixin {
  late Ball ball;
  late Bar  bar;
  double _leftInput  = 0;
  double _rightInput = 0;
  int    _score      = 0;
  double _timeLeft   = 60;
  Timer?  _gameTimer;
  bool   _gameOver   = false;
  late AnimationController _gameLoopController;
  DateTime? _lastFrameTime;
  Size?     _screenSize;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.levelData.timeLimit;
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_gameLoop);

    WidgetsBinding.instance.addPostFrameCallback((_) => _initGame());
  }

  void _initGame() {
    final size = MediaQuery.of(context).size;
    _screenSize = size;

    final barY = size.height * 0.75;
    bar = Bar(
      leftY: barY, rightY: barY,
      targetLeftY: barY, targetRightY: barY,
    );
    ball = Ball(
      position: Offset(size.width / 2, barY - GameConstants.ballRadius - 4),
    );

    _gameLoopController.forward();
    _startTimer();
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameOver) { timer.cancel(); return; }
      setState(() {
        _timeLeft--;
        widget.onScoreUpdate(_score, _timeLeft.toInt());
        if (_timeLeft <= 0) {
          _gameOver = true;
          AudioManager.instance.playLose();
          widget.onGameEnd(_score, widget.levelData.level, false);
        }
      });
    });
  }

  void _gameLoop() {
    if (_gameOver || _screenSize == null) return;

    final now = DateTime.now();
    final dt  = _lastFrameTime != null
        ? min((now.difference(_lastFrameTime!).inMicroseconds / 1_000_000.0), 0.05)
        : 0.016;
    _lastFrameTime = now;

    final size  = _screenSize!;
    final range = (GameConstants.maxBarY - GameConstants.minBarY) * size.height;
    final minY  = GameConstants.minBarY * size.height;
    final maxY  = GameConstants.maxBarY * size.height;

    // Apply joystick inputs to bar targets
    bar.targetLeftY  = (bar.leftY  - _leftInput  * dt * range * 2).clamp(minY, maxY);
    bar.targetRightY = (bar.rightY - _rightInput * dt * range * 2).clamp(minY, maxY);

    bar.update(dt);

    // Clamp tilt angle
    if (bar.angle.abs() > GameConstants.maxTiltAngle) {
      final sign  = bar.angle.sign;
      final maxDy = tan(GameConstants.maxTiltAngle) * GameConstants.barWidth;
      if (bar.rightY > bar.leftY) {
        bar.targetRightY = bar.targetLeftY + sign * maxDy;
        bar.rightY       = bar.targetRightY;
      } else {
        bar.targetLeftY  = bar.targetRightY - sign * maxDy;
        bar.leftY        = bar.targetLeftY;
      }
    }

    // Update ball — pass the already-correct barY at ball's X
    ball.update(dt, bar.angle, bar.getYatX(ball.position.dx, size), size);

    // Hole collision check
    _checkHoles();

    // Ball fell off bottom
    if (ball.position.dy > size.height + 60) {
      setState(() {
        _gameOver = true;
        AudioManager.instance.playLose();
        widget.onGameEnd(_score, widget.levelData.level, false);
      });
    }

    setState(() {});
  }

  void _checkHoles() {
    for (int i = 0; i < widget.levelData.holePositions.length; i++) {
      final holePos = widget.levelData.holePositions[i];
      final dist    = (ball.position - holePos).distance;

      if (dist < GameConstants.holeRadius - 4) {
        if (i == widget.levelData.targetHoleIndex) {
          setState(() {
            _gameOver = true;
            _score += GameConstants.pointsPerLevel * widget.levelData.level +
                      (_timeLeft * 10).toInt();
            AudioManager.instance.playWin();
            widget.onGameEnd(_score, widget.levelData.level, true);
          });
        } else if (widget.levelData.deadHoleIndices.contains(i)) {
          setState(() {
            _gameOver = true;
            AudioManager.instance.playLose();
            widget.onGameEnd(_score, widget.levelData.level, false);
          });
        }
        return;
      }
    }
  }

  void setLeftInput(double value)  => _leftInput  = value;
  void setRightInput(double value) => _rightInput = value;

  /// Called from gameplay_screen when user watches a rewarded ad
  void addBonusTime(int seconds) {
    setState(() => _timeLeft += seconds);
    widget.onScoreUpdate(_score, _timeLeft.toInt());
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _gameLoopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_screenSize == null) return const SizedBox.expand();

    final size         = _screenSize!;
    final barEndpoints = bar.getEndpoints(size);

    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Image.asset('assets/images/game_bg.jpg', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.15)),
        ),

        // Holes
        ...List.generate(widget.levelData.holePositions.length, (index) {
          final pos      = widget.levelData.holePositions[index];
          final isTarget = index == widget.levelData.targetHoleIndex;
          final isDead   = widget.levelData.deadHoleIndices.contains(index);

          return Positioned(
            left: pos.dx - GameConstants.holeRadius,
            top:  pos.dy - GameConstants.holeRadius,
            child: Container(
              width:  GameConstants.holeRadius * 2,
              height: GameConstants.holeRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTarget
                    ? GameConstants.neonGreen.withOpacity(0.3)
                    : isDead
                        ? GameConstants.neonRed.withOpacity(0.3)
                        : Colors.black.withOpacity(0.5),
                border: Border.all(
                  color: isTarget
                      ? GameConstants.neonGreen
                      : isDead ? GameConstants.neonRed
                               : Colors.white.withOpacity(0.3),
                  width: isTarget || isDead ? 3 : 1.5,
                ),
                boxShadow: isTarget
                    ? [BoxShadow(color: GameConstants.neonGreen.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
                    : isDead
                        ? [BoxShadow(color: GameConstants.neonRed.withOpacity(0.2), blurRadius: 6, spreadRadius: 1)]
                        : null,
              ),
              child: Center(
                child: Container(
                  width:  GameConstants.holeRadius * 1.2,
                  height: GameConstants.holeRadius * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.6),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }),

        // Bar
        CustomPaint(
          size: size,
          painter: BarPainter(
            start: barEndpoints[0],
            end:   barEndpoints[1],
            color: Colors.amber.shade400,
          ),
        ),

        // Ball
        Positioned(
          left: ball.position.dx - ball.radius,
          top:  ball.position.dy - ball.radius,
          child: Container(
            width:  ball.radius * 2,
            height: ball.radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Colors.white, Color(0xFFCCCCCC), Color(0xFF888888)],
                stops:  [0.0, 0.3, 1.0],
              ),
              boxShadow: [
                BoxShadow(color: Colors.white.withOpacity(0.18), blurRadius: 4, spreadRadius: 0),
              ],
            ),
          ),
        ),

        // HUD
        Positioned(
          top:   MediaQuery.of(context).padding.top + 10,
          left:  16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hud('LEVEL ${widget.levelData.level}',
                   GameConstants.goldColor.withOpacity(0.25), GameConstants.goldColor, 16),
              _timerHud(),
              _hud('$_score',
                   GameConstants.neonBlue.withOpacity(0.25), GameConstants.neonBlue, 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hud(String text, Color border, Color textColor, double size) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontSize: size, fontWeight: FontWeight.bold, letterSpacing: 2)),
    );
  }

  Widget _timerHud() {
    final urgent = _timeLeft <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: urgent ? GameConstants.neonRed.withOpacity(0.3) : Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: urgent ? GameConstants.neonRed : Colors.white.withOpacity(0.5)),
      ),
      child: Row(children: [
        Icon(Icons.timer, color: urgent ? GameConstants.neonRed : Colors.white, size: 18),
        const SizedBox(width: 6),
        Text('${_timeLeft.toInt()}s',
             style: TextStyle(color: urgent ? GameConstants.neonRed : Colors.white,
                              fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// =============================================================================
// Bar painter
// =============================================================================
class BarPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color  color;

  BarPainter({required this.start, required this.end, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..strokeWidth = GameConstants.barHeight + 10
      ..strokeCap   = StrokeCap.round
      ..color       = color.withOpacity(0.12)
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 5);

    final barPaint = Paint()
      ..strokeWidth = GameConstants.barHeight
      ..strokeCap   = StrokeCap.round
      ..shader      = LinearGradient(colors: [
          color.withOpacity(0.8), color, color.withOpacity(0.8),
        ]).createShader(Rect.fromPoints(start, end));

    final highlightPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap   = StrokeCap.round
      ..color       = Colors.white.withOpacity(0.5);

    canvas.drawLine(start, end, glowPaint);
    canvas.drawLine(start, end, barPaint);

    final dir    = (end - start);
    final angle  = dir.direction;
    final offset = Offset(-sin(angle) * 2, cos(angle) * 2);
    canvas.drawLine(start + offset, end + offset, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}
