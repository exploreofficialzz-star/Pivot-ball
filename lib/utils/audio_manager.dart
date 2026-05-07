import 'package:flame_audio/flame_audio.dart';

/// Thin wrapper around flame_audio 2.x / audioplayers 5.x.
///
/// KEY rules for flame_audio 2.x:
///  1. FlameAudio.bgm.initialize() MUST be called before bgm.play().
///  2. FlameAudio.play() works any time — no pre-loading required.
///  3. The audio cache prefix is already set to 'assets/audio/' by Flame,
///     so pass bare filenames ('click.mp3', not 'audio/click.mp3').
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;
  AudioManager._internal();

  bool _bgmReady      = false;
  bool _soundEnabled  = true;
  bool _musicEnabled  = true;

  // -------------------------------------------------------------------------
  // Initialize — only needs to set up BGM lifecycle observer.
  // SFX (FlameAudio.play) work without any initialization.
  // -------------------------------------------------------------------------
  Future<void> initialize() async {
    if (_bgmReady) return;
    try {
      // Required in flame_audio 2.x before using FlameAudio.bgm
      FlameAudio.bgm.initialize();
      _bgmReady = true;
    } catch (_) {
      // If BGM setup fails, SFX still work fine
      _bgmReady = false;
    }
  }

  // -------------------------------------------------------------------------
  // Sound effects — no initialization needed, play immediately
  // -------------------------------------------------------------------------
  void playClick() {
    if (!_soundEnabled) return;
    try { FlameAudio.play('click.mp3', volume: 0.5); } catch (_) {}
  }

  void playWin() {
    if (!_soundEnabled) return;
    try { FlameAudio.play('win.mp3', volume: 0.8); } catch (_) {}
  }

  void playLose() {
    if (!_soundEnabled) return;
    try { FlameAudio.play('lose.mp3', volume: 0.7); } catch (_) {}
  }

  void playRoll() {
    if (!_soundEnabled) return;
    try { FlameAudio.play('roll.mp3', volume: 0.3); } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Background music — requires bgm.initialize() first
  // -------------------------------------------------------------------------
  Future<void> startMusic() async {
    if (!_musicEnabled) return;
    if (!_bgmReady) await initialize();
    try {
      await FlameAudio.bgm.play('bgm.mp3', volume: 0.4);
    } catch (_) {}
  }

  void stopMusic() {
    try { FlameAudio.bgm.stop(); } catch (_) {}
  }

  void pauseMusic() {
    try { FlameAudio.bgm.pause(); } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!_musicEnabled) return;
    try { await FlameAudio.bgm.resume(); } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Settings
  // -------------------------------------------------------------------------
  void setSoundEnabled(bool value) => _soundEnabled = value;

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
