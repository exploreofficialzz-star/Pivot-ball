import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';

// =============================================================================
// Ball — proper 2D physics with bar-surface interaction
// =============================================================================
class Ball {
  Offset position;
  Offset velocity;
  double radius;
  bool   onBar = false; // was touching bar last frame

  Ball({required this.position, this.velocity = Offset.zero,
        this.radius = GameConstants.ballRadius});

  // [barVelY] = bar surface velocity at ball's X (px/s, negative = upward)
  void update(double dt, double barAngle, double barY, double barVelY,
              Size screenSize) {
    // Sub-step for stability
    for (int i = 0; i < 3; i++) {
      _step(dt / 3, barAngle, barY, barVelY, screenSize);
    }
  }

  void _step(double dt, double barAngle, double barY, double barVelY,
             Size screenSize) {
    final barHW  = GameConstants.barWidth / 2;
    final barL   = screenSize.width / 2 - barHW;
    final barR   = screenSize.width / 2 + barHW;
    final inBarX = position.dx >= barL - radius && position.dx <= barR + radius;
    final touchingBar = inBarX && (position.dy + radius) >= barY - 2;

    // ── Gravity ──────────────────────────────────────────────────────────────
    // Lighter gravity when airborne so ball can arc upward to reach holes.
    final gY = touchingBar ? GameConstants.gravity : GameConstants.gravity * 0.55;
    velocity = Offset(velocity.dx, velocity.dy + gY * dt);

    // ── Light air friction ────────────────────────────────────────────────────
    velocity = Offset(velocity.dx * 0.998, velocity.dy * 0.998);

    // ── Integrate ─────────────────────────────────────────────────────────────
    position = Offset(position.dx + velocity.dx * dt,
                      position.dy + velocity.dy * dt);

    // ── Bar surface collision ─────────────────────────────────────────────────
    final onBarNow = inBarX && (position.dy + radius) >= barY;

    if (onBarNow) {
      // Push ball above surface
      position = Offset(position.dx, barY - radius);

      // ── Launch mechanic ───────────────────────────────────────────────────
      // When bar surface moves UP quickly (barVelY strongly negative),
      // it acts as a catapult — transfer that upward velocity to the ball.
      if (barVelY < -80) {
        const maxLaunch = 680.0; // px/s cap
        final launch = (barVelY * 0.85).clamp(-maxLaunch, 0.0);
        if (velocity.dy > launch) {
          velocity = Offset(velocity.dx, launch);
        }
      }

      // ── Surface normal reflection ──────────────────────────────────────────
      // Outward normal from tilted bar surface (points toward ball)
      final nx =  sin(barAngle);
      final ny = -cos(barAngle);
      final vn = velocity.dx * nx + velocity.dy * ny; // velocity · normal

      if (vn < 0) { // moving into bar
        final e = GameConstants.bounceDamping;
        velocity = Offset(
          velocity.dx - (1.0 + e) * vn * nx,
          velocity.dy - (1.0 + e) * vn * ny,
        );
        // Rolling friction
        velocity = Offset(velocity.dx * 0.82, velocity.dy * 0.82);
      }

      // ── Gravity-along-bar rolling force ───────────────────────────────────
      // This is what makes the ball roll when the bar is tilted.
      // Applied continuously while ball is on bar.
      final rollForce = GameConstants.gravity * sin(barAngle) * 1.4;
      velocity = Offset(velocity.dx + rollForce * dt, velocity.dy);
    }

    onBar = onBarNow;

    // ── Speed cap ─────────────────────────────────────────────────────────────
    const maxSpeed = 1100.0;
    final spd = velocity.distance;
    if (spd > maxSpeed) velocity = velocity * (maxSpeed / spd);

    // ── Bar edge walls ────────────────────────────────────────────────────────
    if (position.dx < barL + radius) {
      position = Offset(barL + radius, position.dy);
      velocity = Offset(-velocity.dx.abs() * 0.45, velocity.dy);
    }
    if (position.dx > barR - radius) {
      position = Offset(barR - radius, position.dy);
      velocity = Offset(velocity.dx.abs() * -0.45, velocity.dy);
    }
  }
}

// =============================================================================
// Bar — tracks velocity so it can transfer energy to the ball (catapult)
// =============================================================================
class Bar {
  double leftY, rightY, targetLeftY, targetRightY;

