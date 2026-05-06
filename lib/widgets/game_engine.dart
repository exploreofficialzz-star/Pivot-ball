import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';

class Ball {
  Offset position;
  Offset velocity;
  double radius;

  Ball({
    required this.position,
    this.velocity = Offset.zero,
    this.radius = GameConstants.ballRadius,
  });

  void update(double dt, double barAngle, double barY, Size screenSize) {
    // Gravity along the bar
    final gravityAlong = GameConstants.gravity * sin(barAngle);
    
    // Apply gravity
    velocity = Offset(
      velocity.dx + gravityAlong * dt,
      velocity.dy + GameConstants.gravity * 0.1 * dt, // Slight vertical gravity
    );
    
    // Apply friction
    velocity = Offset(
      velocity.dx * GameConstants.friction,
      velocity.dy * GameConstants.friction,
    );
    
    // Update position
    position = Offset(
      position.dx + velocity.dx * dt,
      position.dy + velocity.dy * dt,
    );
    
    // Keep ball on bar
    final barHalfWidth = GameConstants.barWidth / 2;
    final barLeft = screenSize.width / 2 - barHalfWidth;
    final barRight = screenSize.width / 2 + barHalfWidth;
    
    // Bar surface Y at ball's X position
    final barSurfaceY = barY - cos(barAngle) * (position.dx - screenSize.width / 2) * tan(barAngle);
    
    // Keep ball above bar
    if (position.dy > barSurfaceY - radius) {
      position = Offset(position.dx, barSurfaceY - radius);
      velocity = Offset(velocity.dx, velocity.dy * -GameConstants.bounceDamping);
      
      // Add rolling friction when on bar
      velocity = Offset(velocity.dx * 0.95, velocity.dy);
    }
    
    // Wall collisions
    if (position.dx < barLeft + radius) {
      position = Offset(barLeft + radius, position.dy);
      velocity = Offset(-velocity.dx * 0.5, velocity.dy);
    }
    if (position.dx > barRight - radius) {
      position = Offset(barRight - radius, position.dy);
      velocity = Offset(-velocity.dx * 0.5, velocity.dy);
    }
    
    // Bottom boundary (fall off)
    if (position.dy > screenSize.height + radius * 2) {
      // Ball fell off
    }
  }

  Rect get bounds => Rect.fromCircle(center: position, radius: radius);
}

class Bar {
  double leftY;
  double rightY;
  double targetLeftY;
  double targetRightY;

  Bar({
    this.leftY = 0.5,
    this.rightY = 0.5,
    this.targetLeftY = 0.5,
    this.targetRightY = 0.5,
  });

  double get angle => atan2(rightY - leftY, GameConstants.barWidth);
  
  double getYatX(double x, Size screenSize) {
    final barX = (x - screenSize.width / 2) / (GameConstants.barWidth / 2);
    final t = (barX + 1) / 2;
    return leftY + (rightY - leftY) * t;
  }

