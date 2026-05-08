import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';
import '../utils/storage_manager.dart';
import '../utils/ad_manager.dart';
import 'menu_screen.dart';
import 'no_internet_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<double>   _scale;
  late Animation<double>   _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await StorageManager.instance.initialize();

    final soundEnabled = StorageManager.instance.getSoundEnabled();
    final musicEnabled = StorageManager.instance.getMusicEnabled();
    AudioManager.instance.setSoundEnabled(soundEnabled);
    AudioManager.instance.setMusicEnabled(musicEnabled);

    // Init audio pools + BGM observer
    await AudioManager.instance.initialize();

    // Start BGM right from splash
    if (musicEnabled) AudioManager.instance.startMusic();

    // Let splash animation breathe — minimum 2.8 s
    await Future.delayed(const Duration(milliseconds: 2800));

    if (!mounted) return;

    // ── Network gate ────────────────────────────────────────────────────────
    bool online = true;
    try {
      final result = await Connectivity().checkConnectivity()
          .timeout(const Duration(seconds: 3));
      online = result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      online = false;
    }

    // Start ad loading in background only when online
    if (online) AdManager.instance.initialize();

    if (!mounted) return;

    final destination = online ? const MenuScreen() : const NoInternetScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final iconSize  = size.width * 0.28;
    final titleSize = size.width * 0.09;
    final subSize   = size.width * 0.030;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Radial background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.25),
                radius: 1.1,
                colors: [Color(0xFF2A1500), Colors.black],
              ),
            ),
          ),

          // Main content
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fade,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App icon
                          Container(
                            width:  iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(iconSize * 0.22),
                              boxShadow: [
                                BoxShadow(
                                  color:       GameConstants.goldColor.withOpacity(0.18),
                                  blurRadius:  iconSize * 0.2,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(iconSize * 0.22),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          SizedBox(height: size.height * 0.035),

                          // Title — FittedBox prevents overflow on small phones
                          FittedBox(
                            child: Text(
                              GameConstants.appName,
                              style: TextStyle(
                                fontSize:   titleSize,
                                fontWeight: FontWeight.bold,
                                color:      GameConstants.goldColor,
                                letterSpacing: 4,
                                shadows: const [
                                  Shadow(
                                    color:      GameConstants.goldColor,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: size.height * 0.008),

                          // Subtitle
                          Text(
                            GameConstants.appSubtitle.toUpperCase(),
                            style: TextStyle(
                              fontSize:    subSize,
                              color:       Colors.white.withOpacity(0.55),
                              letterSpacing: 5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: size.height * 0.07),

                          // Spinner
                          SizedBox(
                            width: 36, height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                GameConstants.goldColor.withOpacity(0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Company tag — bottom
          Positioned(
            bottom: size.height * 0.05,
            left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _fade,
              builder: (context, child) => FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text('by', style: TextStyle(
                      fontSize: size.width * 0.028,
                      color:    Colors.white.withOpacity(0.35),
                    )),
                    SizedBox(height: size.height * 0.004),
                    Text(GameConstants.companyName, style: TextStyle(
                      fontSize:   size.width * 0.05,
                      fontWeight: FontWeight.bold,
                      color:      GameConstants.goldColor.withOpacity(0.55),
                      letterSpacing: 3,
                    )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
