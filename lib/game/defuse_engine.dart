import 'dart:math' as math;

import 'math_problem.dart';

/// Result of submitting a typed answer in a solo run.
class AnswerOutcome {
  const AnswerOutcome({
    required this.correct,
    required this.points,
    required this.timeDelta,
    required this.bombDefused,
    required this.runOver,
    this.endReason,
  });

  final bool correct;
  final int points;
  final double timeDelta;
  final bool bombDefused;
  final bool runOver;
  final String? endReason;
}

/// Solo survival engine. UI-free and deterministic for a given seed.
class DefuseEngine {
  DefuseEngine({int seed = 1, this.modulesPerBomb = 4})
    : _generator = MathGenerator(seed);

  static const double startFuse = 45;
  static const double maxFuse = 60;
  static const double correctBonus = 2.5;
  static const double wrongPenalty = 5;
  static const double bombBonus = 10;
  static const int maxStrikes = 3;

  final MathGenerator _generator;
  final int modulesPerBomb;

  late MathProblem problem;
  double timeLeft = startFuse;
  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int strikes = 0;
  int bombNumber = 1;
  int modulesCutInBomb = 0;
  int modulesCut = 0;
  int bombsDefused = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  int cleanBombs = 0;
  int fastestCutMs = 0;
  int tier = 1;

  bool over = false;
  bool paused = false;
  bool interlude = false;
  String? endReason;

  double _problemClock = 0;
  bool _bombClean = true;

  void start() {
    tier = 1;
    problem = _generator.next(tier);
  }

  bool get isRunning => !over;

  int get answered => correctAnswers + wrongAnswers;

  double get accuracy => answered == 0 ? 0 : correctAnswers / answered;

  double get progress => modulesCutInBomb / modulesPerBomb;

  void tick(double dt) {
    if (over || paused || interlude) return;
    _problemClock += dt;
    timeLeft -= dt;
    if (timeLeft <= 0) {
      timeLeft = 0;
      over = true;
      endReason = 'timeout';
    }
  }

  void togglePause() {
    if (over) return;
    paused = !paused;
  }

  AnswerOutcome? submit(int value) {
    if (over || paused || interlude) return null;

    if (problem.isCorrect(value)) {
      combo++;
      if (combo > bestCombo) bestCombo = combo;
      correctAnswers++;
      modulesCut++;
      modulesCutInBomb++;
      final ms = math.max(1, (_problemClock * 1000).round());
      if (fastestCutMs == 0 || ms < fastestCutMs) fastestCutMs = ms;
      final multiplier = 1 + 0.1 * math.min(combo, 20);
      var points = ((100 + 25 * tier) * multiplier).round();
      if (_problemClock < 4) points += 50;
      score += points;
      timeLeft = math.min(maxFuse, timeLeft + correctBonus);

      var defused = false;
      if (modulesCutInBomb >= modulesPerBomb) {
        defused = true;
        bombsDefused++;
        score += 300 * bombsDefused;
        timeLeft = math.min(maxFuse, timeLeft + bombBonus);
        if (_bombClean) cleanBombs++;
        interlude = true;
      } else {
        _nextProblem();
      }

      return AnswerOutcome(
        correct: true,
        points: points,
        timeDelta: correctBonus,
        bombDefused: defused,
        runOver: false,
      );
    }

    combo = 0;
    strikes++;
    wrongAnswers++;
    _bombClean = false;
    timeLeft = math.max(0, timeLeft - wrongPenalty);

    var reason = 'strikes';
    if (strikes >= maxStrikes) {
      over = true;
      reason = 'strikes';
    } else if (timeLeft <= 0) {
      over = true;
      reason = 'timeout';
    }
    endReason = over ? reason : null;

    return AnswerOutcome(
      correct: false,
      points: 0,
      timeDelta: -wrongPenalty,
      bombDefused: false,
      runOver: over,
      endReason: over ? reason : null,
    );
  }

  /// Called by the UI after the "BOMB DEFUSED" interlude.
  void nextBomb() {
    if (!interlude || over) return;
    interlude = false;
    bombNumber++;
    modulesCutInBomb = 0;
    _bombClean = true;
    _nextProblem();
  }

  void _nextProblem() {
    _problemClock = 0;
    tier = math.min(10, 1 + modulesCut);
    problem = _generator.next(tier);
  }
}