  void update(double dt) {
    // Smooth interpolation to target
    leftY += (targetLeftY - leftY) * min(1.0, dt * 10);
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
  late Bar bar;
  double _leftInput = 0;
  double _rightInput = 0;
  int _score = 0;
  double _timeLeft = 60;
  Timer? _gameTimer;
  bool _gameOver = false;
  late AnimationController _gameLoopController;
  DateTime? _lastFrameTime;
  Size? _screenSize;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.levelData.timeLimit;
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_gameLoop);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGame();
    });
  }

  void _initGame() {
    final size = MediaQuery.of(context).size;
    _screenSize = size;
    
    final barY = size.height * 0.75;
    bar = Bar(
      leftY: barY,
      rightY: barY,
      targetLeftY: barY,
      targetRightY: barY,
    );
    
    ball = Ball(
      position: Offset(size.width / 2, barY - GameConstants.ballRadius - 5),
    );
    
    _gameLoopController.forward();
    _startTimer();
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeft--;
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
    final dt = _lastFrameTime != null
        ? min((now.difference(_lastFrameTime!).inMicroseconds / 1000000.0), 0.05)
        : 0.016;
    _lastFrameTime = now;
    
    // Update bar from inputs
    final size = _screenSize!;
    final range = (GameConstants.maxBarY - GameConstants.minBarY) * size.height;
    final minY = GameConstants.minBarY * size.height;
    
    bar.targetLeftY = (bar.leftY - _leftInput * dt * range * 2).clamp(
      minY,
      GameConstants.maxBarY * size.height,
    );
    bar.targetRightY = (bar.rightY - _rightInput * dt * range * 2).clamp(
      minY,
      GameConstants.maxBarY * size.height,
    );
    
    bar.update(dt);
    
    // Clamp angle
    final angle = bar.angle;
    if (angle.abs() > GameConstants.maxTiltAngle) {
      final sign = angle.sign;
      final maxDy = tan(GameConstants.maxTiltAngle) * GameConstants.barWidth;
      if (bar.targetRightY > bar.targetLeftY) {
        bar.targetRightY = bar.targetLeftY + sign * maxDy;
      } else {
        bar.targetLeftY = bar.targetRightY - sign * maxDy;
      }
    }
    
    // Update ball
    ball.update(dt, bar.angle, bar.getYatX(ball.position.dx, size), size);
    
    // Check hole collisions
    _checkHoles();
    
    // Check ball fell off
    if (ball.position.dy > size.height + 50) {
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
      final dist = (ball.position - holePos).distance;
      
      if (dist < GameConstants.holeRadius - 5) {
        if (i == widget.levelData.targetHoleIndex) {
          // Win!
          setState(() {
            _gameOver = true;
            
            _score += GameConstants.pointsPerLevel * widget.levelData.level + (_timeLeft * 10).toInt();
            AudioManager.instance.playWin();
            widget.onGameEnd(_score, widget.levelData.level, true);
          });
          return;
        } else if (widget.levelData.deadHoleIndices.contains(i)) {
          // Dead hole - lose
          setState(() {
            _gameOver = true;
            
            AudioManager.instance.playLose();
            widget.onGameEnd(_score, widget.levelData.level, false);
          });
          return;
        }
      }
    }
  }

  void setLeftInput(double value) {
    _leftInput = value;
  }

  void setRightInput(double value) {
    _rightInput = value;
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _gameLoopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_screenSize == null) {
      return const SizedBox.expand();
    }
    
    final size = _screenSize!;
    final barEndpoints = bar.getEndpoints(size);
    
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Image.asset(
            'assets/images/game_bg.jpg',
            fit: BoxFit.cover,
          ),
        ),
        
        // Dark overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
        
        // Holes
        ...List.generate(widget.levelData.holePositions.length, (index) {
          final pos = widget.levelData.holePositions[index];
          final isTarget = index == widget.levelData.targetHoleIndex;
          final isDead = widget.levelData.deadHoleIndices.contains(index);
          
          return Positioned(
            left: pos.dx - GameConstants.holeRadius,
            top: pos.dy - GameConstants.holeRadius,
            child: Container(
              width: GameConstants.holeRadius * 2,
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
                      : isDead
                          ? GameConstants.neonRed
                          : Colors.white.withOpacity(0.3),
                  width: isTarget || isDead ? 3 : 1.5,
                ),
                boxShadow: isTarget
                    ? [
                        BoxShadow(
                          color: GameConstants.neonGreen.withOpacity(0.6),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ]
                    : isDead
                        ? [
                            BoxShadow(
                              color: GameConstants.neonRed.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
              ),
              child: Center(
                child: Container(
                  width: GameConstants.holeRadius * 1.2,
                  height: GameConstants.holeRadius * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
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
            end: barEndpoints[1],
            color: Colors.amber.shade400,
          ),
        ),
        
        // Ball
        Positioned(
          left: ball.position.dx - ball.radius,
          top: ball.position.dy - ball.radius,
          child: Container(
            width: ball.radius * 2,
            height: ball.radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white,
                  Colors.grey.shade300,
                  Colors.grey.shade500,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        
        // UI Overlay
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Level
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: GameConstants.goldColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  'LEVEL ${widget.levelData.level}',
                  style: const TextStyle(
                    color: GameConstants.goldColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _timeLeft <= 10
                      ? GameConstants.neonRed.withOpacity(0.3)
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _timeLeft <= 10
                        ? GameConstants.neonRed
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 10
                          ? GameConstants.neonRed
                          : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_timeLeft.toInt()}s',
                      style: TextStyle(
                        color: _timeLeft <= 10
                            ? GameConstants.neonRed
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: GameConstants.neonBlue.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  '$_score',
                  style: const TextStyle(
                    color: GameConstants.neonBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BarPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  BarPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = GameConstants.barHeight
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.8),
          color,
          color.withOpacity(0.8),
        ],
      ).createShader(Rect.fromPoints(start, end));

    // Glow effect
    final glowPaint = Paint()
      ..strokeWidth = GameConstants.barHeight + 8
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawLine(start, end, glowPaint);
    canvas.drawLine(start, end, paint);
    
    // Highlight line
    final highlightPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.5);
    
    final offset = Offset(-sin((end - start).direction) * 1.5, 
                           cos((end - start).direction) * 1.5);
    canvas.drawLine(start + offset, end + offset, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
