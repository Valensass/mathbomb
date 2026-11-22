import 'package:bomb_math/game/duel_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuelSequence', () {
    test('is deterministic per seed and turn', () {
      for (var turn = 0; turn < 12; turn++) {
        final a = DuelSequence.problemFor(777, turn);
        final b = DuelSequence.problemFor(777, turn);
        expect(a.prompt, b.prompt);
        expect(a.answer, b.answer);
        expect(a.tier, b.tier);
      }
    });

    test('starts at multiplication and pairs turns by tier', () {
      expect(DuelSequence.problemFor(42, 0).tier, 1);
      expect(DuelSequence.problemFor(42, 0).op, 'mul');
      expect(DuelSequence.problemFor(42, 1).tier, 1);
      expect(DuelSequence.problemFor(42, 2).tier, 2);
      expect(DuelSequence.problemFor(42, 3).tier, 2);
      expect(DuelSequence.problemFor(42, 8).tier, 5);
    });

    test('pairs share a tier but pose different problems', () {
      for (var pair = 0; pair < 5; pair++) {
        final first = DuelSequence.problemFor(2024, pair * 2);
        final second = DuelSequence.problemFor(2024, pair * 2 + 1);
        expect(second.tier, first.tier);
        expect(second.prompt, isNot(first.prompt));
      }
    });
  });

  group('TurnDuelEngine', () {
    late TurnDuelEngine engine;
    setUp(() {
      engine = TurnDuelEngine(seed: 21, firstId: 'a', secondId: 'b');
    });

    test('players alternate turns', () {
      expect(engine.activeId, 'a');
      engine.submit('a', engine.problem.answer);
      expect(engine.activeId, 'b');
      engine.submit('b', engine.problem.answer);
      expect(engine.activeId, 'a');
    });

    test('turns alternate strictly across the whole match', () {
      final order = <String>[];
      while (!engine.finished) {
        order.add(engine.activeId);
        engine.passTurn();
      }
      expect(order.length, TurnDuelEngine.maxTurns);
      expect(order.first, 'a');
      expect(order[1], 'b');
      for (var i = 1; i < order.length; i++) {
        expect(order[i], isNot(order[i - 1]));
      }
    });

    test('a correct answer scores one point', () {
      final result = engine.submit('a', engine.problem.answer, elapsedMs: 900);
      expect(result.correct, isTrue);
      expect(engine.scoreOf('a'), 1);
      expect(engine.scoreOf('b'), 0);
      expect(engine.correctOf('a'), 1);
      expect(engine.fastestOf('a'), 900);
    });

    test('a wrong answer passes the turn with no point', () {
      final result = engine.submit('a', engine.problem.answer + 1);
      expect(result.correct, isFalse);
      expect(engine.scoreOf('a'), 0);
      expect(engine.wrongOf('a'), 1);
      expect(engine.activeId, 'b');
    });

    test('a non-active player cannot answer', () {
      final result = engine.submit('b', engine.problem.answer);
      expect(result.accepted, isFalse);
      expect(engine.scoreOf('b'), 0);
      expect(engine.activeId, 'a');
    });

    test('first to four points wins', () {
      for (var i = 0; i < 4; i++) {
        engine.submit('a', engine.problem.answer);
        if (engine.finished) break;
        engine.passTurn(); // b misses
      }
      expect(engine.finished, isTrue);
      expect(engine.winnerId, 'a');
      expect(engine.firstScore, 4);
    });

    test('turn limit resolves to a draw at equal scores', () {
      for (var i = 0; i < TurnDuelEngine.maxTurns; i++) {
        engine.passTurn();
      }
      expect(engine.finished, isTrue);
      expect(engine.draw, isTrue);
      expect(engine.winnerId, isNull);
    });

    test('combo and fastest are tracked per player', () {
      engine.submit('a', engine.problem.answer, elapsedMs: 1200);
      engine.submit('b', engine.problem.answer + 1);
      engine.submit('a', engine.problem.answer, elapsedMs: 800);
      expect(engine.bestComboOf('a'), 2);
      expect(engine.fastestOf('a'), 800);
      expect(engine.wrongOf('b'), 1);
    });
  });

  group('TurnBot', () {
    test('difficulties have increasing accuracy and speed', () {
      final easy = TurnBot(difficulty: 'easy', seed: 3);
      final master = TurnBot(difficulty: 'master', seed: 3);
      expect(easy.accuracy, lessThan(master.accuracy));
      expect(easy.thinkMs(0), greaterThan(master.thinkMs(0)));
    });

    test('think time stays inside the turn budget', () {
      for (final d in ['easy', 'normal', 'hard', 'master']) {
        final bot = TurnBot(difficulty: d, seed: 9);
        for (var turn = 0; turn < 20; turn++) {
          expect(bot.thinkMs(turn), lessThan(12000));
          expect(bot.thinkMs(turn), greaterThan(500));
        }
      }
    });
  });
}
