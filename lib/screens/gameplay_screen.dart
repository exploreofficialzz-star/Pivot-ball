import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';
import '../utils/storage_manager.dart';
import '../utils/ad_manager.dart';
import '../widgets/game_engine.dart';
import '../widgets/virtual_joystick.dart';
import 'menu_screen.dart';
import 'game_over_screen.dart';

class GameplayScreen extends StatefulWidget {
  final int startLevel;

  const GameplayScreen({
    super.key,
    required this.startLevel,
  });

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late int _currentLevel;
  int _totalScore = 0;
  bool _isPaused = false;
  bool _showCountdown = true;
  int _countdown = 3;
  final GlobalKey<GameEngineState> _gameKey = GlobalKey<GameEngineState>();
  LevelData? _levelData;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.startLevel;
    AudioManager.instance.stopMusic();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _showCountdown = true;
      _countdown = 3;
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _tickCountdown();
    });
  }

  void _tickCountdown() {
    if (_countdown > 1) {
      setState(() {
        _countdown--;
      });
      AudioManager.instance.playClick();
      Future.delayed(const Duration(milliseconds: 800), _tickCountdown);
    } else {
      setState(() {
        _countdown = 0;
        _showCountdown = false;
        _levelData = LevelData.generate(_currentLevel, MediaQuery.of(context).size);
      });
      AudioManager.instance.playClick();
    }
  }

  void _onGameEnd(int score, int level, bool won) {
    if (won) {
      _totalScore += score;
      StorageManager.instance.saveHighScore(_totalScore);
      StorageManager.instance.saveUnlockedLevel(level + 1);
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _currentLevel++;
            if (_currentLevel > GameConstants.maxLevels) {
              // Game complete!
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GameOverScreen(
                    score: _totalScore,
                    level: level,
                    won: true,
                    gameComplete: true,
                  ),
                ),
              );
              return;
            }
            _levelData = LevelData.generate(_currentLevel, MediaQuery.of(context).size);
          });
          _startCountdown();
        }
      });
    } else {
      AdManager.instance.showInterstitialAd();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameOverScreen(
                score: _totalScore,
                level: level,
                won: false,
              ),
            ),
          );
        }
      });
    }
  }

  void _onScoreUpdate(int score, int timeLeft) {
    setState(() {
      _totalScore = score;
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (_isPaused) {
      AudioManager.instance.pauseMusic();
    } else {
      AudioManager.instance.resumeMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            _togglePause();
          }
        },
        child: Stack(
          children: [
            // Game Engine
            if (_levelData != null && !_showCountdown)
              GameEngine(
                key: _gameKey,
                levelData: _levelData!,
                onGameEnd: _onGameEnd,
                onScoreUpdate: _onScoreUpdate,
                onPause: _togglePause,
              )
            else
              Container(color: Colors.black),
            
            // Pause button
            if (!_showCountdown && !_isPaused)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.pause,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            
            // Virtual Joysticks (only show during gameplay)
            if (!_showCountdown && !_isPaused && _levelData != null)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left control zone (20%)
                    Container(
                      width: size.width * 0.22,
                      alignment: Alignment.center,
                      child: VirtualJoystick(
                        size: size.width * 0.18,
                        color: Colors.red,
                        onMove: (value) {
                          _gameKey.currentState?.setLeftInput(value);
                        },
                        onRelease: () {
                          _gameKey.currentState?.setLeftInput(0);
                        },
                      ),
                    ),
                    
                    // Center spacer
                    SizedBox(width: size.width * 0.5),
                    
                    // Right control zone (20%)
                    Container(
                      width: size.width * 0.22,
                      alignment: Alignment.center,
                      child: VirtualJoystick(
                        size: size.width * 0.18,
                        color: Colors.blue,
                        onMove: (value) {
                          _gameKey.currentState?.setRightInput(value);
                        },
                        onRelease: () {
                          _gameKey.currentState?.setRightInput(0);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            
            // Countdown overlay
            if (_showCountdown)
              Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LEVEL $_currentLevel',
                        style: const TextStyle(
                          fontSize: 24,
                          color: GameConstants.goldColor,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _countdown > 0
                            ? Text(
                                '$_countdown',
                                key: ValueKey<int>(_countdown),
                                style: const TextStyle(
                                  fontSize: 120,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: GameConstants.goldColor,
                                      blurRadius: 40,
                                    ),
                                  ],
                                ),
                              )
                            : const Text(
                                'GO!',
                                style: TextStyle(
                                  fontSize: 80,
                                  fontWeight: FontWeight.bold,
                                  color: GameConstants.neonGreen,
                                  shadows: [
                                    Shadow(
                                      color: GameConstants.neonGreen,
                                      blurRadius: 40,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Pause overlay
            if (_isPaused)
              Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PAUSED',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildPauseButton(
                        'RESUME',
                        GameConstants.neonGreen,
                        () => _togglePause(),
                      ),
                      const SizedBox(height: 16),
                      _buildPauseButton(
                        'RESTART',
                        GameConstants.goldColor,
                        () {
                          setState(() {
                            _isPaused = false;
                            _totalScore = 0;
                            _currentLevel = widget.startLevel;
                          });
                          _startCountdown();
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPauseButton(
                        'QUIT',
                        GameConstants.neonRed,
                        () {
                          AudioManager.instance.startMusic();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const MenuScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      AdManager.instance.buildBannerAd(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.playClick();
        onTap();
      },
      child: Container(
        width: 200,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
