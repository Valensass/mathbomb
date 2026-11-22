import 'dart:math';

/// A single typed-answer challenge. Answers are always non-negative.
class MathProblem {
  const MathProblem({
    required this.prompt,
    required this.answer,
    required this.tier,
    required this.op,
  });

  final String prompt;
  final int answer;
  final int tier;

  /// add | sub | mul | div | mixed
  final String op;

  bool isCorrect(int value) => value == answer;
}

/// Deterministic arithmetic generator with a strictly ordered ladder.
///
/// Tier 1 is always multiplication. Every later tier adds a genuinely harder
/// operation: bigger factors, an extra term, operator precedence, grouping,
/// inverse division or a two-digit square. Subtractions are always kept
/// positive, so answers are never negative.
class MathGenerator {
  MathGenerator(int seed) : _rng = Random(seed);

  final Random _rng;

  int _int(int min, int max) => min + _rng.nextInt(max - min + 1);

  MathProblem next(int tier) {
    final t = tier.clamp(1, 10);
    final (prompt, answer, op) = switch (t) {
      1 => _mul(2, 9, 2, 9),
      2 => _mul(11, 19, 3, 9),
      3 => _mulPlus(),
      4 => _mulMinus(),
      5 => _precedence(),
      6 => _parentheses(),
      7 => _division(),
      8 => _twoProducts(),
      9 => _threeTerm(),
      _ => _square(),
    };
    assert(answer >= 0, 'Negative answers are not allowed');
    return MathProblem(prompt: prompt, answer: answer, tier: t, op: op);
  }

  // 1 — multiplication tables.
  (String, int, String) _mul(int aMin, int aMax, int bMin, int bMax) {
    final a = _int(aMin, aMax);
    final b = _int(bMin, bMax);
    return ('$a × $b', a * b, 'mul');
  }

  // 3 — two-digit × one-digit, then addition.
  (String, int, String) _mulPlus() {
    final a = _int(11, 19);
    final b = _int(3, 9);
    final c = _int(2, 20);
    return ('$a × $b + $c', a * b + c, 'mixed');
  }

  // 4 — same multiplication, then subtraction (always positive).
  (String, int, String) _mulMinus() {
    final a = _int(11, 19);
    final b = _int(3, 9);
    final product = a * b;
    final c = _int(2, max(2, min(30, product - 1)));
    return ('$a × $b − $c', product - c, 'mixed');
  }

  // 5 — operator precedence.
  (String, int, String) _precedence() {
    final a = _int(20, 50);
    final b = _int(3, 9);
    final c = _int(3, 9);
    return ('$a + $b × $c', a + b * c, 'mixed');
  }

  // 6 — grouping with parentheses.
  (String, int, String) _parentheses() {
    final a = _int(4, 9);
    final b = _int(4, 9);
    final c = _int(5, 9);
    return ('($a + $b) × $c', (a + b) * c, 'mixed');
  }

  // 7 — exact division.
  (String, int, String) _division() {
    final b = _int(4, 12);
    final q = _int(6, 12);
    return ('${b * q} ÷ $b', q, 'div');
  }

  // 8 — two products in one expression.
  (String, int, String) _twoProducts() {
    final a = _int(4, 9);
    final b = _int(4, 9);
    final c = _int(4, 9);
    final d = _int(4, 9);
    return ('$a × $b + $c × $d', a * b + c * d, 'mixed');
  }

  // 9 — three-term expression: grouping, multiplication and subtraction.
  (String, int, String) _threeTerm() {
    final a = _int(6, 9);
    final b = _int(6, 9);
    final c = _int(6, 9);
    final d = _int(2, 35);
    final product = (a + b) * c;
    return ('($a + $b) × $c − $d', product - d, 'mixed');
  }

  // 10 — two-digit squares: the largest computation in the game.
  (String, int, String) _square() {
    final n = _int(12, 18);
    return ('$n²', n * n, 'mul');
  }
}
