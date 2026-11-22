import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/l10n.dart';
import '../../data/models.dart';
import '../../services/app_state.dart';
import '../widgets/arena_background.dart';
import '../widgets/ui_kit.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.stats;
    final tr = context.l10n.isTr;
    final recent = stats.recentScores;

    return Scaffold(
      body: ArenaBackground(
        reduceMotion: state.settings.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              ScreenTopBar(title: context.t('stats.title')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                  children: [
                    GlowCard(
                      padding: const EdgeInsets.all(18),
                      glow: AppColors.amber,
                      borderColor: AppColors.amber.withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          _AccuracyRing(accuracy: stats.accuracy),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('stats.rating'),
                                  style: hudLabel,
                                ),
                                Text(
                                  '${state.rating}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 34,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.amber,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    ChipPill(
                                      label:
                                          '${context.t('stats.streak')} ${stats.currentStreak}',
                                      icon: Icons.local_fire_department_rounded,
                                      color: AppColors.amber,
                                    ),
                                    const SizedBox(width: 6),
                                    ChipPill(
                                      label:
                                          '${stats.duelsWon}W · ${stats.duelsLost}L',
                                      color: AppColors.cyan,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(context.t('stats.overview')),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final w = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: w,
                              child: StatTile(
                                label: context.t('stats.runs'),
                                value: '${stats.runs}',
                                accent: AppColors.text,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: StatTile(
                                label: context.t('stats.modules'),
                                value: formatInt(stats.modulesCut, tr: tr),
                                accent: AppColors.cyan,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: StatTile(
                                label: context.t('stats.bestScore'),
                                value: formatInt(stats.bestScore, tr: tr),
                                accent: AppColors.amber,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: StatTile(
                                label: context.t('stats.bestCombo'),
                                value: '×${stats.bestCombo}',
                                accent: AppColors.amber,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: StatTile(
                                label: context.t('stats.bombs'),
                                value: '${stats.bombsDefused}',
                                accent: AppColors.green,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: StatTile(
                                label: context.t('stats.fastest'),
                                value: stats.fastestMs == 0
                                    ? '—'
                                    : '${(stats.fastestMs / 1000).toStringAsFixed(2)}s',
                                accent: AppColors.green,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: StatTile(
                                label: context.t('stats.duels'),
                                value: '${stats.duelsPlayed}',
                                accent: AppColors.text,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: StatTile(
                                label: context.t('stats.wins'),
                                value: '${stats.duelsWon}',
                                accent: AppColors.green,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(context.t('stats.recent')),
                    GlowCard(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      child: recent.length < 2
                          ? SizedBox(
                              height: 110,
                              child: Center(
                                child: Text(
                                  context.t(
                                    recent.isEmpty
                                        ? 'stats.noHistory'
                                        : 'stats.trendHint',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 110,
                              child: CustomPaint(
                                painter: _SparkPainter(recent),
                                size: Size.infinite,
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(context.t('stats.history')),
                    if (state.history.isEmpty)
                      GlowCard(
                        child: Text(
                          context.t('stats.noHistory'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                      )
                    else
                      for (final record in state.history.take(12))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HistoryTile(record: record),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccuracyRing extends StatelessWidget {
  const _AccuracyRing({required this.accuracy});

  final double accuracy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: accuracy.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(value),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(value * 100).round()}%',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cyan,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.t('stats.accuracy'),
                  style: const TextStyle(
                    fontSize: 7,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = AppColors.line.withValues(alpha: 0.6);
    canvas.drawCircle(center, radius, bg);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppColors.cyan, AppColors.green],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.scores);

  final List<int> scores;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;
    final maxScore = scores.reduce(math.max).toDouble();
    final minScore = scores.reduce(math.min).toDouble();
    final range = math.max(1.0, maxScore - minScore);
    final dx = scores.length == 1 ? 0.0 : size.width / (scores.length - 1);
    final points = <Offset>[
      for (var i = 0; i < scores.length; i++)
        Offset(
          i * dx,
          size.height - 8 - ((scores[i] - minScore) / range) * (size.height - 22),
        ),
    ];

    // Baseline grid.
    final grid = Paint()
      ..color = AppColors.line.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final midX = (prev.dx + cur.dx) / 2;
      line.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.amber.withValues(alpha: 0.28),
            AppColors.amber.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.amber,
    );
    for (final p in points) {
      canvas.drawCircle(p, 3.2, Paint()..color = AppColors.amber);
      canvas.drawCircle(
        p,
        6,
        Paint()..color = AppColors.amber.withValues(alpha: 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.scores != scores;
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    final tr = context.l10n.isTr;
    final duel = record.mode == 'duel';
    final color = switch (record.outcome) {
      'win' => AppColors.green,
      'loss' => AppColors.red,
      'draw' => AppColors.muted,
      _ => AppColors.cyan,
    };
    final label = switch (record.outcome) {
      'win' => context.t('stats.win'),
      'loss' => context.t('stats.loss'),
      'draw' => context.t('stats.draw'),
      _ => context.t('stats.solo'),
    };
    final at = record.at;
    final stamp =
        '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')} '
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(
              duel ? Icons.sports_kabaddi_rounded : Icons.timer_rounded,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stamp,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  duel && record.opponent.isNotEmpty
                      ? 'vs ${record.opponent}'
                      : context.t('stats.modules'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatInt(record.score, tr: tr),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