  double _prevLeftY  = 0;
  double _prevRightY = 0;
  double leftVelY    = 0; // px/s — negative = moving upward
  double rightVelY   = 0;

  Bar({this.leftY = 0.75, this.rightY = 0.75,
       this.targetLeftY = 0.75, this.targetRightY = 0.75}) {
    _prevLeftY  = leftY;
    _prevRightY = rightY;
  }

  double get angle => atan2(rightY - leftY, GameConstants.barWidth);

  double getYatX(double x, Size screenSize) {
    final t = (x - (screenSize.width / 2 - GameConstants.barWidth / 2)) /
              GameConstants.barWidth;
    return leftY + (rightY - leftY) * t.clamp(0.0, 1.0);
  }

  /// Interpolated bar surface velocity at a given X (px/s).
  double getVelYatX(double x, Size screenSize) {
    final t = (x - (screenSize.width / 2 - GameConstants.barWidth / 2)) /
              GameConstants.barWidth;
    return leftVelY + (rightVelY - leftVelY) * t.clamp(0.0, 1.0);
  }

  void update(double dt) {
    _prevLeftY  = leftY;
    _prevRightY = rightY;

    // Smooth response — fast enough to feel snappy, not instant
    final k = min(1.0, dt * 18.0);
    leftY  += (targetLeftY  - leftY)  * k;
    rightY += (targetRightY - rightY) * k;

    // Track velocity (px/s) — used for launch mechanic
    if (dt > 0) {
      leftVelY  = (leftY  - _prevLeftY)  / dt;
      rightVelY = (rightY - _prevRightY) / dt;
    }
  }

