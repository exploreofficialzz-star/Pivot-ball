import 'dart:math';
import 'package:flutter/material.dart';

class GameConstants {
  static const String appName         = 'Pivot Ball';
  static const String appSubtitle     = 'Retro Physics Challenge';
  static const String companyName     = 'chAs';
  static const String companyFullName = 'chas tech group';

  // Physics
  static const double gravity        = 800.0;
  static const double maxTiltAngle   = 30.0 * pi / 180.0;
  static const double ballRadius     = 14.0;
  static const double barHeight      = 8.0;
  static const double barWidth       = 280.0;
  static const double holeRadius     = 22.0;
  static const double maxBarY        = 0.75;
  static const double minBarY        = 0.15;
  static const double friction       = 0.98;
  static const double bounceDamping  = 0.35;

  // Levels
  static const int    maxLevels      = 999999;
  static const int    pointsPerLevel = 100;

  // Colors
  static const Color goldColor = Color(0xFFFFB800);
  static const Color darkGold  = Color(0xFFCC8A00);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonRed   = Color(0xFFFF3131);
  static const Color neonBlue  = Color(0xFF00D4FF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Level difficulty table
//
//  Level  │ Green targets │ Red holes │ Time   │ Bumpers
//  ────────┼───────────────┼───────────┼────────┼────────
//  1       │ 1             │ 0         │ 45 s   │ 0
//  2-3     │ 1             │ 1         │ 45 s   │ 0
//  4-6     │ 2             │ 2         │ 70 s   │ 0
//  7-10    │ 2             │ 3         │ 70 s   │ 1-2
//  11-15   │ 3             │ 4         │ 90 s   │ 2-3
//  16-20   │ 3             │ 5         │ 90 s   │ 3-4
//  21-30   │ 4             │ 6         │ 110 s  │ 4-5
//  31-50   │ 4             │ 7-8       │ 100 s  │ 5-7
//  51+     │ 5+            │ growing   │ decay  │ growing
// ─────────────────────────────────────────────────────────────────────────────

class LevelData {
  final int          level;
  final List<Offset> holePositions;
  final List<int>    targetHoleIndices;  // ALL must be hit to win
  final List<int>    deadHoleIndices;    // instant lose on contact
  final double       timeLimit;
  final List<Offset> bumperPegs;

  LevelData({
    required this.level,
    required this.holePositions,
    required this.targetHoleIndices,
    this.deadHoleIndices = const [],
    this.timeLimit       = 45.0,
    this.bumperPegs      = const [],
  });

  // Convenience for legacy code
  int get targetHoleIndex =>
      targetHoleIndices.isNotEmpty ? targetHoleIndices.first : 0;

  // =========================================================================
  // Generator
  // =========================================================================
  static LevelData generate(int level, Size screenSize) {
    final rng = Random(level * 1337 + 7);

    // ── Difficulty params ─────────────────────────────────────────────────
    final int numTargets = _numTargets(level);
    final int numDead    = _numDead(level);
    final int numNeutral = max(1, level ~/ 5);        // neutral/empty holes
    final int numHoles   = numTargets + numDead + numNeutral;
    final double time    = _timeLimit(level, numTargets);

    // ── Hole positions ────────────────────────────────────────────────────
    final playW  = screenSize.width  * 0.78;
    final playH  = screenSize.height * 0.50;
    final startX = (screenSize.width  - playW) / 2;
    final startY = screenSize.height  * 0.17;

    final cols   = 3;
    final rows   = (numHoles / cols).ceil();
    final List<Offset> holes = [];

    for (int i = 0; i < numHoles; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final jx  = (rng.nextDouble() - 0.5) * playW * 0.18;
      final jy  = (rng.nextDouble() - 0.5) * playH * 0.12;
      final x   = startX + (playW / max(cols - 1, 1)) * col + jx;
      final y   = startY + (playH / (rows + 1)) * (row + 1) + jy;
      holes.add(Offset(
        x.clamp(startX + 28, startX + playW - 28),
        y.clamp(startY + 28, startY + playH - 28),
      ));
    }

    // ── Assign roles randomly ─────────────────────────────────────────────
    final indices = List<int>.generate(numHoles, (i) => i)..shuffle(rng);
    final targetIndices = indices.sublist(0, numTargets);
    final deadIndices   = indices.sublist(numTargets, numTargets + numDead);

    // ── Bumper pegs ───────────────────────────────────────────────────────
    final numBumpers = _numBumpers(level);
    final List<Offset> bumpers = [
      for (int i = 0; i < numBumpers; i++)
        Offset(
          startX + rng.nextDouble() * playW,
          startY + rng.nextDouble() * playH * 0.65,
        ),
    ];

    return LevelData(
      level:             level,
      holePositions:     holes,
      targetHoleIndices: targetIndices,
      deadHoleIndices:   deadIndices,
      timeLimit:         time,
      bumperPegs:        bumpers,
    );
  }

  // ── Difficulty curves ─────────────────────────────────────────────────────
  static int _numTargets(int lv) {
    if (lv <= 3)  return 1;
    if (lv <= 10) return 2;
    if (lv <= 20) return 3;
    if (lv <= 35) return 4;
    if (lv <= 55) return 5;
    return min(6 + (lv - 55) ~/ 10, 10);
  }

  static int _numDead(int lv) {
    if (lv == 1)  return 0;
    if (lv <= 3)  return 1;
    if (lv <= 6)  return 2;
    if (lv <= 10) return 3;
    if (lv <= 15) return 4;
    if (lv <= 20) return 5;
    if (lv <= 30) return 6;
    if (lv <= 50) return min(6 + (lv - 30) ~/ 4, 9);
    return min(9 + (lv - 50) ~/ 5, 14);
  }

  static int _numBumpers(int lv) {
    if (lv < 8)   return 0;
    if (lv <= 15) return lv - 7;
    if (lv <= 30) return min(8 + (lv - 15) ~/ 2, 12);
    return min(12 + (lv - 30) ~/ 5, 16);
  }

  /// Time increases with target count (more holes = more time needed),
  /// but decays slowly at high levels to maintain pressure.
  static double _timeLimit(int lv, int targets) {
    // Base per target
    const double perTarget = 22.0;
    // Bonus for early levels
    final double base = targets * perTarget + 10;
    // Gentle decay per level (max -25 s at level 100)
    final double decay = min((lv - 1) * 0.25, 25.0);
    return max(base - decay, targets * 14.0);
  }

  static bool isMilestone(int level) => level > 0 && level % 25 == 0;
}
