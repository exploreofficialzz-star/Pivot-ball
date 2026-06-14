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
  static const double holeRadius     = 12.0;
  static const double bumperRadius   = 8.0;
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
  // Bar rests at 75% of screen height. Holes are placed ABOVE the bar
  // (20–55% zone) so the ball must be launched upward to reach them.
  // Holes and bumpers are constrained to the BAR'S horizontal span so
  // nothing appears outside the stick's reach.
  static const double barRestFraction = 0.75;

  static LevelData generate(int level, Size screenSize) {
    final rng = Random(level * 1337 + 7);

    final int numTargets = _numTargets(level);
    final int numDead    = _numDead(level);
    final int numNeutral = max(0, level ~/ 8);
    final int numHoles   = numTargets + numDead + numNeutral;
    final int numBumpers = _numBumperPegs(level);

    // ── Horizontal constraint — stay within the bar's reach ─────────────────
    final barHalfW = barWidth / 2;
    final barLeft  = screenSize.width / 2 - barHalfW;
    final barRight = screenSize.width / 2 + barHalfW;
    final holeMargin   = holeRadius   + 4;
    final bumperMargin = bumperRadius + 4;

    // ── Hole zone: ABOVE the bar (20 %–55 % of screen height) ───────────────
    final holeTopY    = screenSize.height * 0.20;
    final holeBottomY = screenSize.height * 0.55;
    final holeRangeY  = holeBottomY - holeTopY;

    final cols = min(numHoles, 4).clamp(1, 4);
    final rows = (numHoles / cols).ceil();
    final colW = (barRight - barLeft - holeMargin * 2) / max(cols - 1, 1);

    final List<Offset> holes = [];
    for (int i = 0; i < numHoles; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final jx  = (rng.nextDouble() - 0.5) * colW * 0.35;
      final jy  = (rng.nextDouble() - 0.5) * (holeRangeY / (rows + 1)) * 0.35;
      final x   = (barLeft + holeMargin) + colW * col + jx;
      final y   = holeTopY + (holeRangeY / (rows + 1)) * (row + 1) + jy;
      holes.add(Offset(
        x.clamp(barLeft + holeMargin, barRight - holeMargin),
        y.clamp(holeTopY + 10, holeBottomY - 10),
      ));
    }

    final indices = List<int>.generate(numHoles, (i) => i)..shuffle(rng);
    final targetIndices = indices.sublist(0, numTargets);
    final deadIndices   = indices.sublist(numTargets, numTargets + numDead);

    // ── Bumper pegs: mid zone between holes and bar, within bar width ────────
    final bumperTopY    = screenSize.height * 0.54;
    final bumperBottomY = screenSize.height * 0.70;
    final List<Offset> bumpers = [];
    for (int i = 0; i < numBumpers; i++) {
      bumpers.add(Offset(
        (barLeft + bumperMargin +
            rng.nextDouble() * (barRight - barLeft - bumperMargin * 2))
            .clamp(barLeft + bumperMargin, barRight - bumperMargin),
        (bumperTopY + rng.nextDouble() * (bumperBottomY - bumperTopY))
            .clamp(bumperTopY + 10, bumperBottomY - 10),
      ));
    }

    return LevelData(
      level:             level,
      holePositions:     holes,
      targetHoleIndices: targetIndices,
      deadHoleIndices:   deadIndices,
      timeLimit:         30.0,
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
    if (lv <= 3)  return 1;   // obstacle from the very first level
    if (lv <= 6)  return 2;
    if (lv <= 10) return 3;
    if (lv <= 15) return 4;
    if (lv <= 20) return 5;
    if (lv <= 30) return 6;
    if (lv <= 50) return min(6 + (lv - 30) ~/ 4, 9);
    return min(9 + (lv - 50) ~/ 5, 14);
  }

  static int _numBumperPegs(int lv) {
    if (lv < 4)   return 0;
    if (lv <= 6)  return 2;
    if (lv <= 10) return min(2 + (lv - 6), 5);
    if (lv <= 20) return min(5 + (lv - 10) ~/ 2, 10);
    if (lv <= 50) return min(10 + (lv - 20) ~/ 3, 16);
    return min(16 + (lv - 50) ~/ 5, 24);
  }

  static bool isMilestone(int level) => level > 0 && level % 25 == 0;
}
