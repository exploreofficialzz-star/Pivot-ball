import 'dart:math';
import 'package:flutter/material.dart';

class GameConstants {
  static const String appName = 'Pivot Ball';
  static const String appSubtitle = 'Retro Physics Challenge';
  static const String companyName = 'chAs';
  static const String companyFullName = 'chas tech group';

  // Physics
  static const double gravity         = 800.0;
  static const double maxTiltAngle    = 30.0 * pi / 180.0;
  static const double ballRadius      = 14.0;
  static const double barHeight       = 8.0;
  static const double barWidth        = 280.0;
  static const double holeRadius      = 22.0;
  static const double maxBarY         = 0.75;
  static const double minBarY         = 0.15;
  static const double friction        = 0.98;
  static const double bounceDamping   = 0.35; // coefficient of restitution

  // Levels — no hard cap; game runs infinitely and scales forever
  static const int    maxLevels       = 999999;
  static const double baseTimeLimit   = 60.0;
  static const double timeDecayPerLevel = 0.8;
  static const int    pointsPerLevel  = 100;

  // Colors
  static const Color goldColor  = Color(0xFFFFB800);
  static const Color darkGold   = Color(0xFFCC8A00);
  static const Color neonGreen  = Color(0xFF39FF14);
  static const Color neonRed    = Color(0xFFFF3131);
  static const Color neonBlue   = Color(0xFF00D4FF);
  static const Color woodBrown  = Color(0xFF8B6914);
  static const Color darkWood   = Color(0xFF3D2B1F);

  // Test Ad IDs (replaced at build time via --dart-define)
  static const String bannerAdUnitId       = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId     = 'ca-app-pub-3940256099942544/5224354917';
}

class LevelData {
  final int level;
  final List<Offset> holePositions;
  final int targetHoleIndex;
  final List<int> deadHoleIndices;
  final double timeLimit;
  final bool hasMovingHoles;
  final bool hasBumperPegs;
  final List<Offset> bumperPegs;

  LevelData({
    required this.level,
    required this.holePositions,
    required this.targetHoleIndex,
    this.deadHoleIndices = const [],
    this.timeLimit = 60.0,
    this.hasMovingHoles = false,
    this.hasBumperPegs = false,
    this.bumperPegs = const [],
  });

  // -------------------------------------------------------------------------
  // Infinite level generator — scales difficulty forever, never stops
  // -------------------------------------------------------------------------
  static LevelData generate(int level, Size screenSize) {
    final random    = Random(level * 1337);
    final playWidth = screenSize.width * 0.7;
    final playHeight= screenSize.height * 0.55;
    final startX    = (screenSize.width - playWidth) / 2;
    final startY    = screenSize.height * 0.18;

    // Holes: 3 at level 1, grows every 2 levels, caps at 16
    final numHoles = min(3 + (level ~/ 2), 16);

    // Grid layout
    const cols  = 3;
    final rows  = (numHoles / cols).ceil();
    final List<Offset> holes = [];

    for (int i = 0; i < numHoles; i++) {
      final row    = i ~/ cols;
      final col    = i % cols;
      final jitterX = (random.nextDouble() - 0.5) * playWidth  * 0.18;
      final jitterY = (random.nextDouble() - 0.5) * playHeight * 0.12;

      final x = startX + (playWidth  / max(cols - 1, 1)) * col + jitterX;
      final y = startY + (playHeight / (rows + 1))        * (row + 1) + jitterY;
      holes.add(Offset(
        x.clamp(startX + 24, startX + playWidth  - 24),
        y.clamp(startY + 24, startY + playHeight - 24),
      ));
    }

    // Target hole
    final targetIndex = random.nextInt(numHoles);

    // Dead holes — start at level 3, grow every 4 levels, cap at numHoles-1
    final Set<int> deadHoles = {};
    if (level > 3) {
      final numDead = min((level - 3) ~/ 4 + 1, numHoles - 1);
      int attempts = 0;
      while (deadHoles.length < numDead && attempts < 100) {
        final idx = random.nextInt(numHoles);
        if (idx != targetIndex) deadHoles.add(idx);
        attempts++;
      }
    }

    // Bumper pegs — start at level 8, grow every 3 levels, cap at 10
    List<Offset> bumpers = [];
    if (level > 8) {
      final numBumpers = min((level - 8) ~/ 3 + 1, 10);
      for (int i = 0; i < numBumpers; i++) {
        bumpers.add(Offset(
          startX + random.nextDouble() * playWidth,
          startY + random.nextDouble() * playHeight * 0.6,
        ));
      }
    }

    // Time limit: starts at 60s, shrinks per level, floor rises at 15s for level 100+
    final minTime   = level > 100 ? 12.0 : 15.0;
    final timeLimit = max(
      GameConstants.baseTimeLimit - (level * GameConstants.timeDecayPerLevel),
      minTime,
    );

    return LevelData(
      level:          level,
      holePositions:  holes,
      targetHoleIndex:targetIndex,
      deadHoleIndices:deadHoles.toList(),
      timeLimit:      timeLimit,
      hasMovingHoles: level > 15,
      hasBumperPegs:  level > 8,
      bumperPegs:     bumpers,
    );
  }

  // Milestone check — every 25 levels is a "round"
  static bool isMilestone(int level) => level > 0 && level % 25 == 0;
}
