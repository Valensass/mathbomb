import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/audio.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../data/models.dart';
import '../../services/app_state.dart';
import '../../services/multiplayer_service.dart';
import '../sheets/server_sheet.dart';
import '../widgets/arena_background.dart';
import '../widgets/ui_kit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final net = context.watch<MultiplayerService>();
    final s = state.settings;

    Future<void> update(AppSettings next) async {
      AudioManager.instance.playSfx('click', volume: 0.45);
      Haptics.tap();
      await state.updateSettings(next);
    }

    return Scaffold(
      body: ArenaBackground(
        reduceMotion: s.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              ScreenTopBar(title: context.t('settings.title')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                  children: [
                    SectionLabel(context.t('settings.audio')),
                    GlowCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          _ToggleRow(
                            icon: Icons.volume_up_rounded,
                            label: context.t('settings.sfx'),
                            value: s.sfx,
                            onChanged: (v) =>
                                update(state.settings.copyWith(sfx: v)),
                          ),
                          const _SoftDivider(),
                          _ToggleRow(
                            icon: Icons.music_note_rounded,
                            label: context.t('settings.music'),
                            value: s.music,
                            onChanged: (v) =>
                                update(state.settings.copyWith(music: v)),
                          ),
                          const _SoftDivider(),
                          _ToggleRow(
                            icon: Icons.vibration_rounded,
                            label: context.t('settings.haptics'),
                            value: s.haptics,
                            onChanged: (v) =>
                                update(state.settings.copyWith(haptics: v)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(context.t('settings.gameplay')),
                    GlowCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          _ToggleRow(
                            icon: Icons.motion_photos_off_rounded,
                            label: context.t('settings.reduceMotion'),
                            value: s.reduceMotion,
                            onChanged: (v) => update(
                              state.settings.copyWith(reduceMotion: v),
                            ),
                          ),
                          const _SoftDivider(),
                          _ToggleRow(
                            icon: Icons.contrast_rounded,
                            label: context.t('settings.highContrast'),
                            value: s.highContrast,
                            onChanged: (v) => update(
                              state.settings.copyWith(highContrast: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(context.t('settings.language')),
                    Row(
                      children: [
                        _LangOption(
                          label: context.t('settings.system'),
                          selected: s.language == 'system',
                          onTap: () => update(
                            state.settings.copyWith(language: 'system'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LangOption(
                          label: 'ENGLISH',
                          selected: s.language == 'en',
                          onTap: () => update(
                            state.settings.copyWith(language: 'en'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LangOption(
                          label: 'TÜRKÇE',
                          selected: s.language == 'tr',
                          onTap: () => update(
                            state.settings.copyWith(language: 'tr'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(context.t('settings.online')),
                    GlowCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                net.status == NetStatus.online
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_off_rounded,
                                size: 18,
                                color: net.status == NetStatus.online
                                    ? AppColors.green
                                    : AppColors.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  switch (net.status) {
                                    NetStatus.online =>
                                      '${context.t('settings.connected')} · ${net.onlinePlayers}',
                                    NetStatus.connecting =>
                                      context.t('home.connecting'),
                                    NetStatus.offline =>
                                      context.t('settings.disconnected'),
                                  },
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => showServerSheet(context),
                                child: Text(
                                  net.status == NetStatus.online
                                      ? context.t('settings.manage')
                                      : context.t('settings.connect'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              s.serverUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(context.t('settings.data')),
                    GlowCard(
                      padding: const EdgeInsets.all(14),
                      borderColor: AppColors.redDeep.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('settings.resetBody'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.45,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.red,
                                side: BorderSide(
                                  color: AppColors.red.withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final ok = await confirmAction(
                                  context,
                                  title: context.t('settings.reset'),
                                  body: context.t('settings.resetBody'),
                                  confirm: context.t('settings.resetConfirm'),
                                  destructive: true,
                                );
                                if (!ok) return;
                                await state.resetProgress();
                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                  ).popUntil((r) => r.isFirst);
                                }
                              },
                              icon: const Icon(Icons.delete_forever_rounded),
                              label: Text(context.t('settings.reset')),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(context.t('settings.about')),
                    GlowCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.amber,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'BOMB MATH',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tf('settings.version', {'v': '1.0.0'}),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.muted,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t('settings.credits'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.4,
                              color: AppColors.muted,
                            ),
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
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.amber,
            activeTrackColor: AppColors.amber.withValues(alpha: 0.32),
            inactiveThumbColor: AppColors.steel,
            inactiveTrackColor: AppColors.line.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 46,
      endIndent: 14,
      color: AppColors.line.withValues(alpha: 0.6),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.amber.withValues(alpha: 0.12)
                : AppColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.amber : AppColors.line,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: selected ? AppColors.amber : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
