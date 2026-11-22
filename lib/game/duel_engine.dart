import 'dart:math' as math;

import 'math_problem.dart';

/// Deterministic problem sequence for a turn-based duel.
///
/// Two consecutive turns share a difficulty tier, so the player moving second
/// is not punished with a harder question than the opener.
class DuelSequence {
  static MathProblem problemFor(int seed, int turnIndex) {
    final tier = (1 + turnIndex ~/ 2).clamp(1, 10);
    final mixedSeed = seed ^ (0x9E3779B1 * (turnIndex + 1));
    return MathGenerator(mixedSeed).next(tier);
  }
}

class DuelAnswerResult {
  const DuelAnswerResult({
    required this.accepted,
    required this.correct,
    required this.finished,
    required this.draw,
    this.winnerId,
  });

  final bool accepted;
  final bool correct;
  final bool finished;
  final bool draw;
  final String? winnerId;
}

/// Local, UI-free turn engine used for bot games and unit tests. The online
/// screen mirrors the same rules but the server owns the turn clock.
class TurnDuelEngine {
  TurnDuelEngine({
    required this.seed,
    required this.firstId,
    required this.secondId,
  });

  static const int pointsToWin = 4;
  static const int turnSeconds = 15;
  static const int maxTurns = 20;

  final int seed;
  final String firstId;
  final String secondId;

  int turnIndex = 0;
  int firstScore = 0;
  int secondScore = 0;
  int firstCorrect = 0;
  int firstWrong = 0;
  int secondCorrect = 0;
  int secondWrong = 0;
  int firstBestCombo = 0;
  int secondBestCombo = 0;
  int _firstCombo = 0;
  int _secondCombo = 0;
  int firstFastestMs = 0;
  int secondFastestMs = 0;
  bool finished = false;
  bool draw = false;
  String? winnerId;

  String get activeId => turnIndex.isEven ? firstId : secondId;

  MathProblem get problem => DuelSequence.problemFor(seed, turnIndex);

  int scoreOf(String id) => id == firstId ? firstScore : secondScore;

  int correctOf(String id) => id == firstId ? firstCorrect : secondCorrect;

  int wrongOf(String id) => id == firstId ? firstWrong : secondWrong;

  int bestComboOf(String id) =>
      id == firstId ? firstBestCombo : secondBestCombo;

  int fastestOf(String id) => id == firstId ? firstFastestMs : secondFastestMs;

  bool isActive(String id) => activeId == id;

  DuelAnswerResult submit(
    String playerId,
    int value, {
    int elapsedMs = 0,
  }) {
    if (finished || playerId != activeId) {
      return const DuelAnswerResult(
        accepted: false,
        correct: false,
        finished: false,
        draw: false,
      );
    }
    final correct = problem.isCorrect(value);
    if (correct) {
      _award(playerId, elapsedMs);
    } else {
      _penalise(playerId);
    }
    if (finished) {
      return DuelAnswerResult(
        accepted: true,
        correct: correct,
        finished: true,
        draw: draw,
        winnerId: winnerId,
      );
    }
    _advanceTurn();
    return DuelAnswerResult(
      accepted: true,
      correct: correct,
      finished: finished,
      draw: draw,
      winnerId: winnerId,
    );
  }

  /// Wrong answers and turn timeouts simply pass the turn.
  DuelAnswerResult passTurn() {
    if (finished) {
      return const DuelAnswerResult(
        accepted: false,
        correct: false,
        finished: false,
        draw: false,
      );
    }
    _advanceTurn();
    return DuelAnswerResult(
      accepted: true,
      correct: false,
      finished: finished,
      draw: draw,
      winnerId: winnerId,
    );
  }

  void _award(String playerId, int elapsedMs) {
    final first = playerId == firstId;
    _setScore(playerId, scoreOf(playerId) + 1);
    if (first) {
      firstCorrect++;
      _firstCombo++;
      firstBestCombo = math.max(firstBestCombo, _firstCombo);
      if (elapsedMs > 0) {
        firstFastestMs = firstFastestMs == 0
            ? elapsedMs
            : math.min(firstFastestMs, elapsedMs);
      }
    } else {
      secondCorrect++;
      _secondCombo++;
      secondBestCombo = math.max(secondBestCombo, _secondCombo);
      if (elapsedMs > 0) {
        secondFastestMs = secondFastestMs == 0
            ? elapsedMs
            : math.min(secondFastestMs, elapsedMs);
      }
    }
    if (scoreOf(playerId) >= pointsToWin) {
      finished = true;
      winnerId = playerId;
    }
  }

  void _penalise(String playerId) {
    if (playerId == firstId) {
      firstWrong++;
      _firstCombo = 0;
    } else {
      secondWrong++;
      _secondCombo = 0;
    }
  }

  void _advanceTurn() {
    turnIndex++;
    if (turnIndex >= maxTurns) {
      finished = true;
      if (firstScore == secondScore) {
        draw = true;
        winnerId = null;
      } else {
        winnerId = firstScore > secondScore ? firstId : secondId;
      }
    }
  }

  void _setScore(String playerId, int value) {
    if (playerId == firstId) {
      firstScore = value;
    } else {
      secondScore = value;
    }
  }
}

/// Offline opponent. Accuracy and thinking time scale with difficulty.
class TurnBot {
  TurnBot({required this.difficulty, required int seed})
    : _rng = math.Random(seed ^ 0x5EED);

  final String difficulty;
  final math.Random _rng;

  double get accuracy => switch (difficulty) {
    'easy' => 0.55,
    'hard' => 0.85,
    'master' => 0.95,
    _ => 0.72,
  };

  int thinkMs(int turnIndex) {
    final base = switch (difficulty) {
      'easy' => 5200,
      'hard' => 2800,
      'master' => 1900,
      _ => 3900,
    };
    final jitter = _rng.nextInt(1200);
    return math.min(9000, base + jitter - 600 + turnIndex * 40);
  }

  bool answersCorrectly() => _rng.nextDouble() < accuracy;
}

