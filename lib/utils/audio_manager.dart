import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;
  AudioManager._internal();

  bool _initialized = false;
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // 5-second timeout — if audio fails to load, app continues normally
      await FlameAudio.audioCache.loadAll([
        'click.mp3',
        'win.mp3',
        'lose.mp3',
        'roll.mp3',
        'bgm.mp3',
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Audio unavailable — game still works, just silent
          return [];
        },
      );
    } catch (_) {
      // Never block the app over audio
    }
    _initialized = true;
  }

  void playClick() {
    if (!_soundEnabled || !_initialized) return;
    try { FlameAudio.play('click.mp3', volume: 0.5); } catch (_) {}
  }

  void playWin() {
    if (!_soundEnabled || !_initialized) return;
    try { FlameAudio.play('win.mp3', volume: 0.8); } catch (_) {}
  }

  void playLose() {
    if (!_soundEnabled || !_initialized) return;
    try { FlameAudio.play('lose.mp3', volume: 0.7); } catch (_) {}
  }

  void playRoll() {
    if (!_soundEnabled || !_initialized) return;
  }

  void startMusic() {
    if (!_musicEnabled || !_initialized) return;
    try { FlameAudio.bgm.play('bgm.mp3', volume: 0.4); } catch (_) {}
  }

  void stopMusic() {
    try { FlameAudio.bgm.stop(); } catch (_) {}
  }

  void pauseMusic() {
    try { FlameAudio.bgm.pause(); } catch (_) {}
  }

  void resumeMusic() {
    if (!_musicEnabled || !_initialized) return;
    try { FlameAudio.bgm.resume(); } catch (_) {}
  }

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
  }

  void setMusicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      stopMusic();
    } else {
      startMusic();
    }
  }

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
}
