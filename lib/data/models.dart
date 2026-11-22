import 'dart:math';

/// Persistent player identity.
class PlayerProfile {
  PlayerProfile({
    required this.id,
    required this.name,
    required this.tag,
    required this.friendCode,
    required this.emblem,
    required this.colorIndex,
    required this.rating,
    required this.createdAt,
  });

  final String id;
  String name;
  String tag;
  String friendCode;
  int emblem;
  int colorIndex;
  int rating;
  DateTime createdAt;

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String makeCode(Random rng) {
    final b = StringBuffer('BM-');
    for (var i = 0; i < 6; i++) {
      b.write(_codeAlphabet[rng.nextInt(_codeAlphabet.length)]);
    }
    return b.toString();
  }

  static String makeTag(String name, Random rng) {
    final letters = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (letters.length >= 3) return letters.substring(0, 3).padRight(4, 'X');
    return String.fromCharCodes(
      List.generate(4, (_) => 65 + rng.nextInt(26)),
    );
  }

  factory PlayerProfile.create(String rawName, {Random? random}) {
    final rng = random ?? Random();
    final name = rawName.trim().isEmpty ? 'OPERATIVE' : rawName.trim();
    final now = DateTime.now();
    return PlayerProfile(
      id: 'p${now.microsecondsSinceEpoch.toRadixString(36)}'
          '${rng.nextInt(1 << 20).toRadixString(36)}',
      name: name.length > 14 ? name.substring(0, 14) : name,
      tag: makeTag(name, rng),
      friendCode: makeCode(rng),
      emblem: rng.nextInt(6),
      colorIndex: rng.nextInt(6),
      rating: 1000,
      createdAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tag': tag,
    'friendCode': friendCode,
    'emblem': emblem,
    'colorIndex': colorIndex,
    'rating': rating,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? 'OPERATIVE').toString(),
    tag: (j['tag'] ?? 'BM').toString(),
    friendCode: (j['friendCode'] ?? 'BM-000000').toString(),
    emblem: (j['emblem'] as num?)?.toInt() ?? 0,
    colorIndex: (j['colorIndex'] as num?)?.toInt() ?? 0,
    rating: (j['rating'] as num?)?.toInt() ?? 1000,
    createdAt:
        DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
  );

  PlayerProfile copyWith({String? name, int? rating, int? emblem}) =>
      PlayerProfile(
        id: id,
        name: name ?? this.name,
        tag: tag,
        friendCode: friendCode,
        emblem: emblem ?? this.emblem,
        colorIndex: colorIndex,
        rating: rating ?? this.rating,
        createdAt: createdAt,
      );
}

class GameStats {
  GameStats({
    this.runs = 0,
    this.modulesCut = 0,
    this.correct = 0,
    this.wrong = 0,
    this.bombsDefused = 0,
    this.bestScore = 0,
    this.bestCombo = 0,
    this.fastestMs = 0,
    this.cleanBombs = 0,
    this.bestTimeLeftMs = 0,
    this.bestBombs = 0,
    this.duelsPlayed = 0,
    this.duelsWon = 0,
    this.duelsLost = 0,
    this.duelsDrawn = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.recentScores = const [],
  });

  int runs;
  int modulesCut;
  int correct;
  int wrong;
  int bombsDefused;
  int bestScore;
  int bestCombo;
  int fastestMs; // 0 = none
  int cleanBombs;
  int bestTimeLeftMs;
  int bestBombs;
  int duelsPlayed;
  int duelsWon;
  int duelsLost;
  int duelsDrawn;
  int currentStreak;
  int bestStreak;
  List<int> recentScores;

  int get answers => correct + wrong;
  double get accuracy => answers == 0 ? 0 : correct / answers;
  int get winRate =>
      duelsPlayed == 0 ? 0 : ((duelsWon / duelsPlayed) * 100).round();

