import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';

// =============================================================================
// GAME MECHANIC — "basin of water"
//
// The bar is a tray. The ball rests on it.
// Left joystick lifts/lowers the LEFT end of the tray.
// Right joystick lifts/lowers the RIGHT end.
// When the tray tilts, the ball rolls toward the lower end — just like
// water sliding in a basin you carry on your head.
// When the ball reaches an edge it falls off and drops into a hole below.
//
// Physics summary:
//   • On bar : gravity component along bar surface drives gentle rolling.
//              Surface friction slows the ball when tray is level.
//   • Off bar: pure freefall under full gravity.
//   • No launch / catapult mechanics — only natural motion.
// =============================================================================

class Ball {
  Offset position;
  Offset velocity;
  final double radius;

  Ball({required this.position,
        this.velocity = Offset.zero,
        this.radius   = GameConstants.ballRadius});

  /// [barAngle]  – bar tilt angle in radians
  /// [barY]      – bar surface Y at ball's current X (from Bar.getYatX)
  /// [onBar]     – whether ball is currently resting on bar surface
  void update(double dt, double barAngle, double barY, bool wasOnBar,
              Size screenSize) {
    // Sub-step for stability
    for (int i = 0; i < 2; i++) {
      _step(dt / 2, barAngle, barY, screenSize);
    }
  }

  void _step(double dt, double barAngle, double barY, Size screenSize) {
    final barHW  = GameConstants.barWidth / 2;
    final barL   = screenSize.width / 2 - barHW;
    final barR   = screenSize.width / 2 + barHW;

    // Is ball within bar's horizontal span?
    final inBarX = position.dx > barL - radius * 0.5 &&
                   position.dx < barR + radius * 0.5;
    // Is ball touching the bar surface?
    final touching = inBarX && (position.dy + radius) >= barY - 1;

    if (touching) {
      // ── Ball is ON the bar ─────────────────────────────────────────────

      // Snap to surface
      position = Offset(position.dx, barY - radius);

      // Gravity component ALONG bar surface → makes ball roll.
      // sin(angle) gives component parallel to tilt.
      // Multiplier 0.55 = gentle, basin-like feel.
      final rollAccel = GameConstants.gravity * sin(barAngle) * 0.55;
      velocity = Offset(velocity.dx + rollAccel * dt, 0.0);
      // Zero out vertical velocity while on bar — no bouncing on surface.

      // Rolling friction: decelerates ball when bar is level.
      // 0.88 per step at 120Hz ≈ 0.88^120 = very small — ball stops quickly
      // when tray is level, rolls freely when tilted.
      velocity = Offset(velocity.dx * 0.88, 0.0);

    } else {
      // ── Ball is AIRBORNE (fell off edge or above bar) ──────────────────

      // Full gravity — natural freefall.
      velocity = Offset(velocity.dx, velocity.dy + GameConstants.gravity * dt);

      // Tiny air resistance so ball doesn't fly forever horizontally.
      velocity = Offset(velocity.dx * 0.998, velocity.dy * 0.998);
    }

    // ── Integrate position ─────────────────────────────────────────────────
    position = Offset(
      position.dx + velocity.dx * dt,
      position.dy + velocity.dy * dt,
    );

    // ── Horizontal speed cap (prevents runaway on steep tilt) ──────────────
    const maxHorizSpeed = 600.0;
    if (velocity.dx.abs() > maxHorizSpeed) {
      velocity = Offset(velocity.dx.sign * maxHorizSpeed, velocity.dy);
    }
  }
}

// =============================================================================
// Bar — two independently controlled endpoints
// =============================================================================
class Bar {
  double leftY;
  double rightY;
  double targetLeftY;
  double targetRightY;

  Bar({this.leftY        = 400,
       this.rightY       = 400,
       this.targetLeftY  = 400,
       this.targetRightY = 400});

  double get angle => atan2(rightY - leftY, GameConstants.barWidth);

  double getYatX(double x, Size screenSize) {
    final t = (x - (screenSize.width / 2 - GameConstants.barWidth / 2)) /
              GameConstants.barWidth;
    return leftY + (rightY - leftY) * t.clamp(0.0, 1.0);
  }

  List<Offset> endpoints(Size screenSize) {
    final hw = GameConstants.barWidth / 2;
    return [
      Offset(screenSize.width / 2 - hw, leftY),
      Offset(screenSize.width / 2 + hw, rightY),
    ];
  }

  void update(double dt) {
    // Smooth lag coefficient — feels like physical inertia of a real tray.
    // Lower = more sluggish (heavier tray), Higher = more responsive.
    final k = min(1.0, dt * 10.0);
    leftY  += (targetLeftY  - leftY)  * k;
    rightY += (targetRightY - rightY) * k;
  }
}

