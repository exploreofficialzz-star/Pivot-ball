import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardEntry {
  final String name;
  final int score;
  final int level;
  final DateTime date;

  LeaderboardEntry({
    required this.name,
    required this.score,
    required this.level,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'level': level,
    'date': date.toIso8601String(),
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
    name: json['name'],
    score: json['score'],
    level: json['level'],
    date: DateTime.parse(json['date']),
  );
}

class StorageManager {
  static final StorageManager _instance = StorageManager._internal();
  static StorageManager get instance => _instance;
  StorageManager._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveHighScore(int score) async {
    await initialize();
    final current = _prefs?.getInt('high_score') ?? 0;
    if (score > current) {
      await _prefs?.setInt('high_score', score);
    }
  }

  int getHighScore() {
    return _prefs?.getInt('high_score') ?? 0;
  }

  Future<void> saveUnlockedLevel(int level) async {
    await initialize();
    final current = _prefs?.getInt('unlocked_level') ?? 1;
    if (level > current) {
      await _prefs?.setInt('unlocked_level', level);
    }
  }

  int getUnlockedLevel() {
    return _prefs?.getInt('unlocked_level') ?? 1;
  }

  Future<void> addLeaderboardEntry(LeaderboardEntry entry) async {
    await initialize();
    final entries = getLeaderboard();
    entries.add(entry);
    entries.sort((a, b) => b.score.compareTo(a.score));
    if (entries.length > 20) {
      entries.removeRange(20, entries.length);
    }
    final jsonList = entries.map((e) => e.toJson()).toList();
    await _prefs?.setString('leaderboard', jsonEncode(jsonList));
  }

  List<LeaderboardEntry> getLeaderboard() {
    final jsonStr = _prefs?.getString('leaderboard');
    if (jsonStr == null) return [];
    try {
      final jsonList = jsonDecode(jsonStr) as List;
      return jsonList.map((e) => LeaderboardEntry.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSoundEnabled(bool value) async {
    await initialize();
    await _prefs?.setBool('sound_enabled', value);
  }

  bool getSoundEnabled() {
    return _prefs?.getBool('sound_enabled') ?? true;
  }

  Future<void> saveMusicEnabled(bool value) async {
    await initialize();
    await _prefs?.setBool('music_enabled', value);
  }

  bool getMusicEnabled() {
    return _prefs?.getBool('music_enabled') ?? true;
  }

  Future<void> saveTutorialSeen(bool value) async {
    await initialize();
    await _prefs?.setBool('tutorial_seen', value);
  }

  bool getTutorialSeen() {
    return _prefs?.getBool('tutorial_seen') ?? false;
  }

  Future<void> resetProgress() async {
    await initialize();
    await _prefs?.remove('high_score');
    await _prefs?.remove('unlocked_level');
    await _prefs?.remove('leaderboard');
  }

  // ── IAP ───────────────────────────────────────────────────────────────────
  Future<void> saveAdsRemoved(bool value) async {
    await initialize();
    await _prefs?.setBool('ads_removed', value);
  }

  bool getAdsRemoved() => _prefs?.getBool('ads_removed') ?? false;

  // ── Session tracking ──────────────────────────────────────────────────────
  Future<void> saveLastPlayedTime() async {
    await initialize();
    await _prefs?.setString('last_played', DateTime.now().toIso8601String());
  }

  DateTime? getLastPlayedTime() {
    final s = _prefs?.getString('last_played');
    return s != null ? DateTime.tryParse(s) : null;
  }

  Future<void> saveCurrentStreak(int streak) async {
    await initialize();
    await _prefs?.setInt('streak', streak);
  }

  int getCurrentStreak() => _prefs?.getInt('streak') ?? 0;

  // ── Daily Ad Skip ─────────────────────────────────────────────────────────
  Future<void> saveDailySkipTime() async {
    await initialize();
    await _prefs?.setString('daily_skip_time', DateTime.now().toIso8601String());
  }

  DateTime? getDailySkipTime() {
    final s = _prefs?.getString('daily_skip_time');
    return s != null ? DateTime.tryParse(s) : null;
  }

  // ── Weekly Ad Skip (7 days) ───────────────────────────────────────────────
  Future<void> saveWeeklySkipTime() async {
    await initialize();
    await _prefs?.setString('weekly_skip_time', DateTime.now().toIso8601String());
  }

  DateTime? getWeeklySkipTime() {
    final s = _prefs?.getString('weekly_skip_time');
    return s != null ? DateTime.tryParse(s) : null;
  }

  // ── 30-Day Ad Skip ────────────────────────────────────────────────────────
  Future<void> saveMonthlySkipTime() async {
    await initialize();
    await _prefs?.setString('monthly_skip_time', DateTime.now().toIso8601String());
  }

  DateTime? getMonthlySkipTime() {
    final s = _prefs?.getString('monthly_skip_time');
    return s != null ? DateTime.tryParse(s) : null;
  }

}
