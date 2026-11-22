import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/l10n.dart';
import '../../data/models.dart';
import '../../services/app_state.dart';
import '../../services/multiplayer_service.dart';
import '../widgets/arena_background.dart';
import '../widgets/ui_kit.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _adding = false;
  bool _waitingDialog = false;

  @override
  void initState() {
    super.initState();
    _sub = context.read<MultiplayerService>().events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> msg) {
    if (!mounted) return;
    switch (msg['t']) {
      case 'friend.added':
        final raw = msg['friend'];
        if (raw is Map) {
          final friend = FriendInfo.fromJson(
            raw.cast<String, dynamic>(),
          );
          final added = context.read<AppState>().addFriend(friend);
          if (mounted) {
            showSnack(
              context,
              added
                  ? context.t('friends.added')
                  : context.t('friends.exists'),
            );
            _codeController.clear();
            setState(() => _adding = false);
          }
        }
      case 'room.created':
        final code = (msg['code'] ?? '').toString();
        if (code.isNotEmpty && !_waitingDialog) _showWaiting(code);
      case 'error':
        if (_adding) {
          setState(() => _adding = false);
          showSnack(
            context,
            (msg['message'] ?? context.t('friends.notFound')).toString(),
          );
        }
    }
  }

  Future<void> _showWaiting(String code) async {
    _waitingDialog = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('duel.roomCode')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 34,
                letterSpacing: 6,
                fontWeight: FontWeight.w900,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 10),
            Text(context.tf('duel.roomHint', {'code': code})),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<MultiplayerService>().leaveRoom();
              Navigator.of(ctx).pop();
            },
            child: Text(context.t('duel.cancel')),
          ),
        ],
      ),
    );
    _waitingDialog = false;
  }

  void _addFriend() {
    final net = context.read<MultiplayerService>();
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    if (!net.isOnline) {
      showSnack(context, context.t('friends.offlineHint'));
      return;
    }
    final me = context.read<AppState>().profile?.friendCode;
    if (me == code) {
      showSnack(context, context.t('friends.self'));
      return;
    }
    setState(() => _adding = true);
    net.lookupFriend(code);
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _adding) setState(() => _adding = false);
    });
  }

  void _challenge(FriendInfo friend) {
    final net = context.read<MultiplayerService>();
    if (!friend.online) {
      showSnack(context, context.t('friends.offlineHint'));
      return;
    }
    net.challengeFriend(friend.id);
    showSnack(context, context.t('friends.sent'));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final net = context.watch<MultiplayerService>();
    final friends = state.friends;
    return Scaffold(
      body: ArenaBackground(
        reduceMotion: state.settings.reduceMotion,
        child: SafeArea(
          child: Column(
            children: [
              ScreenTopBar(title: context.t('friends.title')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                  children: [
                    GlowCard(
                      glow: AppColors.cyan,
                      borderColor: AppColors.cyan.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('friends.code'),
                                  style: hudLabel,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.profile?.friendCode ?? '—',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.4,
                                    color: AppColors.cyan,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final code = state.profile?.friendCode;
                              if (code == null) return;
                              await Clipboard.setData(
                                ClipboardData(text: code),
                              );
                              if (context.mounted) {
                                showSnack(
                                  context,
                                  context.t('friends.copied'),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded),
                            color: AppColors.cyan,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlowCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('friends.add'),
                            style: hudLabel,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  maxLength: 9,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 16,
                                    letterSpacing: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: context.t('friends.addHint'),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _addFriend(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.cyan,
                                    foregroundColor: const Color(0xFF001A17),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _adding ? null : _addFriend,
                                  child: _adding
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF001A17),
                                          ),
                                        )
                                      : Text(
                                          context.t('friends.addAction'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (!net.isOnline) ...[
                            const SizedBox(height: 8),
                            Text(
                              context.t('friends.offlineHint'),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(
                      '${context.t('friends.title')} · ${friends.length}',
                    ),
                    if (friends.isEmpty)
                      GlowCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 26,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 34,
                              color: AppColors.muted.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.t('friends.empty'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final friend in friends)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FriendTile(
                            friend: friend,
                            onChallenge: () => _challenge(friend),
                            onRemove: () async {
                              final remove = await confirmAction(
                                context,
                                title: context.t('friends.remove'),
                                body: friend.name,
                                confirm: context.t('friends.remove'),
                                destructive: true,
                              );
                              if (remove && context.mounted) {
                                await context
                                    .read<AppState>()
                                    .removeFriend(friend.id);
                              }
                            },
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

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.onChallenge,
    required this.onRemove,
  });

  final FriendInfo friend;
  final VoidCallback onChallenge;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hash = friend.id.hashCode.abs();
    return GlowCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AvatarBadge(
            emblem: hash % 6,
            colorIndex: hash ~/ 7 % 6,
            size: 42,
            ring: friend.online,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        friend.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: friend.online
                            ? AppColors.green
                            : AppColors.steel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '#${friend.tag} · ${friend.rating}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onChallenge,
            icon: const Icon(Icons.sports_kabaddi_rounded, size: 20),
            color: friend.online ? AppColors.cyan : AppColors.steel,
            tooltip: context.t('friends.challenge'),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: AppColors.muted,
            tooltip: context.t('friends.remove'),
          ),
        ],
      ),
    );
  }
}
