# Pivot Ball: Retro Physics Challenge

A precision arcade game inspired by the classic 1983 Taito arcade game "Ice Cold Beer". Guide a metal ball into target holes by controlling a tilting bar with dual virtual joysticks.

## Features

- **Dual Virtual Joystick Controls** - Left and right vertical joysticks control each end of the bar
- **Realistic Physics** - Ball rolls based on gravity, tilt angle, and friction
- **50 Progressive Levels** - Increasing difficulty with moving holes, dead holes, and bumper pegs
- **Retro Arcade Aesthetic** - Neon visuals with golden playfield inspired by classic arcade cabinets
- **Leaderboard** - Track high scores and compete
- **Sound Effects & Music** - Retro arcade audio experience
- **Ad Integration** - Banner, interstitial, and rewarded ads professionally implemented

## Screenshots

- Splash Screen with "by chAs" branding
- Main Menu with animated title
- Gameplay with dual joysticks
- Level Complete / Game Over screens with confetti
- Settings, Leaderboard, How to Play tutorials

## Controls

- **Left Joystick (Red)**: Control left end of the bar
- **Right Joystick (Blue)**: Control right end of the bar
- **Goal**: Guide the ball into the GREEN target hole
- **Avoid**: RED danger holes

## Tech Stack

- Flutter 3.41.9
- Dart 3.11.5
- Flame Engine (game framework)
- Google Mobile Ads
- Shared Preferences (local storage)

## Building

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## GitHub Actions CI/CD

The project includes a GitHub Actions workflow (`.github/workflows/build.yml`) that:
- Builds Android APK and AAB on every push to main/master
- Builds iOS IPA on macOS runner
- Creates GitHub releases automatically when tagging with `v*`
- Uploads build artifacts

## Project Structure

```
pivot_ball/
├── android/           # Android platform files
├── ios/              # iOS platform files
├── assets/
│   ├── images/       # Game assets (ball, bar, holes, backgrounds)
│   ├── audio/        # Sound effects and music
│   └── fonts/        # Custom fonts
├── lib/
│   ├── main.dart              # App entry point
│   ├── screens/               # All game screens
│   │   ├── splash_screen.dart
│   │   ├── menu_screen.dart
│   │   ├── gameplay_screen.dart
│   │   ├── game_over_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── leaderboard_screen.dart
│   │   └── how_to_play_screen.dart
│   ├── widgets/               # Game widgets
│   │   ├── game_engine.dart   # Physics engine
│   │   └── virtual_joystick.dart
│   ├── models/                # Data models
│   └── utils/                 # Utilities
│       ├── constants.dart
│       ├── ad_manager.dart
│       ├── audio_manager.dart
│       └── storage_manager.dart
├── test/             # Widget tests
└── .github/workflows/# CI/CD configuration
```

## Package Name

- **Android**: `com.chastechgroup.pivotball`
- **iOS**: `com.chastechgroup.pivotball`

## Credits

Developed by **chAs** (chas tech group)

## License

This project is proprietary software.
