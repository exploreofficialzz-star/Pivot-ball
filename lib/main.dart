import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'utils/ad_manager.dart';
import 'utils/audio_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      systemNavigationBarColor: Colors.black,
      statusBarBrightness:      Brightness.dark,
    ),
  );

  // Init BGM observer first — must happen before any bgm.play() call
  await AudioManager.instance.initialize();

  // Init ads in background — never blocks UI
  AdManager.instance.initialize();

  runApp(const PivotBallApp());
}

class PivotBallApp extends StatelessWidget {
  const PivotBallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'Pivot Ball',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3:   true,
        brightness:     Brightness.dark,
        colorScheme:    ColorScheme.fromSeed(
          seedColor:  const Color(0xFFFFB800),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.pressStart2pTextTheme(
          ThemeData.dark().textTheme,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SplashScreen(),
    );
  }
}
