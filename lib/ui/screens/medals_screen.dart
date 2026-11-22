import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/l10n.dart';
import '../../game/achievements.dart';
import '../../services/app_state.dart';
import '../widgets/arena_background.dart';
import '../widgets/ui_kit.dart';

class MedalsScreen extends StatelessWidget {
  const MedalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ctx = MedalContext(
      stats: state.stats,
      friends: state.friends.length,
      rating: state.rating,
    );
    final unlocked = state.unlockedMedals;
    final total = MedalDef.all.length;

    return Scaffold(
      body: ArenaBackground(
        reduceMotion: state.settings.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              ScreenTopBar(title: context.t('medals.title')),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: GlowCard(
                  padding: const EdgeInsets.all(14),
                  glow: AppColors.amber,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            context.tf('medals.count', {
                              'a': unlocked,
                              'b': total,
                            }),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: AppColors.amber,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: AppColors.amber,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : unlocked / total,
                          minHeight: 5,
                          backgroundColor: AppColors.line,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.05,
                      ),
                  itemCount: total,
                  itemBuilder: (context, i) {
                    final medal = MedalDef.all[i];
                    return _MedalCard(
                      medal: medal,
                      contextData: ctx,
                      unlockedAt: state.medals[medal.id],
                      onTap: () => _showMedal(context, medal, ctx, state),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMedal(
    BuildContext context,
    MedalDef medal,
    MedalContext ctx,
    AppState state,
  ) {
    final tr = context.l10n.isTr;
    final unlockedAt = state.medals[medal.id];
    showDialog<void>(
      context: context,
      builder: (ctxDialog) => AlertDialog(
        title: Row(
          children: [
            Icon(medal.icon, color: medal.color),
            const SizedBox(width: 10),
            Expanded(child: Text(medal.title(tr))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(medal.desc(tr)),
            const SizedBox(height: 14),
            Text(
              unlockedAt == null
                  ? context.t('medals.locked')
                  : '${context.t('medals.unlocked')} · '
                        '${unlockedAt.day.toString().padLeft(2, '0')}.'
                        '${unlockedAt.month.toString().padLeft(2, '0')}.'
                        '${unlockedAt.year}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: unlockedAt == null ? AppColors.muted : medal.color,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: medal.clampProgress(ctx) / medal.target,
                minHeight: 5,
                backgroundColor: AppColors.line,
                valueColor: AlwaysStoppedAnimation(medal.color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tf('medals.progress', {
                'a': medal.clampProgress(ctx),
                'b': medal.target,
              }),
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctxDialog).pop(),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );
  }
}

class _MedalCard extends StatelessWidget {
  const _MedalCard({
    required this.medal,
    required this.contextData,
    required this.unlockedAt,
    required this.onTap,
  });

  final MedalDef medal;
  final MedalContext contextData;
  final DateTime? unlockedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tr = context.l10n.isTr;
    final unlocked = unlockedAt != null;
    final progress = medal.clampProgress(contextData);
    final color = unlocked ? medal.color : AppColors.steel;
    return GlowCard(
      padding: const EdgeInsets.all(12),
      borderColor: unlocked
          ? medal.color.withValues(alpha: 0.45)
          : AppColors.line,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.13),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: medal.color.withValues(alpha: 0.18),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Icon(medal.icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(
                unlocked
                    ? Icons.verified_rounded
                    : Icons.lock_outline_rounded,
                size: 15,
                color: color.withValues(alpha: unlocked ? 1 : 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Spacer(),
          Text(
            medal.title(tr).toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: unlocked ? AppColors.text : AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            medal.desc(tr),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              height: 1.3,
              color: AppColors.muted.withValues(alpha: unlocked ? 0.95 : 0.6),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress / medal.target,
              minHeight: 3.5,
              backgroundColor: AppColors.line.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unlocked
                ? context.t('medals.unlocked')
                : context.tf('medals.progress', {
                    'a': progress,
                    'b': medal.target,
                  }),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
