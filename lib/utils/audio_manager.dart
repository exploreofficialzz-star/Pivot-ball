import 'package:flame_audio/flame_audio.dart';

/// AudioManager — AudioPool for SFX (prevents sound stopping at high levels)
///
/// Root cause of SFX stopping: FlameAudio.play() creates a NEW AudioPlayer
/// each call. After minutes of play, dozens pile up and overwhelm the audio
/// subsystem. Fix: FlameAudio.createPool() creates a fixed set of players
/// that are reused in rotation — memory stays bounded forever.
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;
  AudioManager._internal();

  bool _bgmReady     = false;
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  // Audio pools — fixed player count, cycled on each play call
  AudioPool? _clickPool;
  AudioPool? _winPool;
  AudioPool? _losePool;
  AudioPool? _rollPool;

  // Per-sound cooldown guard (ms) — prevents double-fire on rapid events
  final Map<String, DateTime> _lastPlayed = {};
  static const _cooldown = Duration(milliseconds: 180);

  // -------------------------------------------------------------------------
  // Initialize
  // -------------------------------------------------------------------------
  Future<void> initialize() async {
    if (_bgmReady) return;

    // BGM lifecycle observer — must be called before bgm.play()
    try {
      FlameAudio.bgm.initialize();
      _bgmReady = true;
    } catch (_) {}

    // Build SFX pools — 3 concurrent players per short sound, 2 for longer
    try {
      _clickPool = await FlameAudio.createPool('click.mp3', maxPlayers: 4);
      _winPool   = await FlameAudio.createPool('win.mp3',   maxPlayers: 2);
      _losePool  = await FlameAudio.createPool('lose.mp3',  maxPlayers: 2);
      _rollPool  = await FlameAudio.createPool('roll.mp3',  maxPlayers: 4);
    } catch (_) {
      // Pools unavailable — SFX silently skipped, game still works
    }
  }

  // -------------------------------------------------------------------------
  // SFX
  // -------------------------------------------------------------------------
  bool _canPlay(String key) {
    final now  = DateTime.now();
    final last = _lastPlayed[key];
    if (last != null && now.difference(last) < _cooldown) return false;
    _lastPlayed[key] = now;
    return true;
  }

  void playClick() {
    if (!_soundEnabled || !_canPlay('click') || _clickPool == null) return;
    try { _clickPool!.start(volume: 0.5); } catch (_) {}
  }

  void playWin() {
    if (!_soundEnabled || !_canPlay('win') || _winPool == null) return;
    try { _winPool!.start(volume: 0.8); } catch (_) {}
  }

  void playLose() {
    if (!_soundEnabled || !_canPlay('lose') || _losePool == null) return;
    try { _losePool!.start(volume: 0.7); } catch (_) {}
  }

  void playRoll() {
    if (!_soundEnabled || !_canPlay('roll') || _rollPool == null) return;
    try { _rollPool!.start(volume: 0.25); } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // BGM
  // -------------------------------------------------------------------------
  Future<void> startMusic() async {
    if (!_musicEnabled) return;
    if (!_bgmReady) await initialize();
    try { await FlameAudio.bgm.play('bgm.mp3', volume: 0.35); } catch (_) {}
  }

  void stopMusic()          { try { FlameAudio.bgm.stop();   } catch (_) {} }
  void pauseMusic()         { try { FlameAudio.bgm.pause();  } catch (_) {} }
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
