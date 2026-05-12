import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'utils/audio_manager.dart';
import 'utils/purchase_manager.dart';
import 'utils/notification_manager.dart';
import 'utils/network_monitor.dart';
import 'utils/ad_manager.dart';
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

  // 4. Notifications — fire in background, never block app launch
  NotificationManager.instance.initialize();

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
        return ValueListenableBuilder<NetworkStatus>(
          valueListenable: NetworkMonitor.instance.status,
          builder: (context, netStatus, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: AdManager.instance.adBlockedNotifier,
              builder: (context, adsBlocked, _) {
                return Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    // Network overlay — highest priority
                    if (netStatus != NetworkStatus.online)
                      _NetworkOverlay(status: netStatus),
                    // Ad-blocked overlay — only when online but ads disabled
                    if (netStatus == NetworkStatus.online && adsBlocked)
                      const _AdBlockedOverlay(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Inline overlay widget ─────────────────────────────────────────────────
class _NetworkOverlay extends StatelessWidget {
  final NetworkStatus status;
  const _NetworkOverlay({required this.status});

  @override
  Widget build(BuildContext context) {
    final isNoInternet = status == NetworkStatus.noInternet;

    final title   = isNoInternet ? 'NO INTERNET' : 'NO CONNECTION';
    final icon    = isNoInternet ? Icons.signal_wifi_bad : Icons.wifi_off_rounded;
    final message = isNoInternet
        ? 'You are connected to a network but have no internet access.\n\nCheck your Wi-Fi password, data plan, or contact your provider.'
        : 'Pivot Ball needs internet to run ads and support the game.\n\nPlease turn on Wi-Fi or mobile data.';

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.93),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulsingIcon(icon: icon),
                  const SizedBox(height: 28),
                  Text(title, style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Color(0xFFFF3131), letterSpacing: 4),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(message, style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.6),
                    height: 1.8, letterSpacing: 0.3),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          GameConstants.goldColor.withOpacity(0.6)))),
                    const SizedBox(width: 10),
                    Text('Checking...', style: TextStyle(
                      fontSize: 10,
                      color: GameConstants.goldColor.withOpacity(0.6),
                      letterSpacing: 1)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Dismisses automatically when connected.',
                    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.25)),
                    textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdBlockedOverlay extends StatelessWidget {
  const _AdBlockedOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.93),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withOpacity(0.08),
                      border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
                    ),
                    child: const Icon(Icons.block_rounded, color: Colors.orange, size: 42),
                  ),
                  const SizedBox(height: 28),
                  const Text('ADS BLOCKED',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: Colors.orange, letterSpacing: 4),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    'It looks like ads are being blocked on your device.\n\n'
                    'Pivot Ball is free and supported by ads.\n\n'
                    'Please disable your ad blocker or check your ads connection to continue playing.',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65),
                      height: 1.8),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange.withOpacity(0.6)))),
                    const SizedBox(width: 10),
                    Text('Checking ad connection...',
                      style: TextStyle(fontSize: 10,
                        color: Colors.orange.withOpacity(0.6), letterSpacing: 1)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Dismisses automatically when ads are available.',
                    style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.25)),
                    textAlign: TextAlign.center),
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
  final IconData icon;
  const _PulsingIcon({this.icon = Icons.wifi_off_rounded});
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
