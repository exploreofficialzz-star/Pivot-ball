import 'dart:math';
import 'package:flutter/material.dart';

class GameConstants {
  static const String appName = 'Pivot Ball';
  static const String appSubtitle = 'Retro Physics Challenge';
  static const String companyName = 'chAs';
  static const String companyFullName = 'chas tech group';
  
  // Physics
  static const double gravity = 800.0;
  static const double maxTiltAngle = 30.0 * pi / 180.0;
  static const double ballRadius = 14.0;
  static const double barHeight = 8.0;
  static const double barWidth = 280.0;
  static const double holeRadius = 22.0;
  static const double maxBarY = 0.75;
  static const double minBarY = 0.15;
  static const double friction = 0.98;
  static const double bounceDamping = 0.3;
  
  // Level
  static const int maxLevels = 50;
  static const double baseTimeLimit = 60.0;
  static const double timeDecayPerLevel = 0.8;
  static const int pointsPerLevel = 100;
  
  // Colors
  static const Color goldColor = Color(0xFFFFB800);
  static const Color darkGold = Color(0xFFCC8A00);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonRed = Color(0xFFFF3131);
  static const Color neonBlue = Color(0xFF00D4FF);
  static const Color woodBrown = Color(0xFF8B6914);
  static const Color darkWood = Color(0xFF3D2B1F);
  
  // Ad placement IDs (will be configured via AdManager)
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Test ID
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test ID
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Test ID
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

  static LevelData generate(int level, Size screenSize) {
    final random = Random(level * 1000);
    final playWidth = screenSize.width * 0.7;
    final playHeight = screenSize.height * 0.55;
    final startX = (screenSize.width - playWidth) / 2;
    final startY = screenSize.height * 0.18;
    
    final numHoles = min(3 + (level ~/ 3), 12);
    final List<Offset> holes = [];
    final Set<int> deadHoles = {};
    
    // Generate holes in a grid-like pattern
    final cols = 3;
    final rows = (numHoles / cols).ceil();
    
    for (int i = 0; i < numHoles; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final jitterX = (random.nextDouble() - 0.5) * playWidth * 0.15;
      final jitterY = (random.nextDouble() - 0.5) * playHeight * 0.1;
      
      final x = startX + (playWidth / (cols - 1)) * col + jitterX;
      final y = startY + (playHeight / (rows + 1)) * (row + 1) + jitterY;
      holes.add(Offset(x.clamp(startX + 20, startX + playWidth - 20), 
                       y.clamp(startY + 20, startY + playHeight - 20)));
    }
    
    // Target hole (higher levels = higher position)
    final targetIndex = random.nextInt(numHoles);
    
    // Dead holes for higher levels
    if (level > 5) {
      final numDead = min(level ~/ 5, numHoles - 1);
      while (deadHoles.length < numDead) {
        final idx = random.nextInt(numHoles);
        if (idx != targetIndex) {
          deadHoles.add(idx);
        }
      }
    }
    
    // Bumper pegs for higher levels
    List<Offset> bumpers = [];
    if (level > 10) {
      final numBumpers = min((level - 10) ~/ 3, 5);
      for (int i = 0; i < numBumpers; i++) {
        bumpers.add(Offset(
          startX + random.nextDouble() * playWidth,
          startY + random.nextDouble() * playHeight * 0.5,
        ));
      }
    }
    
    return LevelData(
      level: level,
      holePositions: holes,
      targetHoleIndex: targetIndex,
      deadHoleIndices: deadHoles.toList(),
      timeLimit: max(GameConstants.baseTimeLimit - (level * GameConstants.timeDecayPerLevel), 20.0),
      hasMovingHoles: level > 15,
      hasBumperPegs: level > 10,
      bumperPegs: bumpers,
    );
  }
}
