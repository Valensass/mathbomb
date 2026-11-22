import 'package:bomb_math/game/math_problem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MathGenerator', () {
    test('tier 1 is always multiplication', () {
      for (var seed = 0; seed < 30; seed++) {
        final gen = MathGenerator(seed);
        for (var i = 0; i < 10; i++) {
          final p = gen.next(1);
          expect(p.op, 'mul');
          expect(p.prompt, contains('×'));
          expect(p.tier, 1);
          final parts = p.prompt.split(' × ');
          expect(parts.length, 2);
          expect(int.parse(parts[0]) * int.parse(parts[1]), p.answer);
        }
      }
    });

    test('every tier produces a solvable problem', () {
      for (var seed = 0; seed < 20; seed++) {
        final gen = MathGenerator(seed);
        for (var tier = 1; tier <= 10; tier++) {
          for (var i = 0; i < 20; i++) {
            final p = gen.next(tier);
            expect(p.prompt.trim(), isNotEmpty);
            expect(p.tier, tier);
            expect(p.answer, isA<int>());
            expect(p.op, isNotEmpty);
          }
        }
      }
    });

    test('is deterministic for a shared seed', () {
      final a = MathGenerator(4242);
      final b = MathGenerator(4242);
      for (var tier = 1; tier <= 10; tier++) {
        for (var i = 0; i < 25; i++) {
          final pa = a.next(tier);
          final pb = b.next(tier);
          expect(pa.prompt, pb.prompt);
          expect(pa.answer, pb.answer);
        }
      }
    });

    test('division problems are exact', () {
      final gen = MathGenerator(7);
      var checked = 0;
      for (var i = 0; i < 800 && checked < 20; i++) {
        final p = gen.next(7);
        if (p.op != 'div') continue;
        checked++;
        final parts = p.prompt.split(' ÷ ');
        expect(parts.length, 2);
        final dividend = int.parse(parts[0]);
        final divisor = int.parse(parts[1]);
        expect(dividend % divisor, 0);
        expect(dividend ~/ divisor, p.answer);
      }
      expect(checked, greaterThan(0));
    });

    test('later tiers are harder than multiplication tables', () {
      final easy = MathGenerator(11);
      final hard = MathGenerator(11);
      var easyMax = 0;
      var hardMax = 0;
      for (var i = 0; i < 300; i++) {
        final e = easy.next(1).answer.abs();
        if (e > easyMax) easyMax = e;
        final h = hard.next(10).answer.abs();
        if (h > hardMax) hardMax = h;
      }
      expect(easyMax, lessThanOrEqualTo(81));
      expect(hardMax, greaterThan(81));
    });

    test('no tier ever produces a negative answer', () {
      for (var seed = 0; seed < 40; seed++) {
        final gen = MathGenerator(seed);
        for (var tier = 1; tier <= 10; tier++) {
          for (var i = 0; i < 50; i++) {
            final p = gen.next(tier);
            expect(
              p.answer,
              greaterThan(0),
              reason: '${p.prompt} produced ${p.answer} at tier $tier',
            );
          }
        }
      }
    });

    test('tier 2 always uses a two-digit factor', () {
      final gen = MathGenerator(31);
      for (var i = 0; i < 60; i++) {
        final p = gen.next(2);
        final parts = p.prompt.split(' × ');
        expect(parts.length, 2);
        expect(int.parse(parts[0]), greaterThanOrEqualTo(11));
        expect(p.answer, greaterThanOrEqualTo(3 * 11));
      }
    });

    test('tier 10 squares a two-digit number', () {
      final gen = MathGenerator(17);
      for (var i = 0; i < 60; i++) {
        final p = gen.next(10);
        expect(p.prompt, endsWith('²'));
        final n = int.parse(p.prompt.substring(0, p.prompt.length - 1));
        expect(n, inInclusiveRange(12, 18));
        expect(p.answer, n * n);
      }
    });
  });
}
