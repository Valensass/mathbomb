import 'package:bomb_math/data/models.dart';
import 'package:bomb_math/game/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MedalDef medal(String id) => MedalDef.all.firstWhere((m) => m.id == id);

  test('first cut unlocks after the first module', () {
    final stats = GameStats(modulesCut: 1);
    final ctx = MedalContext(stats: stats, friends: 0, rating: 1000);
    expect(medal('first_cut').progress(ctx), 1);
    expect(medal('first_cut').progress(ctx) >= medal('first_cut').target, isTrue);
  });

  test('bomb squad requires ten bombs', () {
    final nine = MedalContext(
      stats: GameStats(bombsDefused: 9),
      friends: 0,
      rating: 1000,
    );
    final ten = MedalContext(
      stats: GameStats(bombsDefused: 10),
      friends: 0,
      rating: 1000,
    );
    expect(medal('bomb_squad').progress(nine), lessThan(10));
    expect(medal('bomb_squad').progress(ten), 10);
  });

  test('sharpshooter is gated behind 100 answers', () {
    final early = MedalContext(
      stats: GameStats(correct: 10, wrong: 0),
      friends: 0,
      rating: 1000,
    );
    expect(
      medal('sharpshooter').progress(early),
      lessThan(medal('sharpshooter').target),
    );
    final accurate = MedalContext(
      stats: GameStats(correct: 97, wrong: 3),
      friends: 0,
      rating: 1000,
    );
    expect(medal('sharpshooter').progress(accurate), greaterThanOrEqualTo(95));
  });

  test('speed demon requires a sub-two-second cut', () {
    final slow = MedalContext(
      stats: GameStats(fastestMs: 2500),
      friends: 0,
      rating: 1000,
    );
    final fast = MedalContext(
      stats: GameStats(fastestMs: 1500),
      friends: 0,
      rating: 1000,
    );
    expect(medal('speed_demon').progress(slow), 0);
    expect(medal('speed_demon').progress(fast), 1);
  });

  test('rating and social medals track their context', () {
    final ctx = MedalContext(
      stats: GameStats(),
      friends: 2,
      rating: 1425,
    );
    expect(medal('social').progress(ctx), 2);
    expect(medal('contender').progress(ctx), 1425);
    expect(
      medal('elite').progress(ctx) >= medal('elite').target,
      isTrue,
    );
  });

  test('progress is clamped for the UI', () {
    final ctx = MedalContext(
      stats: GameStats(bestCombo: 90),
      friends: 0,
      rating: 1000,
    );
    expect(medal('neuro').clampProgress(ctx), medal('neuro').target);
  });
}
