import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';
import '../utils/storage_manager.dart';
import '../utils/ad_manager.dart';
import '../utils/notification_manager.dart';
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
  int  _nextBonusLevel = 1;   // level when +30s becomes available again
  int  _nextSkipLevel  = 6;   // level when SKIP becomes available again
  bool _bonusTimeUsed  = false; // used this cycle
  bool _skipUsed       = false; // used this cycle

  final GlobalKey<GameEngineState> _gameKey = GlobalKey<GameEngineState>();
  LevelData? _levelData;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.startLevel;
    // BGM keeps playing — never stop on screen enter
    _startCountdown();
  }

  // ---------------------------------------------------------------------------
  // Countdown
  // ---------------------------------------------------------------------------
  void _startCountdown() {
    // Show 3 and play sound simultaneously
    setState(() {
      _showCountdown = true;
      _countdown     = 3;
    });
    // Sound fires after first frame renders so visual and audio are in sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioManager.instance.playClick();
    });
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    Future.delayed(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
        // Play sound after frame renders — keeps visual + audio locked together
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AudioManager.instance.playClick();
        });
        _scheduleNextTick();
      } else {
        // "GO!" frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AudioManager.instance.playWin();
        });
        setState(() => _countdown = 0);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() {
            _showCountdown = false;
            _levelData     = LevelData.generate(
                _currentLevel, MediaQuery.of(context).size);
          });
        });
      }
    });
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

      // Show interstitial FIRST — countdown starts only after ad dismisses
      AdManager.instance.showInterstitialAd(onDismissed: () {
        if (!mounted) return;
        setState(() {
          _currentLevel++;
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
      NotificationManager.instance.scheduleLoseReminder(_currentLevel);
      // Offer +30s rewarded ad before game over — player may want to continue
      if (AdManager.instance.rewardedAdReady && !_bonusTimeUsed) {
        _showContinueOffer(level);
      } else {
        AdManager.instance.showInterstitialAd(onDismissed: () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => GameOverScreen(score: _totalScore, level: level, won: false),
          ));
        });
      }
    }
  }

  /// Shows a dialog offering the player a rewarded ad to get +30s instead of
  /// going straight to game over. Fires only when a rewarded ad is ready.
  void _showContinueOffer(int level) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Game Over!',
          style: TextStyle(color: GameConstants.goldColor, fontSize: 14, letterSpacing: 2),
          textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Watch a short ad to get +30s and keep playing!', style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.6),
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('No thanks', style: TextStyle(
                color: Colors.white38, fontSize: 9)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GameConstants.goldColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.play_circle_outline, size: 16),
              label: const Text('+30s', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ]),
        ]),
      ),
    ).then((watch) async {
      if (watch == true && mounted) {
        final earned = await AdManager.instance.showRewardedAd();
        if (earned && mounted) {
          // Restart the same level with +30s bonus
          setState(() {
            _bonusTimeUsed  = true;
            _nextBonusLevel = _currentLevel + 4 + (DateTime.now().millisecond % 2);
          });
          _gameKey.currentState?.resetAndResume(30);
          return;
        }
      }
      // No ad or declined — show interstitial then game over
      if (mounted) {
        AdManager.instance.showInterstitialAd(onDismissed: () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => GameOverScreen(score: _totalScore, level: level, won: false),
          ));
        });
      }
    });
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

            // ── Bottom control panel ─────────────────────────────────
            if (!_showCountdown && !_isPaused && _levelData != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: size.height * 0.22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.85),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left joystick
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 12),
                        child: VirtualJoystick(
                          size:      size.width * 0.2,
                          color:     Colors.red,
                          onMove:    (v) => _gameKey.currentState?.setLeftInput(v),
                          onRelease: ()  => _gameKey.currentState?.setLeftInput(0),
                        ),
                      ),
                      // Center — +30s and SKIP buttons stacked
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // +30s bonus time button
                            if (!_bonusTimeUsed && _currentLevel >= _nextBonusLevel && AdManager.instance.rewardedAdReady)
                              GestureDetector(
                                onTap: () async {
                                  AudioManager.instance.playClick();
                                  final earned = await AdManager.instance.showRewardedAd();
                                  if (earned && mounted) {
                                    _gameKey.currentState?.addBonusTime(30);
                                    setState(() {
                                      _bonusTimeUsed  = true;
                                      _nextBonusLevel = _currentLevel + 4 + (DateTime.now().millisecond % 2);
                                    });
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: GameConstants.goldColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: GameConstants.goldColor, width: 1.5),
                                  ),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.play_circle_outline, color: GameConstants.goldColor, size: 13),
                                    SizedBox(width: 4),
                                    Text('+30s', style: TextStyle(
                                      color: GameConstants.goldColor, fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ),

                            // Skip level button (level 6+)
                            if (!_skipUsed && _currentLevel >= _nextSkipLevel && AdManager.instance.rewardedAdReady)
                              GestureDetector(
                                onTap: () async {
                                  AudioManager.instance.playClick();
                                  final earned = await AdManager.instance.showRewardedAd();
                                  if (earned && mounted) {
                                    setState(() {
                                      _skipUsed      = true;
                                      _nextSkipLevel = _currentLevel + 4 + (DateTime.now().millisecond % 2);
                                    });
                                    _onGameEnd(_totalScore, _currentLevel, true);
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: GameConstants.neonBlue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: GameConstants.neonBlue, width: 1.5),
                                  ),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.skip_next_rounded, color: GameConstants.neonBlue, size: 13),
                                    SizedBox(width: 4),
                                    Text('SKIP', style: TextStyle(
                                      color: GameConstants.neonBlue, fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Right joystick
                      Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 12),
                        child: VirtualJoystick(
                          size:      size.width * 0.2,
                          color:     Colors.blue,
                          onMove:    (v) => _gameKey.currentState?.setRightInput(v),
                          onRelease: ()  => _gameKey.currentState?.setRightInput(0),
                        ),
                      ),
                    ],
                  ),
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
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: Tween<double>(begin: 1.5, end: 1.0).animate(
                            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                          ),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: _countdown > 0
                          ? Text('$_countdown',
                              key: ValueKey<int>(_countdown),
                              style: TextStyle(
                                fontSize: size.width * 0.32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: const [Shadow(
                                  color: GameConstants.goldColor,
                                  blurRadius: 12,
                                )],
                              ))
                          : Text('GO!',
                              key: const ValueKey<String>('go'),
                              style: TextStyle(
                                fontSize: size.width * 0.2,
                                fontWeight: FontWeight.bold,
                                color: GameConstants.neonGreen,
                                shadows: const [Shadow(
                                  color: GameConstants.neonGreen,
                                  blurRadius: 12,
                                )],
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
                      // Skip Level via rewarded ad (available from level 6+)
              if (!_skipUsed && _currentLevel >= _nextSkipLevel && AdManager.instance.rewardedAdReady)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  _pauseBtn('⏭  SKIP LEVEL  (Ad)', GameConstants.neonBlue, () async {
                    final earned = await AdManager.instance.showRewardedAd();
                    if (earned && mounted) {
                      setState(() {
                        _isPaused      = false;
                        _skipUsed      = true;
                        _nextSkipLevel = _currentLevel + 4 + (DateTime.now().millisecond % 2);
                      });
                      _onGameEnd(_totalScore, _currentLevel, true);
                    }
                  }),
                  const SizedBox(height: 16),
                ]),

              _pauseBtn('QUIT', GameConstants.neonRed, () {
                        AudioManager.instance.resumeMusic();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MenuScreen()),
                          (r) => false,
                        );
                      }),
                      const SizedBox(height: 20),
                      AdManager.instance.buildBannerAd(showNudge: true),
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