  void addSoloRun({
    required int score,
    required int modules,
    required int correctAnswers,
    required int wrongAnswers,
    required int bombs,
    required int combo,
    required int fastestCutMs,
    required int cleanBombCount,
    required int timeLeftMs,
  }) {
    runs++;
    modulesCut += modules;
    correct += correctAnswers;
    wrong += wrongAnswers;
    bombsDefused += bombs;
    bestScore = max(bestScore, score);
    bestCombo = max(bestCombo, combo);
    if (fastestCutMs > 0) {
      fastestMs = fastestMs == 0 ? fastestCutMs : min(fastestMs, fastestCutMs);
    }
    cleanBombs += cleanBombCount;
    bestTimeLeftMs = max(bestTimeLeftMs, timeLeftMs);
    bestBombs = max(bestBombs, bombs);
    recentScores = [...recentScores, score];
    if (recentScores.length > 10) {
      recentScores = recentScores.sublist(recentScores.length - 10);
    }
  }

  void addDuel({
    required bool won,
    required bool draw,
    required int score,
    required int modules,
    required int correctAnswers,
    required int wrongAnswers,
    required int combo,
    required int fastestCutMs,
  }) {
    duelsPlayed++;
    modulesCut += modules;
    correct += correctAnswers;
    wrong += wrongAnswers;
    bestScore = max(bestScore, score);
    bestCombo = max(bestCombo, combo);
    if (fastestCutMs > 0) {
      fastestMs = fastestMs == 0 ? fastestCutMs : min(fastestMs, fastestCutMs);
    }
    if (draw) {
      duelsDrawn++;
      currentStreak = 0;
    } else if (won) {
      duelsWon++;
      currentStreak++;
      bestStreak = max(bestStreak, currentStreak);
    } else {
      duelsLost++;
      currentStreak = 0;
    }
  }

  Map<String, dynamic> toJson() => {
    'runs': runs,
    'modulesCut': modulesCut,
    'correct': correct,
    'wrong': wrong,
    'bombsDefused': bombsDefused,
    'bestScore': bestScore,
    'bestCombo': bestCombo,
    'fastestMs': fastestMs,
    'cleanBombs': cleanBombs,
    'bestTimeLeftMs': bestTimeLeftMs,
    'bestBombs': bestBombs,
    'duelsPlayed': duelsPlayed,
    'duelsWon': duelsWon,
    'duelsLost': duelsLost,
    'duelsDrawn': duelsDrawn,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'recentScores': recentScores,
  };

