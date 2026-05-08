import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';
import '../utils/storage_manager.dart';
import '../utils/ad_manager.dart';
import 'menu_screen.dart';
import 'gameplay_screen.dart';
import 'leaderboard_screen.dart';

class GameOverScreen extends StatefulWidget {
  final int score;
  final int level;
  final bool won;
  final bool gameComplete;

  const GameOverScreen({
    super.key,
    required this.score,
    required this.level,
    required this.won,
    this.gameComplete = false,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late ConfettiController _confettiController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _isNewHighScore = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AudioManager.instance.resumeMusic();
    
    _checkHighScore();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    
    if (widget.won || widget.gameComplete) {
      _confettiController.play();
    }
    
    _animController.forward();
  }

  void _checkHighScore() {
    final highScore = StorageManager.instance.getHighScore();
    if (widget.score > highScore && widget.score > 0) {
      _isNewHighScore = true;
    }
    
    // Auto-save to leaderboard
    if (widget.score > 0) {
      StorageManager.instance.addLeaderboardEntry(
        LeaderboardEntry(
          name: 'Player',
          score: widget.score,
          level: widget.level,
          date: DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _confettiController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/menu_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          
          // Confetti
          if (widget.won || widget.gameComplete)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                colors: const [
                  GameConstants.goldColor,
                  GameConstants.neonGreen,
                  GameConstants.neonBlue,
                  Colors.white,
                ],
              ),
            ),
          
          // Content
          SafeArea(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        
                        // Result title
                        if (widget.gameComplete)
                          Column(
                            children: [
                              Image.asset(
                                'assets/images/trophy.png',
                                width: 100,
                                height: 100,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'GAME COMPLETE!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: GameConstants.goldColor,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You beat all ${GameConstants.maxLevels} levels!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          )
                        else if (widget.won)
                          Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: GameConstants.neonGreen,
                                size: 80,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'LEVEL COMPLETE!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: GameConstants.neonGreen,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              const Icon(
                                Icons.cancel,
                                color: GameConstants.neonRed,
                                size: 80,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'GAME OVER',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: GameConstants.neonRed,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 30),
                        
                        // Score card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 30),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.won || widget.gameComplete
                                  ? GameConstants.neonGreen.withOpacity(0.5)
                                  : GameConstants.neonRed.withOpacity(0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (widget.won || widget.gameComplete
                                        ? GameConstants.neonGreen
                                        : GameConstants.neonRed)
                                    .withOpacity(0.2),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Score
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'SCORE',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.score}',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              
                              if (_isNewHighScore) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: GameConstants.goldColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: GameConstants.goldColor,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.emoji_events,
                                        color: GameConstants.goldColor,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'NEW HIGH SCORE!',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: GameConstants.goldColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 16),
                              Divider(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              const SizedBox(height: 16),
                              
                              // Stats row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStat('LEVEL', '${widget.level}'),
                                  _buildStat(
                                    'HIGH SCORE',
                                    '${StorageManager.instance.getHighScore()}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Buttons
                        if (!widget.gameComplete)
                          _buildActionButton(
                            widget.won ? 'NEXT LEVEL' : 'TRY AGAIN',
                            widget.won ? GameConstants.neonGreen : GameConstants.goldColor,
                            () {
                              if (widget.won) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => GameplayScreen(
                                      startLevel: widget.level + 1,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => GameplayScreen(
                                      startLevel: widget.level,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        
                        const SizedBox(height: 12),
                        
                        _buildActionButton(
                          'MAIN MENU',
                          Colors.white.withOpacity(0.3),
                          () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const MenuScreen(),
                              ),
                              (route) => false,
                            );
                          },
                          isOutlined: true,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        _buildActionButton(
                          'LEADERBOARD',
                          GameConstants.neonBlue.withOpacity(0.3),
                          () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LeaderboardScreen(),
                              ),
                            );
                          },
                          isOutlined: true,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Rewarded ad button
                        GestureDetector(
                          onTap: () async {
                            final success = await AdManager.instance.showRewardedAd();
                            if (success && context.mounted) {
                              // Give bonus
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bonus points earned!'),
                                  backgroundColor: GameConstants.neonGreen,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: GameConstants.goldColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: GameConstants.goldColor.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.videocam,
                                  color: GameConstants.goldColor.withOpacity(0.8),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'WATCH AD FOR BONUS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: GameConstants.goldColor.withOpacity(0.8),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Banner ad
                        AdManager.instance.buildBannerAd(showNudge: true),
                        
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    Color color,
    VoidCallback onTap, {
    bool isOutlined = false,
  }) {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.playClick();
        onTap();
      },
      child: Container(
        width: 240,
        height: 50,
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: color,
            width: 2,
          ),
          boxShadow: isOutlined
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isOutlined ? color : Colors.black,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
