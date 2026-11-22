import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/audio.dart';
import '../../core/l10n.dart';
import '../../services/app_state.dart';
import '../../services/multiplayer_service.dart';
import '../sheets/duel_setup_sheet.dart';
import '../sheets/server_sheet.dart';
import '../widgets/arena_background.dart';
import '../widgets/ui_kit.dart';
import 'defuse_screen.dart';
import 'duel_screen.dart';
import 'friends_screen.dart';
import 'how_to_play_screen.dart';
import 'medals_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    AudioManager.instance.playSfx('click', volume: 0.5);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final net = context.watch<MultiplayerService>();
    final profile = state.profile;
    final l10n = context.l10n;

    return Scaffold(
      body: ArenaBackground(
        reduceMotion: state.settings.reduceMotion,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: box.maxWidth - 36,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AvatarBadge(
                            emblem: profile?.emblem ?? 0,
                            colorIndex: profile?.colorIndex ?? 0,
                            size: 46,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.name.toUpperCase() ?? 'OPERATIVE',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      '#${profile?.tag ?? 'BM'}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10.5,
                                        color: AppColors.muted,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ChipPill(
                                      label: '${state.rating}',
                                      icon: Icons.military_tech_rounded,
                                      color: AppColors.amber,
                                      filled: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _RoundIcon(
                            icon: Icons.settings_outlined,
                            onTap: () => _push(context, const SettingsScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      // Logo block.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tf('home.ready', {
                                    'name': profile?.name ?? 'OPERATIVE',
                                  }).toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 44,
                                      height: 0.96,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -2,
                                      color: AppColors.text,
                                    ),
                                    children: [
                                      const TextSpan(text: 'BOMB\n'),
                                      TextSpan(
                                        text: 'MATH',
                                        style: TextStyle(
                                          color: AppColors.amber,
                                          shadows: [
                                            Shadow(
                                              color: AppColors.amber.withValues(
                                                alpha: 0.55,
                                              ),
                                              blurRadius: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 66,
                            height: 66,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.panel,
                              border: Border.all(
                                color: AppColors.amber.withValues(alpha: 0.4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.amber.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.amber,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t('app.tagline'),
                        style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 2.6,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GlowCard(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.t('home.bestLabel'),
                                    style: hudLabel,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatInt(
                                      state.stats.bestScore,
                                      tr: l10n.isTr,
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.amber,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GlowCard(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.t('home.medals').toUpperCase(),
                                    style: hudLabel,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${state.unlockedMedals}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 23,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.cyan,
                                          height: 1,
                                        ),
                                      ),
                                      Text(
                                        '/18',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.muted.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      HazardButton(
                        title: context.t('home.solo'),
                        subtitle: context.t('home.soloSub'),
                        icon: Icons.timer_rounded,
                        accent: AppColors.amber,
                        trailing: const Icon(
                          Icons.play_arrow_rounded,
                          size: 30,
                          color: Color(0xFF1A1200),
                        ),
                        onTap: () => _push(context, const DefuseScreen()),
                      ),
                      const SizedBox(height: 10),
                      HazardButton(
                        title: context.t('home.duel'),
                        subtitle: context.t('home.duelSub'),
                        icon: Icons.sports_kabaddi_rounded,
                        accent: AppColors.cyan,
                        primary: false,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusDot(status: net.status),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                        onTap: () async {
                          AudioManager.instance.playSfx('click', volume: 0.5);
                          final config = await showDuelSetup(context);
                          if (config != null && context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DuelScreen(config: config),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _NavTile(
                            icon: Icons.insights_rounded,
                            label: context.t('home.stats'),
                            color: AppColors.cyan,
                            onTap: () => _push(context, const StatsScreen()),
                          ),
                          const SizedBox(width: 8),
                          _NavTile(
                            icon: Icons.military_tech_rounded,
                            label: context.t('home.medals'),
                            color: AppColors.amber,
                            onTap: () => _push(context, const MedalsScreen()),
                          ),
                          const SizedBox(width: 8),
                          _NavTile(
                            icon: Icons.group_rounded,
                            label: context.t('home.friends'),
                            color: AppColors.green,
                            onTap: () => _push(context, const FriendsScreen()),
                          ),
                          const SizedBox(width: 8),
                          _NavTile(
                            icon: Icons.menu_book_rounded,
                            label: context.t('home.howto'),
                            color: AppColors.muted,
                            onTap: () =>
                                _push(context, const HowToPlayScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => showServerSheet(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              _StatusDot(status: net.status),
                              const SizedBox(width: 8),
                              Text(
                                net.status == NetStatus.online
                                    ? context.tf('home.online', {
                                        'n': net.onlinePlayers,
                                      }).toUpperCase()
                                    : net.status == NetStatus.connecting
                                    ? context.t('home.connecting')
                                    : context.t('home.offline'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                  color: net.status == NetStatus.online
                                      ? AppColors.green
                                      : AppColors.muted,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                context.t('home.server'),
                                style: const TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.dns_outlined,
                                size: 13,
                                color: AppColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (state.stats.currentStreak > 0) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: ChipPill(
                            label:
                                '${context.t('home.streak')} · ${state.stats.currentStreak}',
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.amber,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: AppColors.text),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 5),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final NetStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      NetStatus.online => AppColors.green,
      NetStatus.connecting => AppColors.amber,
      NetStatus.offline => AppColors.redDeep,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
        ],
      ),
    );
  }
}
