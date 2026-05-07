import 'package:flame_audio/flame_audio.dart';

/// AudioManager — continuous BGM + clean SFX with debounce
///
/// Design decisions:
///  • BGM runs through ALL screens — never call stopMusic() on screen enter.
///    Use pauseMusic() / resumeMusic() only for the pause overlay.
///  • SFX have a per-sound cooldown (200 ms) so rapid level changes at high
///    levels can't stack dozens of overlapping audio players.
///  • BGM auto-resumes if the app comes back from background (handled by
///    FlameAudio.bgm lifecycle observer set up in initialize()).
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;
  AudioManager._internal();

  bool _bgmReady     = false;
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  // Per-sound cooldown — prevents overlap at high game speeds
  final Map<String, DateTime> _lastPlayed = {};
  static const _sfxCooldown = Duration(milliseconds: 200);

  // -------------------------------------------------------------------------
  // Init
  // -------------------------------------------------------------------------
  Future<void> initialize() async {
    if (_bgmReady) return;
    try {
      FlameAudio.bgm.initialize(); // registers lifecycle observer
      _bgmReady = true;
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // SFX — fire-and-forget, with cooldown guard
  // -------------------------------------------------------------------------
  void _playSfx(String file, double volume) {
    if (!_soundEnabled) return;
    final now  = DateTime.now();
    final last = _lastPlayed[file];
    if (last != null && now.difference(last) < _sfxCooldown) return;
    _lastPlayed[file] = now;
    try { FlameAudio.play(file, volume: volume); } catch (_) {}
  }

  void playClick() => _playSfx('click.mp3', 0.5);
  void playWin()   => _playSfx('win.mp3',   0.8);
  void playLose()  => _playSfx('lose.mp3',  0.7);
  void playRoll()  => _playSfx('roll.mp3',  0.3);

  // -------------------------------------------------------------------------
  // BGM — continuous across all screens
  // Call startMusic() once at app start; never stop it except on settings
  // -------------------------------------------------------------------------
  Future<void> startMusic() async {
    if (!_musicEnabled) return;
    if (!_bgmReady) await initialize();
    try {
      // bgm.play() is idempotent — safe to call even if already playing
      await FlameAudio.bgm.play('bgm.mp3', volume: 0.35);
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
