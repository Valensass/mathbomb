import 'package:bomb_math/game/defuse_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefuseEngine', () {
    test('starts with multiplication', () {
      final engine = DefuseEngine(seed: 3)..start();
      expect(engine.problem.op, 'mul');
      expect(engine.problem.tier, 1);
      expect(engine.problem.prompt, contains('×'));
    });

    test('a correct typed answer scores and advances', () {
      final engine = DefuseEngine(seed: 3)..start();
      final startTime = engine.timeLeft;
      final firstPrompt = engine.problem.prompt;
      final outcome = engine.submit(engine.problem.answer)!;
      expect(outcome.correct, isTrue);
      expect(outcome.points, greaterThan(0));
      expect(engine.score, greaterThan(0));
      expect(engine.modulesCut, 1);
      expect(engine.combo, 1);
      expect(engine.timeLeft, greaterThan(startTime));
      expect(engine.problem.prompt, isNot(firstPrompt));
      expect(engine.tier, 2);
    });

    test('a wrong typed answer costs a strike and keeps the problem', () {
      final engine = DefuseEngine(seed: 4)..start();
      final prompt = engine.problem.prompt;
      final before = engine.timeLeft;
      final outcome = engine.submit(engine.problem.answer + 1)!;
      expect(outcome.correct, isFalse);
      expect(engine.strikes, 1);
      expect(engine.combo, 0);
      expect(engine.timeLeft, closeTo(before - 5, 0.001));
      expect(engine.problem.prompt, prompt);
      expect(engine.modulesCut, 0);
    });

    test('three strikes end the run', () {
      final engine = DefuseEngine(seed: 5)..start();
      for (var i = 0; i < 3; i++) {
        engine.submit(engine.problem.answer + 1);
      }
      expect(engine.over, isTrue);
      expect(engine.endReason, 'strikes');
      expect(engine.strikes, 3);
    });

    test('the fuse burns out into a timeout', () {
      final engine = DefuseEngine(seed: 6)..start();
      engine.tick(DefuseEngine.startFuse + 1);
      expect(engine.over, isTrue);
      expect(engine.endReason, 'timeout');
      expect(engine.timeLeft, 0);
    });

    test('four correct answers clear the bomb and pause for the interlude', () {
      final engine = DefuseEngine(seed: 8)..start();
      for (var i = 0; i < 3; i++) {
        engine.submit(engine.problem.answer);
      }
      expect(engine.bombsDefused, 0);
      final outcome = engine.submit(engine.problem.answer)!;
      expect(outcome.bombDefused, isTrue);
      expect(engine.bombsDefused, 1);
      expect(engine.interlude, isTrue);
      final frozen = engine.timeLeft;
      engine.tick(1);
      expect(engine.timeLeft, frozen);
      engine.nextBomb();
      expect(engine.bombNumber, 2);
      expect(engine.modulesCutInBomb, 0);
      expect(engine.interlude, isFalse);
      expect(engine.problem.tier, greaterThan(1));
    });

    test('difficulty increases with every solved module', () {
      final engine = DefuseEngine(seed: 9)..start();
      expect(engine.tier, 1);
      engine.submit(engine.problem.answer);
      expect(engine.tier, 2);
      engine.submit(engine.problem.answer);
      expect(engine.tier, 3);
      engine.submit(engine.problem.answer);
      expect(engine.tier, 4);
    });

    test('combo multiplier increases rewards', () {
      final engine = DefuseEngine(seed: 9)..start();
      final first = engine.submit(engine.problem.answer)!.points;
      final second = engine.submit(engine.problem.answer)!.points;
      expect(second, greaterThan(first));
      expect(engine.bestCombo, 2);
    });

    test('pause freezes the fuse', () {
      final engine = DefuseEngine(seed: 10)..start();
      engine.paused = true;
      final before = engine.timeLeft;
      engine.tick(3);
      expect(engine.timeLeft, before);
      expect(engine.submit(engine.problem.answer), isNull);
    });
  });
}
