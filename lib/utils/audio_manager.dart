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
    await FlameAudio.audioCache.loadAll([
      'click.mp3',
      'win.mp3',
      'lose.mp3',
      'roll.mp3',
      'bgm.mp3',
    ]);
    _initialized = true;
  }

  void playClick() {
    if (!_soundEnabled) return;
    FlameAudio.play('click.mp3', volume: 0.5);
  }

  void playWin() {
    if (!_soundEnabled) return;
    FlameAudio.play('win.mp3', volume: 0.8);
  }

  void playLose() {
    if (!_soundEnabled) return;
    FlameAudio.play('lose.mp3', volume: 0.7);
  }

  void playRoll() {
    if (!_soundEnabled) return;
    // Roll sound is continuous, handled separately
  }

  void startMusic() {
    if (!_musicEnabled) return;
    FlameAudio.bgm.play('bgm.mp3', volume: 0.4);
  }

  void stopMusic() {
    FlameAudio.bgm.stop();
  }

  void pauseMusic() {
    FlameAudio.bgm.pause();
  }

  void resumeMusic() {
    if (_musicEnabled) {
      FlameAudio.bgm.resume();
    }
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
