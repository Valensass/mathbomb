import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/audio.dart';
import '../../core/l10n.dart';
import '../../game/achievements.dart';
import '../../services/app_state.dart';
import '../widgets/arena_background.dart';
import '../widgets/ui_kit.dart';
import 'defuse_screen.dart';
import 'duel_screen.dart';

class ResultData {
  const ResultData({
    required this.duel,
    required this.won,
    required this.draw,
    required this.newBest,
    required this.score,
    required this.modules,
    required this.correct,
    required this.wrong,
    required this.bestCombo,
    required this.fastestMs,
    required this.durationMs,
    required this.bombs,
    required this.timeLeftMs,
    required this.medals,
    required this.endReason,
    this.opponentName = '',
    this.ratingDelta = 0,
    this.newRating = 0,
    this.rematchConfig,
  });

  final bool duel;
  final bool won;
  final bool draw;
  final bool newBest;
  final int score;
  final int modules;
  final int correct;
  final int wrong;
  final int bestCombo;
  final int fastestMs;
  final int durationMs;
  final int bombs;
  final int timeLeftMs;
  final List<MedalDef> medals;
  final String endReason;
  final String opponentName;
  final int ratingDelta;
  final int newRating;
  final DuelConfig? rematchConfig;

  double get accuracy => correct + wrong == 0 ? 0 : correct / (correct + wrong);
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.data});

  final ResultData data;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    final d = widget.data;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (d.medals.isNotEmpty) {
        AudioManager.instance.playSfx('medal', volume: 0.85);
      } else if (d.duel && d.won) {
        AudioManager.instance.playSfx('win', volume: 0.85);
      } else if (d.duel && !d.draw) {
        AudioManager.instance.playSfx('lose', volume: 0.7);
      }
    });
  }

  void _home() {
    AudioManager.instance.playSfx('click', volume: 0.55);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _again() {
    AudioManager.instance.playSfx('click', volume: 0.55);
    final d = widget.data;
    if (d.duel && d.rematchConfig != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DuelScreen(config: d.rematchConfig!),
        ),
      );
    } else if (!d.duel) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DefuseScreen()),
      );
    } else {
      _home();
    }
  }

  Future<void> _copy() async {
    final d = widget.data;
    final buffer = StringBuffer()
      ..writeln('BOMB MATH — ${d.duel ? (d.won ? 'VICTORY' : d.draw ? 'DRAW' : 'DEFEAT') : 'RUN OVER'}')
      ..writeln('SCORE: ${d.score}')
      ..writeln('MODULES: ${d.modules}')
      ..writeln('ACCURACY: ${(d.accuracy * 100).round()}%')
      ..writeln('BEST COMBO: ${d.bestCombo}');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) showSnack(context, context.t('result.copied'));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final state = context.watch<AppState>();
    final tr = context.l10n.isTr;
    final title = d.duel
        ? (d.draw
              ? context.t('result.draw')
              : d.won
              ? context.t('result.victory')
              : context.t('result.defeat'))
        : context.t('result.runOver');
    final accent = d.duel
        ? (d.draw
              ? AppColors.muted
              : d.won
              ? AppColors.green
              : AppColors.red)
        : AppColors.amber;
    final icon = d.duel
        ? (d.draw
              ? Icons.handshake_rounded
              : d.won
              ? Icons.emoji_events_rounded
              : Icons.close_rounded)
        : Icons.timer_rounded;

    return Scaffold(
      body: ArenaBackground(
        danger: d.duel && !d.won && !d.draw,
        reduceMotion: state.settings.reduceMotion,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 34,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: accent, size: 40),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: accent,
                  ),
                ),
                if (d.duel && d.opponentName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${context.t('result.opponent')}: ${d.opponentName.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                if (d.newBest) ...[
                  const SizedBox(height: 12),
                  ChipPill(
                    label: context.t('result.newBest'),
                    icon: Icons.star_rounded,
                    color: AppColors.amber,
                    filled: true,
                  ),
                ],
                const SizedBox(height: 22),
                GlowCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  glow: accent,
                  borderColor: accent.withValues(alpha: 0.4),
                  child: Column(
                    children: [
                      Text(
                        context.t('result.score'),
                        style: hudLabel,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(
                          formatInt(d.score, tr: tr),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 58,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: accent,
                            shadows: [
                              Shadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (d.duel && d.ratingDelta != 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          context.tf('result.ratingDelta', {
                            'n': d.newRating,
                            'd': d.ratingDelta > 0
                                ? '+${d.ratingDelta}'
                                : '${d.ratingDelta}',
                          }),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: d.ratingDelta > 0
                                ? AppColors.green
                                : AppColors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _StatsGrid(data: d),
                if (d.medals.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionLabel(context.t('result.medal')),
                  for (final medal in d.medals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlowCard(
                        padding: const EdgeInsets.all(12),
                        borderColor: medal.color.withValues(alpha: 0.45),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: medal.color.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: medal.color.withValues(alpha: 0.55),
                                ),
                              ),
                              child: Icon(
                                medal.icon,
                                color: medal.color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    medal.title(tr).toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    medal.desc(tr),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.workspace_premium_rounded,
                              color: medal.color,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                if (!d.duel || d.rematchConfig != null) ...[
                  HazardButton(
                    title: d.duel
                        ? context.t('result.rematch')
                        : context.t('result.again'),
                    icon: Icons.replay_rounded,
                    onTap: _again,
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _MiniResultButton(
                        icon: Icons.home_rounded,
                        label: context.t('result.home'),
                        onTap: _home,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniResultButton(
                        icon: Icons.copy_rounded,
                        label: context.t('result.copy'),
                        onTap: _copy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniResultButton extends StatelessWidget {
  const _MiniResultButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(AppRadius.s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.s),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});

  final ResultData data;

  @override
  Widget build(BuildContext context) {
    final seconds = (data.durationMs / 1000).round();
    final values = <(String, String, Color)>[
      (context.t('result.modules'), '${data.modules}', AppColors.cyan),
      (
        context.t('result.accuracy'),
        '${(data.accuracy * 100).round()}%',
        AppColors.green,
      ),
      (context.t('result.combo'), '×${data.bestCombo}', AppColors.amber),
      (
        context.t('result.time'),
        context.tf('stats.time', {'s': seconds}),
        AppColors.text,
      ),
      if (!data.duel)
        (context.t('result.bombs'), '${data.bombs}', AppColors.amber),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final v in values)
              SizedBox(
                width: width,
                child: StatTile(
                  label: v.$1,
                  value: v.$2,
                  accent: v.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}
