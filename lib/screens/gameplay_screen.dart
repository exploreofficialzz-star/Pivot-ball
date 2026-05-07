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
  const GameplayScreen({super.key, required this.startLevel});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late int _currentLevel;
  int  _totalScore    = 0;
  bool _isPaused      = false;
  bool _showCountdown = true;
  int  _countdown     = 3;
  bool _showMilestone = false;

  final GlobalKey<GameEngineState> _gameKey = GlobalKey<GameEngineState>();
  LevelData? _levelData;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.startLevel;
    AudioManager.instance.stopMusic();
    _startCountdown();
  }

  // ---------------------------------------------------------------------------
  // Countdown
  // ---------------------------------------------------------------------------
  void _startCountdown() {
    setState(() {
      _showCountdown = true;
      _countdown     = 3;
    });
    Future.delayed(const Duration(milliseconds: 500), _tickCountdown);
  }

  void _tickCountdown() {
    if (!mounted) return;
    if (_countdown > 1) {
      setState(() => _countdown--);
      AudioManager.instance.playClick();
      Future.delayed(const Duration(milliseconds: 800), _tickCountdown);
    } else {
      setState(() {
        _countdown     = 0;
        _showCountdown = false;
        _levelData     = LevelData.generate(_currentLevel, MediaQuery.of(context).size);
      });
      AudioManager.instance.playClick();
    }
  }

  // ---------------------------------------------------------------------------
  // Game result handler — infinite levels, no hard cap
  // ---------------------------------------------------------------------------
  void _onGameEnd(int score, int level, bool won) {
    if (won) {
      _totalScore += score;
      StorageManager.instance.saveHighScore(_totalScore);
      // Unlock one ahead so the player can continue from where they left off
      StorageManager.instance.saveUnlockedLevel(level + 1);

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          _currentLevel++;
          // Milestone every 25 levels — show a banner, then keep playing
          _showMilestone = LevelData.isMilestone(_currentLevel - 1);
          _levelData     = LevelData.generate(_currentLevel, MediaQuery.of(context).size);
        });

        if (_showMilestone) {
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            setState(() => _showMilestone = false);
            _startCountdown();
          });
        } else {
          _startCountdown();
        }
      });
    } else {
      AdManager.instance.showInterstitialAd();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => GameOverScreen(
            score: _totalScore,
            level: level,
            won:   false,
          ),
        ));
      });
    }
  }

  void _onScoreUpdate(int score, int timeLeft) {
    setState(() => _totalScore = score);
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      AudioManager.instance.pauseMusic();
    } else {
      AudioManager.instance.resumeMusic();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) { if (!didPop) _togglePause(); },
        child: Stack(
          children: [
            // Game engine
            if (_levelData != null && !_showCountdown)
              GameEngine(
                key:           _gameKey,
                levelData:     _levelData!,
                onGameEnd:     _onGameEnd,
                onScoreUpdate: _onScoreUpdate,
                onPause:       _togglePause,
              )
            else
              Container(color: Colors.black),

            // Pause button
            if (!_showCountdown && !_isPaused)
              Positioned(
                top:   MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color:  Colors.black.withOpacity(0.5),
                      shape:  BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.pause, color: Colors.white, size: 20),
                  ),
                ),
              ),

            // Joysticks
            if (!_showCountdown && !_isPaused && _levelData != null)
              Positioned(
                bottom: 30,
                left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: size.width * 0.22,
                      alignment: Alignment.center,
                      child: VirtualJoystick(
                        size:      size.width * 0.18,
                        color:     Colors.red,
                        onMove:    (v) => _gameKey.currentState?.setLeftInput(v),
                        onRelease: ()  => _gameKey.currentState?.setLeftInput(0),
                      ),
                    ),
                    SizedBox(width: size.width * 0.5),
                    Container(
                      width: size.width * 0.22,
                      alignment: Alignment.center,
                      child: VirtualJoystick(
                        size:      size.width * 0.18,
                        color:     Colors.blue,
                        onMove:    (v) => _gameKey.currentState?.setRightInput(v),
                        onRelease: ()  => _gameKey.currentState?.setRightInput(0),
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
                      // Show "∞ MODE" badge for levels beyond 50
                      if (_currentLevel > 50)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color:        GameConstants.neonBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border:       Border.all(color: GameConstants.neonBlue),
                          ),
                          child: const Text('∞ INFINITY MODE',
                            style: TextStyle(color: GameConstants.neonBlue, fontSize: 12, letterSpacing: 3)),
                        ),
                      Text(
                        'LEVEL $_currentLevel',
                        style: const TextStyle(
                          fontSize: 24, color: GameConstants.goldColor, letterSpacing: 4),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _countdown > 0
                          ? Text('$_countdown',
                              key: ValueKey<int>(_countdown),
                              style: const TextStyle(
                                fontSize: 120, fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(color: GameConstants.goldColor, blurRadius: 40)],
                              ))
                          : const Text('GO!',
                              style: TextStyle(
                                fontSize: 80, fontWeight: FontWeight.bold,
                                color: GameConstants.neonGreen,
                                shadows: [Shadow(color: GameConstants.neonGreen, blurRadius: 40)],
                              )),
                      ),
                    ],
                  ),
                ),
              ),

            // Milestone banner (every 25 levels)
            if (_showMilestone)
              Container(
                color: Colors.black.withOpacity(0.88),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        'LEVEL ${_currentLevel - 1} COMPLETE!',
                        style: const TextStyle(
                          fontSize: 22, color: GameConstants.goldColor,
                          fontWeight: FontWeight.bold, letterSpacing: 3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SCORE: $_totalScore',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text('KEEP GOING →',
                        style: TextStyle(
                          fontSize: 14, color: GameConstants.neonGreen, letterSpacing: 4)),
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
                      const Text('PAUSED',
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                          color: Colors.white, letterSpacing: 6)),
                      const SizedBox(height: 8),
                      Text('LEVEL $_currentLevel   SCORE: $_totalScore',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
                      const SizedBox(height: 40),
                      _pauseBtn('RESUME',  GameConstants.neonGreen, _togglePause),
                      const SizedBox(height: 16),
                      _pauseBtn('RESTART', GameConstants.goldColor, () {
                        setState(() {
                          _isPaused     = false;
                          _totalScore   = 0;
                          _currentLevel = widget.startLevel;
                        });
                        _startCountdown();
                      }),
                      const SizedBox(height: 16),
                      _pauseBtn('QUIT', GameConstants.neonRed, () {
                        AudioManager.instance.startMusic();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MenuScreen()),
                          (r) => false,
                        );
                      }),
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

  Widget _pauseBtn(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { AudioManager.instance.playClick(); onTap(); },
      child: Container(
        width: 200, height: 50,
        decoration: BoxDecoration(
          color:        color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
          border:       Border.all(color: color),
        ),
        child: Center(
          child: Text(text,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: color, letterSpacing: 3)),
        ),
      ),
    );
  }
}
