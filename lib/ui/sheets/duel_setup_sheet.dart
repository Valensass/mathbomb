import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/audio.dart';
import '../../core/l10n.dart';
import '../../services/app_state.dart';
import '../../services/multiplayer_service.dart';
import '../screens/duel_screen.dart';
import '../widgets/ui_kit.dart';

Future<DuelConfig?> showDuelSetup(BuildContext context) {
  return showModalBottomSheet<DuelConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DuelSetupSheet(),
  );
}

enum _Phase { menu, searching, room, join, bot }

class _DuelSetupSheet extends StatefulWidget {
  const _DuelSetupSheet();

  @override
  State<_DuelSetupSheet> createState() => _DuelSetupSheetState();
}

class _DuelSetupSheetState extends State<_DuelSetupSheet> {
  _Phase _phase = _Phase.menu;
  String? _roomCode;
  String? _error;
  String _difficulty = 'normal';
  final _codeController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _matchStarted = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _difficulty = state.settings.botDifficulty;
    _sub = context.read<MultiplayerService>().events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (!_matchStarted) {
      final net = context.read<MultiplayerService>();
      net.cancelQueue();
      net.leaveRoom();
    }
    _codeController.dispose();
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> msg) {
    if (!mounted) return;
    switch (msg['t']) {
      case 'room.created':
        setState(() {
          _roomCode = (msg['code'] ?? '').toString();
          _phase = _Phase.room;
        });
      case 'match.start':
        // The app-level listener pops back to the root and pushes the duel.
        _matchStarted = true;
        if (mounted) setState(() {});
      case 'error':
        setState(() {
          _error = (msg['message'] ?? '').toString();
          if (_phase == _Phase.searching) _phase = _Phase.menu;
        });
    }
  }

  void _quickMatch() {
    final net = context.read<MultiplayerService>();
    setState(() {
      _error = null;
      if (!net.isOnline) {
        _phase = _Phase.menu;
      } else {
        _phase = _Phase.searching;
        net.joinQueue();
      }
    });
    if (!net.isOnline) {
      showSnack(context, context.t('duel.offlineTitle'));
    }
  }

  void _createRoom() {
    setState(() {
      _error = null;
      _roomCode = null;
      _phase = _Phase.room;
    });
    context.read<MultiplayerService>().createRoom();
  }

  void _joinRoom() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _error = context.t('duel.badCode'));
      return;
    }
    setState(() {
      _error = null;
      _phase = _Phase.searching;
    });
    context.read<MultiplayerService>().joinRoom(code);
  }

  void _cancel() {
    final net = context.read<MultiplayerService>();
    net.cancelQueue();
    net.leaveRoom();
    setState(() {
      _phase = _Phase.menu;
      _roomCode = null;
      _error = null;
    });
  }

  void _startBot() {
    final state = context.read<AppState>();
    state.updateSettings(state.settings.copyWith(botDifficulty: _difficulty));
    AudioManager.instance.playSfx('click', volume: 0.5);
    Navigator.of(context).pop(DuelConfig.bot(difficulty: _difficulty));
  }

  @override
  Widget build(BuildContext context) {
    final net = context.watch<MultiplayerService>();
    final online = net.isOnline;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 22 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.panelHi,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(
          top: BorderSide(color: AppColors.line),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_phase != _Phase.menu)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _phase == _Phase.bot
                      ? () => setState(() => _phase = _Phase.menu)
                      : _cancel,
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
              if (_phase != _Phase.menu) const SizedBox(width: 8),
              Text(
                _phase == _Phase.bot
                    ? context.t('duel.difficulty')
                    : _phase == _Phase.join
                    ? context.t('duel.join')
                    : _phase == _Phase.room || _phase == _Phase.searching
                    ? context.t('duel.searching').replaceAll('…', '')
                    : context.t('home.duel'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              ChipPill(
                label: online
                    ? context.tf('home.online', {'n': net.onlinePlayers})
                    : context.t('home.offline'),
                icon: Icons.circle,
                color: online ? AppColors.green : AppColors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.red),
              ),
            ),
          switch (_phase) {
            _Phase.menu => _buildMenu(online),
            _Phase.searching => _buildWaiting(context.t('duel.searching')),
            _Phase.room => _roomCode == null
                ? _buildWaiting(context.t('duel.connecting'))
                : _buildRoomCode(_roomCode!),
            _Phase.join => _buildJoin(),
            _Phase.bot => _buildBot(),
          },
        ],
      ),
    );
  }

  Widget _buildMenu(bool online) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!online)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlowCard(
              padding: const EdgeInsets.all(14),
              borderColor: AppColors.redDeep.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 17,
                        color: AppColors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.t('duel.offlineTitle'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: AppColors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t('duel.offlineBody'),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        HazardButton(
          title: context.t('duel.quick'),
          subtitle: online
              ? context.t('duel.quickSub')
              : context.t('home.offline'),
          icon: Icons.flash_on_rounded,
          accent: AppColors.cyan,
          onTap: online ? _quickMatch : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MenuTile(
                icon: Icons.add_circle_outline_rounded,
                title: context.t('duel.create'),
                subtitle: context.t('duel.createSub'),
                enabled: online,
                onTap: _createRoom,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MenuTile(
                icon: Icons.login_rounded,
                title: context.t('duel.join'),
                subtitle: context.t('duel.joinSub'),
                enabled: online,
                onTap: () => setState(() {
                  _error = null;
                  _phase = _Phase.join;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.muted.withValues(alpha: 0.8),
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        HazardButton(
          title: context.t('duel.bot'),
          subtitle: context.t('duel.botSub'),
          icon: Icons.smart_toy_outlined,
          primary: false,
          accent: AppColors.amber,
          onTap: () => setState(() {
            _error = null;
            _phase = _Phase.bot;
          }),
        ),
      ],
    );
  }

  Widget _buildWaiting(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.amber,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 22),
          TextButton(
            onPressed: _cancel,
            child: Text(context.t('duel.cancel')),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCode(String code) {
    return Column(
      children: [
        Text(
          context.t('duel.roomCode'),
          style: hudLabel,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF060C11),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
          ),
          child: Text(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: AppColors.amber,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tf('duel.roomHint', {'code': code}),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9.5,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: HazardButton(
                title: context.t('friends.copy'),
                icon: Icons.copy_rounded,
                primary: false,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) {
                    showSnack(context, context.t('friends.copied'));
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: HazardButton(
                title: context.t('duel.cancel'),
                icon: Icons.close_rounded,
                primary: false,
                onTap: _cancel,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            UpperCaseTextFormatter(),
          ],
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'XXXXXX',
            hintStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 28,
              letterSpacing: 8,
              color: AppColors.muted.withValues(alpha: 0.4),
            ),
          ),
          onSubmitted: (_) => _joinRoom(),
        ),
        const SizedBox(height: 12),
        HazardButton(
          title: context.t('duel.joinAction'),
          icon: Icons.login_rounded,
          accent: AppColors.cyan,
          onTap: _joinRoom,
        ),
      ],
    );
  }

  Widget _buildBot() {
    const options = ['easy', 'normal', 'hard', 'master'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final option in options) ...[
              Expanded(
                child: _DifficultyChip(
                  label: context.t('duel.$option'),
                  selected: _difficulty == option,
                  onTap: () => setState(() => _difficulty = option),
                ),
              ),
              if (option != options.last) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 18),
        HazardButton(
          title: context.t('onboard.start'),
          icon: Icons.sports_kabaddi_rounded,
          accent: AppColors.cyan,
          onTap: _startBot,
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(13),
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: AppColors.cyan),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.25,
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

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.cyan.withValues(alpha: 0.12)
              : AppColors.panel,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppColors.cyan : AppColors.line,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: selected ? AppColors.cyan : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