  factory GameStats.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return GameStats(
      runs: n('runs'),
      modulesCut: n('modulesCut'),
      correct: n('correct'),
      wrong: n('wrong'),
      bombsDefused: n('bombsDefused'),
      bestScore: n('bestScore'),
      bestCombo: n('bestCombo'),
      fastestMs: n('fastestMs'),
      cleanBombs: n('cleanBombs'),
      bestTimeLeftMs: n('bestTimeLeftMs'),
      bestBombs: n('bestBombs'),
      duelsPlayed: n('duelsPlayed'),
      duelsWon: n('duelsWon'),
      duelsLost: n('duelsLost'),
      duelsDrawn: n('duelsDrawn'),
      currentStreak: n('currentStreak'),
      bestStreak: n('bestStreak'),
      recentScores: ((j['recentScores'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

class MatchRecord {
  MatchRecord({
    required this.mode,
    required this.outcome,
    required this.score,
    required this.modules,
    required this.durationMs,
    required this.at,
    this.opponent = '',
  });

  final String mode; // solo | duel
  final String outcome; // run | win | loss | draw
  final int score;
  final int modules;
  final int durationMs;
  final DateTime at;
  final String opponent;

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'outcome': outcome,
    'score': score,
    'modules': modules,
    'durationMs': durationMs,
    'at': at.toIso8601String(),
    'opponent': opponent,
  };

  factory MatchRecord.fromJson(Map<String, dynamic> j) => MatchRecord(
    mode: (j['mode'] ?? 'solo').toString(),
    outcome: (j['outcome'] ?? 'run').toString(),
    score: (j['score'] as num?)?.toInt() ?? 0,
    modules: (j['modules'] as num?)?.toInt() ?? 0,
    durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
    at: DateTime.tryParse((j['at'] ?? '').toString()) ?? DateTime.now(),
    opponent: (j['opponent'] ?? '').toString(),
  );
}

class FriendInfo {
  FriendInfo({
    required this.id,
    required this.name,
    required this.tag,
    required this.code,
    required this.rating,
    this.online = false,
  });

  final String id;
  final String name;
  final String tag;
  final String code;
  final int rating;
  bool online;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tag': tag,
    'code': code,
    'rating': rating,
    'online': online,
  };

  factory FriendInfo.fromJson(Map<String, dynamic> j) => FriendInfo(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    tag: (j['tag'] ?? '').toString(),
    code: (j['code'] ?? j['friendCode'] ?? '').toString(),
    rating: (j['rating'] as num?)?.toInt() ?? 1000,
    online: j['online'] == true,
  );
}

class AppSettings {
  AppSettings({
    this.language = 'system',
    this.sfx = true,
    this.music = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.highContrast = false,
    this.serverUrl = 'ws://10.0.2.2:8080/ws',
    this.botDifficulty = 'normal',
    this.onboarded = false,
  });

  String language; // system | en | tr
  bool sfx;
  bool music;
  bool haptics;
  bool reduceMotion;
  bool highContrast;
  String serverUrl;
  String botDifficulty;
  bool onboarded;

  Map<String, dynamic> toJson() => {
    'language': language,
    'sfx': sfx,
    'music': music,
    'haptics': haptics,
    'reduceMotion': reduceMotion,
    'highContrast': highContrast,
    'serverUrl': serverUrl,
    'botDifficulty': botDifficulty,
    'onboarded': onboarded,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    language: (j['language'] ?? 'system').toString(),
    sfx: j['sfx'] != false,
    music: j['music'] != false,
    haptics: j['haptics'] != false,
    reduceMotion: j['reduceMotion'] == true,
    highContrast: j['highContrast'] == true,
    serverUrl: (j['serverUrl'] ?? 'ws://10.0.2.2:8080/ws').toString(),
    botDifficulty: (j['botDifficulty'] ?? 'normal').toString(),
    onboarded: j['onboarded'] == true,
  );

  AppSettings copyWith({
    String? language,
    bool? sfx,
    bool? music,
    bool? haptics,
    bool? reduceMotion,
    bool? highContrast,
    String? serverUrl,
    String? botDifficulty,
    bool? onboarded,
  }) => AppSettings(
    language: language ?? this.language,
    sfx: sfx ?? this.sfx,
    music: music ?? this.music,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    highContrast: highContrast ?? this.highContrast,
    serverUrl: serverUrl ?? this.serverUrl,
    botDifficulty: botDifficulty ?? this.botDifficulty,
    onboarded: onboarded ?? this.onboarded,
  );
}

/// Data needed to launch an online duel received from the server.
class OnlineMatchStart {
  OnlineMatchStart({
    required this.matchId,
    required this.seed,
    required this.opponentId,
    required this.opponentName,
    required this.opponentTag,
    required this.opponentRating,
  });

  final String matchId;
  final int seed;
  final String opponentId;
  final String opponentName;
  final String opponentTag;
  final int opponentRating;

  factory OnlineMatchStart.fromJson(Map<String, dynamic> j) => OnlineMatchStart(
    matchId: (j['matchId'] ?? '').toString(),
    seed: (j['seed'] as num?)?.toInt() ?? 1,
    opponentId: (j['opponentId'] ?? '').toString(),
    opponentName: (j['opponentName'] ?? 'OPERATIVE').toString(),
    opponentTag: (j['opponentTag'] ?? '??').toString(),
    opponentRating: (j['opponentRating'] as num?)?.toInt() ?? 1000,
  );
}