// =============================================================================
// GameEngine widget
// =============================================================================
class GameEngine extends StatefulWidget {
  final LevelData  levelData;
  final Function(int score, int level, bool won) onGameEnd;
  final Function(int score, int timeLeft)        onScoreUpdate;
  final VoidCallback                             onPause;

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

class GameEngineState extends State<GameEngine>
    with SingleTickerProviderStateMixin {

  late Ball ball;
  late Bar  bar;

  // Joystick inputs — range -1.0 (full up) to +1.0 (full down)
  double _leftInput  = 0.0;
  double _rightInput = 0.0;

  int    _score    = 0;
  double _timeLeft = 30.0;
  Timer? _timer;
  bool   _gameOver = false;
  final  Set<int> _completedTargets = {};

  late AnimationController _loop;
  DateTime? _lastFrame;
  Size?     _size;

  // Bar rest position in pixels — set once on init
  double _barRestY = 0;

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
    _size      = s;
    _barRestY  = s.height * LevelData.barRestFraction;

    bar = Bar(
      leftY: _barRestY, rightY: _barRestY,
      targetLeftY: _barRestY, targetRightY: _barRestY,
    );
    ball = Ball(
      position: Offset(s.width / 2, _barRestY - GameConstants.ballRadius - 1),
    );
    _completedTargets.clear();
    _loop.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
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

    final s    = _size!;
    final minY = GameConstants.minBarY * s.height;

    // ── Map joystick input → bar endpoint positions ─────────────────────────
    //
    // Joystick at -1 (knob full UP)   → that side of bar rises toward minY
    // Joystick at  0 (knob centred)   → that side returns to rest position
    // Joystick at +1 (knob full DOWN) → that side dips slightly below rest
    //
    // upTravel controls how high each end can rise — this determines
    // the maximum tilt angle. Keep it proportional to bar height so the
    // tilt is physically believable (basin, not see-saw).
    final upTravel   = _barRestY - minY;          // full upward travel
    final downTravel = s.height * 0.055;           // small downward dip allowed

    bar.targetLeftY = (_barRestY +
        _leftInput * (_leftInput < 0 ? upTravel : downTravel))
        .clamp(minY, _barRestY + downTravel);

    bar.targetRightY = (_barRestY +
        _rightInput * (_rightInput < 0 ? upTravel : downTravel))
        .clamp(minY, _barRestY + downTravel);

    // Hard-clamp tilt angle — prevents extreme tilts that feel unnatural
    if (bar.angle.abs() > GameConstants.maxTiltAngle) {
      final maxDy = tan(GameConstants.maxTiltAngle) * GameConstants.barWidth;
      if (bar.rightY > bar.leftY) {
        bar.targetRightY = bar.targetLeftY + maxDy;
      } else {
        bar.targetLeftY  = bar.targetRightY + maxDy;
      }
    }

    bar.update(dt);

    // ── Update ball ──────────────────────────────────────────────────────────
    final barYatBall = bar.getYatX(ball.position.dx, s);
    ball.update(dt, bar.angle, barYatBall, false, s);

    // ── Hole collision ───────────────────────────────────────────────────────
    _checkHoles(s);

    // ── Ball out of bounds ───────────────────────────────────────────────────
    if (ball.position.dy > s.height + 60) {
      setState(() {
        _gameOver = true;
        AudioManager.instance.playLose();
        widget.onGameEnd(_score, widget.levelData.level, false);
      });
      return;
    }

    setState(() {});
  }