  List<Offset> getEndpoints(Size screenSize) {
    final hw = GameConstants.barWidth / 2;
    return [
      Offset(screenSize.width / 2 - hw, leftY),
      Offset(screenSize.width / 2 + hw, rightY),
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

  // Raw joystick inputs — set by gameplay_screen via setLeftInput/setRightInput.
  // Range: -1.0 (full up) to +1.0 (full down).
  double _leftInput  = 0.0;
  double _rightInput = 0.0;

  int    _score    = 0;
  double _timeLeft = 30.0;
  Timer? _gameTimer;
  bool   _gameOver = false;
  final Set<int> _completedTargets = {};

  late AnimationController _loop;
  DateTime? _lastFrame;
  Size?     _size;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.levelData.timeLimit;
    _loop = AnimationController(
      vsync:    this,
      duration: const Duration(days: 1),
    )..addListener(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final s = MediaQuery.of(context).size;
    _size = s;
    final barY = s.height * 0.73; // bar resting position
    bar  = Bar(leftY: barY, rightY: barY,
               targetLeftY: barY, targetRightY: barY);
    ball = Ball(position: Offset(s.width / 2, barY - GameConstants.ballRadius - 2));
    _completedTargets.clear();
    _loop.forward();
    _startTimer();
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_gameOver) { t.cancel(); return; }
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

  void _tick() {
    if (_gameOver || _size == null) return;
    final now = DateTime.now();
    final dt  = _lastFrame != null
        ? (now.difference(_lastFrame!).inMicroseconds / 1e6).clamp(0.0, 0.05)
        : 0.016;
    _lastFrame = now;

    final s     = _size!;
    final minY  = GameConstants.minBarY * s.height;
    final baseY = s.height * 0.73;

    // ── Direct joystick → bar endpoint position ───────────────────────────────
    // Joystick at -1 (knob full UP)   → bar side moves to minY (very high)
    // Joystick at  0 (knob centred)   → bar side at baseY (neutral)
    // Joystick at +1 (knob full DOWN) → bar side goes slightly below neutral
    final upTravel   = baseY - minY;           // how far bar can go UP
    final downTravel = s.height * 0.06;        // small downward movement allowed

    bar.targetLeftY = baseY + _leftInput * (
        _leftInput < 0 ? upTravel : downTravel);
    bar.targetRightY = baseY + _rightInput * (
        _rightInput < 0 ? upTravel : downTravel);

    // Clamp
    bar.targetLeftY  = bar.targetLeftY .clamp(minY, baseY + downTravel);
    bar.targetRightY = bar.targetRightY.clamp(minY, baseY + downTravel);

    // Clamp tilt angle
    if (bar.angle.abs() > GameConstants.maxTiltAngle) {
      final maxDy = tan(GameConstants.maxTiltAngle) * GameConstants.barWidth;
      if (bar.rightY > bar.leftY) {
        bar.targetRightY = bar.targetLeftY + maxDy;
      } else {
        bar.targetLeftY  = bar.targetRightY + maxDy;
      }
    }

    bar.update(dt);

    // ── Ball update ───────────────────────────────────────────────────────────
    final barYatBall  = bar.getYatX(ball.position.dx, s);
    final barVelAtBall = bar.getVelYatX(ball.position.dx, s);
    ball.update(dt, bar.angle, barYatBall, barVelAtBall, s);

    // ── Hole check ────────────────────────────────────────────────────────────
    _checkHoles();

    // ── Ball fell off bottom ──────────────────────────────────────────────────
    if (ball.position.dy > s.height + 80) {
      setState(() {
        _gameOver = true;
        AudioManager.instance.playLose();
        widget.onGameEnd(_score, widget.levelData.level, false);
      });
      return;
    }

    setState(() {});
  }

  void _checkHoles() {
    for (int i = 0; i < widget.levelData.holePositions.length; i++) {
      if (_completedTargets.contains(i)) continue;
      final dist = (ball.position - widget.levelData.holePositions[i]).distance;
      if (dist >= GameConstants.holeRadius - 4) continue;

      if (widget.levelData.targetHoleIndices.contains(i)) {
        _completedTargets.add(i);
        AudioManager.instance.playClick();
        final allDone = _completedTargets.length ==
            widget.levelData.targetHoleIndices.length;
        if (allDone) {
          setState(() {
            _gameOver = true;
            _score   += GameConstants.pointsPerLevel * widget.levelData.level +
                        _timeLeft.toInt() * 10 +
                        _completedTargets.length * 50;
            AudioManager.instance.playWin();
            widget.onGameEnd(_score, widget.levelData.level, true);
          });
        } else {
          // Reset ball to bar centre, keep bar angle
          final s   = _size!;
          final barY = bar.getYatX(s.width / 2, s);
          setState(() {
            ball.position = Offset(s.width / 2, barY - GameConstants.ballRadius - 2);
            ball.velocity = Offset.zero;
            _leftInput    = 0;
            _rightInput   = 0;
          });
          widget.onScoreUpdate(_score, _timeLeft.toInt());
        }
        return;
      }

      if (widget.levelData.deadHoleIndices.contains(i)) {
        setState(() {
          _gameOver = true;
          AudioManager.instance.playLose();
          widget.onGameEnd(_score, widget.levelData.level, false);
        });
        return;
      }
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────
  void setLeftInput(double v)  => _leftInput  = v;
  void setRightInput(double v) => _rightInput = v;

  void addBonusTime(int s) {
    setState(() => _timeLeft += s);
    widget.onScoreUpdate(_score, _timeLeft.toInt());
  }

  void resetAndResume(int bonus) {
    if (!mounted || _size == null) return;
    final s    = _size!;
    final barY = s.height * 0.73;
    ball.position = Offset(s.width / 2, barY - GameConstants.ballRadius - 2);
    ball.velocity = Offset.zero;
    bar.leftY  = bar.rightY  = barY;
    bar.targetLeftY = bar.targetRightY = barY;
    _leftInput  = 0;
    _rightInput = 0;
    _completedTargets.clear();
    setState(() { _gameOver = false; _timeLeft += bonus; });
    _gameTimer?.cancel();
    _startTimer();
    _lastFrame = null;
    _loop.stop();
    _loop.forward();
    widget.onScoreUpdate(_score, _timeLeft.toInt());
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _loop.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_size == null) return const SizedBox.expand();
    final s   = _size!;
    final eps = bar.getEndpoints(s);

    return Stack(children: [
      // Background
      Positioned.fill(child: Image.asset('assets/images/game_bg.jpg', fit: BoxFit.cover)),
      Positioned.fill(child: Container(color: Colors.black.withOpacity(0.15))),

      // Holes
      ...List.generate(widget.levelData.holePositions.length, (i) {
        final pos      = widget.levelData.holePositions[i];
        final isTgt    = widget.levelData.targetHoleIndices.contains(i);
        final isDead   = widget.levelData.deadHoleIndices.contains(i);
        final isDone   = _completedTargets.contains(i);
        final r        = GameConstants.holeRadius;
        final col      = isDone    ? Colors.grey
                       : isTgt    ? GameConstants.neonGreen
                       : isDead   ? GameConstants.neonRed
                                  : Colors.white.withOpacity(0.25);
        return Positioned(
          left: pos.dx - r, top: pos.dy - r,
          child: Container(
            width: r * 2, height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? Colors.grey.withOpacity(0.2)
                   : isTgt ? GameConstants.neonGreen.withOpacity(0.25)
                   : isDead ? GameConstants.neonRed.withOpacity(0.25)
                            : Colors.black.withOpacity(0.45),
              border: Border.all(color: col, width: isTgt || isDead ? 3 : 1.5),
              boxShadow: isDone ? null : (isTgt || isDead)
                  ? [BoxShadow(color: col.withOpacity(0.35),
                               blurRadius: 10, spreadRadius: 2)]
                  : null,
            ),
            child: Center(
              child: Text(isDone ? '✓' : '',
                style: const TextStyle(color: Colors.white70,
                                       fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }),

      // Bar
      CustomPaint(size: s, painter: _BarPainter(eps[0], eps[1])),

      // Ball
      Positioned(
        left: ball.position.dx - ball.radius,
        top:  ball.position.dy - ball.radius,
        child: Container(
          width: ball.radius * 2, height: ball.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Colors.white, Color(0xFFDDDDDD), Color(0xFF888888)],
              stops:  [0.0, 0.35, 1.0],
            ),
            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3),
                                  blurRadius: 6, spreadRadius: 1)],
          ),
        ),
      ),

      // HUD
      Positioned(
        top:  MediaQuery.of(context).padding.top + 8,
        left: 12, right: 12,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pill('LEVEL ${widget.levelData.level}',
                  GameConstants.goldColor, 13),
            // Progress counter: targets hit / total
            _pill(
              '${_completedTargets.length}/${widget.levelData.targetHoleIndices.length} ●',
              GameConstants.neonGreen, 13,
            ),
            _timerPill(),
          ],
        ),
      ),
    ]);
  }

  Widget _pill(String t, Color c, double fs) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.65),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: c.withOpacity(0.35)),
    ),
    child: Text(t, style: TextStyle(color: c, fontSize: fs,
                                    fontWeight: FontWeight.bold)),
  );

  Widget _timerPill() {
    final urgent = _timeLeft <= 8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: urgent ? GameConstants.neonRed.withOpacity(0.3)
                      : Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: urgent ? GameConstants.neonRed : Colors.white.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(Icons.timer, size: 16,
             color: urgent ? GameConstants.neonRed : Colors.white70),
        const SizedBox(width: 4),
        Text('${_timeLeft.toInt()}s',
          style: TextStyle(
            color: urgent ? GameConstants.neonRed : Colors.white,
            fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// =============================================================================
// Bar painter
// =============================================================================
class _BarPainter extends CustomPainter {
  final Offset a, b;
  _BarPainter(this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..strokeWidth = GameConstants.barHeight + 8
      ..strokeCap   = StrokeCap.round
      ..color       = Colors.amber.withOpacity(0.14)
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 6);

    final bar = Paint()
      ..strokeWidth = GameConstants.barHeight
      ..strokeCap   = StrokeCap.round
      ..shader      = LinearGradient(colors: [
          Colors.amber.shade300.withOpacity(0.85),
          Colors.amber.shade400,
          Colors.amber.shade300.withOpacity(0.85),
        ]).createShader(Rect.fromPoints(a, b));

    final shine = Paint()
      ..strokeWidth = 2
      ..strokeCap   = StrokeCap.round
      ..color       = Colors.white.withOpacity(0.45);

    canvas.drawLine(a, b, glow);
    canvas.drawLine(a, b, bar);

    // Highlight along top edge
    final ang = (b - a).direction;
    final off = Offset(-sin(ang) * 2, cos(ang) * 2);
    canvas.drawLine(a + off, b + off, shine);
  }

  @override bool shouldRepaint(covariant CustomPainter _) => true;
}
