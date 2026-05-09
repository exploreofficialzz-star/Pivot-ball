import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'utils/audio_manager.dart';
import 'utils/purchase_manager.dart';
import 'utils/notification_manager.dart';
import 'utils/network_monitor.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    systemNavigationBarColor: Colors.black,
    statusBarBrightness:      Brightness.dark,
  ));

  // 1. Network monitor — must start first, used throughout the whole app
  await NetworkMonitor.instance.initialize();

  // 2. Audio
  await AudioManager.instance.initialize();

  // 3. IAP — restore purchases silently
  PurchaseManager.instance.initialize();

  // 4. Notifications
  await NotificationManager.instance.initialize();

  runApp(const PivotBallApp());
}

class PivotBallApp extends StatelessWidget {
  const PivotBallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'Pivot Ball',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3:            true,
        brightness:              Brightness.dark,
        colorScheme:             ColorScheme.fromSeed(
          seedColor:  const Color(0xFFFFB800),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.pressStart2pTextTheme(
          ThemeData.dark().textTheme,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SplashScreen(),

      // ── Global network overlay ───────────────────────────────────────────
      // Wraps every screen in the app. When offline, shows a non-dismissible
      // overlay on top of whatever screen is currently showing.
      // Auto-dismisses the moment connection is restored.
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: NetworkMonitor.instance.isOnline,
          builder: (context, online, _) {
            return Stack(
              children: [
                // The actual app
                child ?? const SizedBox.shrink(),

                // Network overlay — sits on top of everything when offline
                if (!online)
                  const _NetworkOverlay(),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Inline overlay widget ─────────────────────────────────────────────────
class _NetworkOverlay extends StatelessWidget {
  const _NetworkOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.92),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing icon
                  _PulsingIcon(),

                  const SizedBox(height: 28),

                  // Title
                  const Text(
                    'NO CONNECTION',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF3131),
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Message
                  Text(
                    'Pivot Ball needs internet to\nrun ads and support the game.\n\nPlease turn on Wi-Fi or mobile data.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.8,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Auto-reconnect indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            GameConstants.goldColor.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Checking connection...',
                        style: TextStyle(
                          fontSize: 10,
                          color: GameConstants.goldColor.withOpacity(0.6),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'This will dismiss automatically\nonce you are connected.',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF3131).withOpacity(0.08),
            border: Border.all(
              color: const Color(0xFFFF3131).withOpacity(0.5),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFFF3131),
            size: 42,
          ),
        ),
      ),
    );
  }
}
