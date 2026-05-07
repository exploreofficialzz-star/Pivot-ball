import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/constants.dart';
import '../utils/audio_manager.dart';
import '../utils/ad_manager.dart';
import 'menu_screen.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen>
    with SingleTickerProviderStateMixin {
  bool _checking = false;
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _checking = true);
    AudioManager.instance.playClick();

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final result = await Connectivity().checkConnectivity();
      final online = result.any((r) => r != ConnectivityResult.none);

      if (!mounted) return;

      if (online) {
        // Connected — init ads and go to menu
        AdManager.instance.initialize();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MenuScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } else {
        setState(() => _checking = false);
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.2),
                radius: 1.0,
                colors: [
                  const Color(0xFF1A0A00),
                  Colors.black,
                ],
              ),
            ),
          ),

          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing wifi-off icon
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Opacity(
                      opacity: _pulse.value,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: GameConstants.neonRed.withOpacity(0.6),
                            width: 2,
                          ),
                          color: GameConstants.neonRed.withOpacity(0.08),
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 54,
                          color: GameConstants.neonRed,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Title
                  const Text(
                    'NO CONNECTION',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: GameConstants.neonRed,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Message
                  Text(
                    'Pivot Ball is free to play and\nsupported by ads.\n\nPlease connect to the internet\nto continue.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.65),
                      height: 1.8,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Retry button
                  GestureDetector(
                    onTap: _checking ? null : _retry,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 220,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: _checking
                              ? Colors.white24
                              : GameConstants.goldColor,
                          width: 2,
                        ),
                        color: _checking
                            ? Colors.white.withOpacity(0.05)
                            : GameConstants.goldColor.withOpacity(0.15),
                        boxShadow: _checking
                            ? []
                            : [
                                BoxShadow(
                                  color: GameConstants.goldColor.withOpacity(0.25),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                      ),
                      child: Center(
                        child: _checking
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: GameConstants.goldColor,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'TRY AGAIN',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: GameConstants.goldColor,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Hint
                  Text(
                    'Check your Wi-Fi or mobile data',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Company credit
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'by ${GameConstants.companyName}',
                style: TextStyle(
                  fontSize: 12,
                  color: GameConstants.goldColor.withOpacity(0.4),
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