  void _checkHoles(Size s) {
    for (int i = 0; i < widget.levelData.holePositions.length; i++) {
      if (_completedTargets.contains(i)) continue;
      final dist = (ball.position - widget.levelData.holePositions[i]).distance;
      if (dist >= GameConstants.holeRadius) continue;

      if (widget.levelData.targetHoleIndices.contains(i)) {
        _completedTargets.add(i);
        AudioManager.instance.playClick();

        final allDone = _completedTargets.length ==
            widget.levelData.targetHoleIndices.length;

        if (allDone) {
          _score += GameConstants.pointsPerLevel * widget.levelData.level +
                    _timeLeft.toInt() * 10 +
                    _completedTargets.length * 50;
          setState(() => _gameOver = true);
          AudioManager.instance.playWin();
          widget.onGameEnd(_score, widget.levelData.level, true);
        } else {
          // Reset ball to bar centre for next target
          setState(() {
            ball.position = Offset(s.width / 2,
                _barRestY - GameConstants.ballRadius - 1);
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
    final s = _size!;
    bar.leftY  = bar.rightY  = _barRestY;
    bar.targetLeftY = bar.targetRightY = _barRestY;
    ball.position = Offset(s.width / 2, _barRestY - GameConstants.ballRadius - 1);
    ball.velocity = Offset.zero;
    _leftInput    = 0;
    _rightInput   = 0;
    _completedTargets.clear();
    setState(() { _gameOver = false; _timeLeft += bonus; });
    _timer?.cancel();
    _startTimer();
    _lastFrame = null;
    _loop
      ..stop()
      ..forward();
    widget.onScoreUpdate(_score, _timeLeft.toInt());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loop.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_size == null) return const SizedBox.expand();
    final s  = _size!;
    final ep = bar.endpoints(s);

    return Stack(children: [

      // Background
      Positioned.fill(
          child: Image.asset('assets/images/game_bg.jpg', fit: BoxFit.cover)),
      Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.12))),

      // ── Holes (below bar) ────────────────────────────────────────────────
      ...List.generate(widget.levelData.holePositions.length, (i) {
        final pos    = widget.levelData.holePositions[i];
        final isTgt  = widget.levelData.targetHoleIndices.contains(i);
        final isDead = widget.levelData.deadHoleIndices.contains(i);
        final isDone = _completedTargets.contains(i);
        final r      = GameConstants.holeRadius;

        Color borderCol = isDone    ? Colors.grey
                        : isTgt    ? GameConstants.neonGreen
                        : isDead   ? GameConstants.neonRed
                                   : Colors.white.withOpacity(0.3);

        return Positioned(
          left: pos.dx - r,
          top:  pos.dy - r,
          child: Container(
            width: r * 2, height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? Colors.grey.withOpacity(0.15)
                   : isTgt ? GameConstants.neonGreen.withOpacity(0.22)
                   : isDead ? GameConstants.neonRed.withOpacity(0.22)
                            : Colors.black.withOpacity(0.50),
              border: Border.all(color: borderCol, width: 2.5),
              boxShadow: isDone ? null
                  : (isTgt || isDead) ? [BoxShadow(
                      color:       borderCol.withOpacity(0.4),
                      blurRadius:  10,
                      spreadRadius: 2,
                    )] : null,
            ),
            child: Center(
              child: isDone
                ? const Icon(Icons.check, color: Colors.white60, size: 18)
                : isTgt
                    ? Container(width: r * 0.6, height: r * 0.6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GameConstants.neonGreen.withOpacity(0.55),
                        ))
                    : isDead
                        ? Container(width: r * 0.6, height: r * 0.6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: GameConstants.neonRed.withOpacity(0.5),
                            ))
                        : null,
            ),
          ),
        );
      }),

      // ── Bar ──────────────────────────────────────────────────────────────
      CustomPaint(size: s, painter: _BarPainter(ep[0], ep[1])),

      // ── Ball ─────────────────────────────────────────────────────────────
      Positioned(
        left: ball.position.dx - ball.radius,
        top:  ball.position.dy - ball.radius,
        child: Container(
          width:  ball.radius * 2,
          height: ball.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Colors.white, Color(0xFFDDDDDD), Color(0xFF777777)],
              stops:  [0.0, 0.4, 1.0],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.35),
                        blurRadius: 6, offset: const Offset(2, 3)),
              BoxShadow(color: Colors.white.withOpacity(0.25),
                        blurRadius: 4, spreadRadius: 0),
            ],
          ),
        ),
      ),

      // ── HUD ──────────────────────────────────────────────────────────────
      Positioned(
        top:  MediaQuery.of(context).padding.top + 8,
        left: 10, right: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pill('LVL ${widget.levelData.level}', GameConstants.goldColor),
            _pill(
              '${_completedTargets.length}/${widget.levelData.targetHoleIndices.length}  ●',
              GameConstants.neonGreen,
            ),
            _timerPill(),
          ],
        ),
      ),
    ]);
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color:        Colors.black.withOpacity(0.65),
      borderRadius: BorderRadius.circular(18),
      border:       Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(text, style: TextStyle(
      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
  );

  Widget _timerPill() {
    final urgent = _timeLeft <= 8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: urgent
            ? GameConstants.neonRed.withOpacity(0.28)
            : Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: urgent ? GameConstants.neonRed : Colors.white.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 14,
             color: urgent ? GameConstants.neonRed : Colors.white70),
        const SizedBox(width: 4),
        Text('${_timeLeft.toInt()}s', style: TextStyle(
          color: urgent ? GameConstants.neonRed : Colors.white,
          fontSize: 13, fontWeight: FontWeight.bold)),
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
    // Subtle glow
    canvas.drawLine(a, b, Paint()
      ..strokeWidth = GameConstants.barHeight + 10
      ..strokeCap   = StrokeCap.round
      ..color       = Colors.amber.withOpacity(0.12)
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 6));

    // Main bar
    canvas.drawLine(a, b, Paint()
      ..strokeWidth = GameConstants.barHeight
      ..strokeCap   = StrokeCap.round
      ..shader      = LinearGradient(colors: [
          Colors.amber.shade300.withOpacity(0.9),
          Colors.amber.shade400,
          Colors.amber.shade300.withOpacity(0.9),
        ]).createShader(Rect.fromPoints(a, b)));

    // Top highlight (gives 3-D depth)
    final ang = (b - a).direction;
    final off = Offset(-sin(ang) * 2.5, cos(ang) * 2.5);
    canvas.drawLine(a + off, b + off, Paint()
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round
      ..color       = Colors.white.withOpacity(0.50));
  }

  @override bool shouldRepaint(covariant CustomPainter _) => true;
}
