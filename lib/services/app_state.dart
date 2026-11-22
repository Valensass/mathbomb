import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/audio.dart';
import '../core/haptics.dart';
import '../game/achievements.dart';
import '../data/models.dart';

class DuelAward {
  DuelAward({
    required this.ratingDelta,
    required this.newRating,
    required this.newMedals,
  });

  final int ratingDelta;
  final int newRating;
  final List<MedalDef> newMedals;
}

/// Single source of truth for profile, stats, medals, friends, settings and
/// match history. Everything is persisted as small JSON documents.
class AppState extends ChangeNotifier {
  AppState._(this._prefs);

  static const _kProfile = 'bm.profile.v1';
  static const _kStats = 'bm.stats.v1';
  static const _kMedals = 'bm.medals.v1';
  static const _kFriends = 'bm.friends.v1';
  static const _kHistory = 'bm.history.v1';
  static const _kSettings = 'bm.settings.v1';

  final SharedPreferences _prefs;

  PlayerProfile? profile;
  GameStats stats = GameStats();
  final Map<String, DateTime> medals = {};
  List<FriendInfo> friends = [];
  List<MatchRecord> history = [];
  AppSettings settings = AppSettings();

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppState._(prefs);
    state._read();
    return state;
  }

  bool get onboarded => settings.onboarded && profile != null;

  int get rating => profile?.rating ?? 1000;

  int get unlockedMedals => medals.length;

  void _read() {
    final settingsRaw = _prefs.getString(_kSettings);
    if (settingsRaw != null) {
      try {
        settings = AppSettings.fromJson(
          jsonDecode(settingsRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    final profileRaw = _prefs.getString(_kProfile);
    if (profileRaw != null) {
      try {
        profile = PlayerProfile.fromJson(
          jsonDecode(profileRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    final statsRaw = _prefs.getString(_kStats);
    if (statsRaw != null) {
      try {
        stats = GameStats.fromJson(
          jsonDecode(statsRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    final medalsRaw = _prefs.getString(_kMedals);
    if (medalsRaw != null) {
      try {
        final map = jsonDecode(medalsRaw) as Map<String, dynamic>;
        map.forEach((k, v) {
          final dt = DateTime.tryParse(v.toString());
          if (dt != null) medals[k] = dt;
        });
      } catch (_) {}
    }
    final friendsRaw = _prefs.getString(_kFriends);
    if (friendsRaw != null) {
      try {
        friends = (jsonDecode(friendsRaw) as List)
            .map((e) => FriendInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final historyRaw = _prefs.getString(_kHistory);
    if (historyRaw != null) {
      try {
        history = (jsonDecode(historyRaw) as List)
            .map((e) => MatchRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
  }

  Future<void> completeOnboarding(String name) async {
    profile = PlayerProfile.create(name);
    settings = settings.copyWith(onboarded: true);
    await _saveProfile();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    Haptics.enabled = next.haptics;
    await AudioManager.instance.setSfxEnabled(next.sfx);
    await AudioManager.instance.setMusicEnabled(next.music);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> renameProfile(String name) async {
    final p = profile;
    if (p == null || name.trim().isEmpty) return;
    profile = p.copyWith(name: name.trim());
    await _saveProfile();
    notifyListeners();
  }

  List<MedalDef> _checkMedals() {
    final ctx = MedalContext(
      stats: stats,
      friends: friends.length,
      rating: rating,
    );
    final newly = <MedalDef>[];
    for (final medal in MedalDef.all) {
      if (medals.containsKey(medal.id)) continue;
      if (medal.progress(ctx) >= medal.target) {
        medals[medal.id] = DateTime.now();
        newly.add(medal);
      }
    }
    if (newly.isNotEmpty) {
      _saveMedals();
    }
    return newly;
  }

  Future<List<MedalDef>> recordSolo(SoloRunResult result) async {
    stats.addSoloRun(
      score: result.score,
      modules: result.modules,
      correctAnswers: result.correct,
      wrongAnswers: result.wrong,
      bombs: result.bombs,
      combo: result.bestCombo,
      fastestCutMs: result.fastestMs,
      cleanBombCount: result.cleanBombs,
      timeLeftMs: result.timeLeftMs,
    );
    _addHistory(
      MatchRecord(
        mode: 'solo',
        outcome: 'run',
        score: result.score,
        modules: result.modules,
        durationMs: result.durationMs,
        at: DateTime.now(),
      ),
    );
    final newly = _checkMedals();
    await _saveStats();
    await _saveHistory();
    notifyListeners();
    return newly;
  }

  Future<DuelAward> recordDuel(DuelRunResult result) async {
    var delta = 0;
    if (result.rated) {
      final expected =
          1 / (1 + math.pow(10, (result.opponentRating - rating) / 400));
      final actual = result.draw ? 0.5 : (result.won ? 1.0 : 0.0);
      delta = (24 * (actual - expected)).round();
      if (delta == 0 && !result.draw) delta = result.won ? 1 : -1;
    }
    final newRating = math.max(100, rating + delta);
    if (result.rated && profile != null) {
      profile = profile!.copyWith(rating: newRating);
      await _saveProfile();
    }

    stats.addDuel(
      won: result.won,
      draw: result.draw,
      score: result.score,
      modules: result.modules,
      correctAnswers: result.correct,
      wrongAnswers: result.wrong,
      combo: result.bestCombo,
      fastestCutMs: result.fastestMs,
    );
    _addHistory(
      MatchRecord(
        mode: 'duel',
        outcome: result.draw ? 'draw' : (result.won ? 'win' : 'loss'),
        score: result.score,
        modules: result.modules,
        durationMs: result.durationMs,
        at: DateTime.now(),
        opponent: result.opponentName,
      ),
    );
    final newly = _checkMedals();
    await _saveStats();
    await _saveHistory();
    notifyListeners();
    return DuelAward(
      ratingDelta: delta,
      newRating: newRating,
      newMedals: newly,
    );
  }

  void _addHistory(MatchRecord record) {
    history = [record, ...history];
    if (history.length > 20) {
      history = history.sublist(0, 20);
    }
  }

  bool addFriend(FriendInfo friend) {
    if (friends.any((f) => f.id == friend.id || f.code == friend.code)) {
      return false;
    }
    friends = [...friends, friend];
    _saveFriends();
    _checkMedals();
    notifyListeners();
    return true;
  }

  Future<void> removeFriend(String id) async {
    friends = friends.where((f) => f.id != id).toList();
    await _saveFriends();
    notifyListeners();
  }

  void setPresence(Iterable<String> onlineIds) {
    final ids = onlineIds.toSet();
    var changed = false;
    for (final f in friends) {
      final now = ids.contains(f.id);
      if (f.online != now) {
        f.online = now;
        changed = true;
      }
    }
    if (changed) {
      _saveFriends();
      notifyListeners();
    }
  }

  Future<void> resetProgress() async {
    await _prefs.remove(_kProfile);
    await _prefs.remove(_kStats);
    await _prefs.remove(_kMedals);
    await _prefs.remove(_kFriends);
    await _prefs.remove(_kHistory);
    profile = null;
    stats = GameStats();
    medals.clear();
    friends = [];
    history = [];
    settings = settings.copyWith(onboarded: false);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> _saveProfile() async {
    final p = profile;
    if (p == null) return;
    await _prefs.setString(_kProfile, jsonEncode(p.toJson()));
  }

  Future<void> _saveStats() async {
    await _prefs.setString(_kStats, jsonEncode(stats.toJson()));
  }

  Future<void> _saveMedals() async {
    await _prefs.setString(
      _kMedals,
      jsonEncode(
        medals.map((k, v) => MapEntry(k, v.toIso8601String())),
      ),
    );
  }

  Future<void> _saveFriends() async {
    await _prefs.setString(
      _kFriends,
      jsonEncode(friends.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> _saveHistory() async {
    await _prefs.setString(
      _kHistory,
      jsonEncode(history.map((h) => h.toJson()).toList()),
    );
  }

  Future<void> _saveSettings() async {
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }
}

/// Summary built by the solo result screen.
class SoloRunResult {
  const SoloRunResult({
    required this.score,
    required this.modules,
    required this.correct,
    required this.wrong,
    required this.bombs,
    required this.bestCombo,
    required this.fastestMs,
    required this.cleanBombs,
    required this.timeLeftMs,
    required this.durationMs,
  });

  final int score;
  final int modules;
  final int correct;
  final int wrong;
  final int bombs;
  final int bestCombo;
  final int fastestMs;
  final int cleanBombs;
  final int timeLeftMs;
  final int durationMs;
}

class DuelRunResult {
  const DuelRunResult({
    required this.won,
    required this.draw,
    required this.rated,
    required this.score,
    required this.modules,
    required this.correct,
    required this.wrong,
    required this.bestCombo,
    required this.fastestMs,
    required this.durationMs,
    required this.opponentName,
    required this.opponentRating,
  });

  final bool won;
  final bool draw;
  final bool rated;
  final int score;
  final int modules;
  final int correct;
  final int wrong;
  final int bestCombo;
  final int fastestMs;
  final int durationMs;
  final String opponentName;
  final int opponentRating;
}
