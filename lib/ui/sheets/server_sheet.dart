import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/l10n.dart';
import '../../services/app_state.dart';
import '../../services/multiplayer_service.dart';
import '../widgets/ui_kit.dart';

Future<void> showServerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ServerSheet(),
  );
}

class _ServerSheet extends StatefulWidget {
  const _ServerSheet();

  @override
  State<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<_ServerSheet> {
  late final TextEditingController _url;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(
      text: context.read<AppState>().settings.serverUrl,
    );
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final value = _url.text.trim();
    if (!value.startsWith('ws://') && !value.startsWith('wss://')) {
      setState(() => _error = context.t('settings.badUrl'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final net = context.read<MultiplayerService>();
    await state.updateSettings(state.settings.copyWith(serverUrl: value));
    final ok = await net.connect(url: value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = context.t('duel.offlineTitle');
    });
  }

  @override
  Widget build(BuildContext context) {
    final net = context.watch<MultiplayerService>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.panelHi,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: AppColors.line)),
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
              const Icon(Icons.dns_outlined, color: AppColors.cyan, size: 20),
              const SizedBox(width: 10),
              Text(
                context.t('settings.online'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              ChipPill(
                label: switch (net.status) {
                  NetStatus.online => context.t('settings.connected'),
                  NetStatus.connecting => 'LINKING',
                  NetStatus.offline => context.t('settings.disconnected'),
                },
                color: net.status == NetStatus.online
                    ? AppColors.green
                    : net.status == NetStatus.connecting
                    ? AppColors.amber
                    : AppColors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.t('settings.server'),
            style: hudLabel,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: context.t('settings.serverHint'),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'emulator → ws://10.0.2.2:8080/ws   ·   phone → ws://<LAN-IP>:8080/ws',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: HazardButton(
                  title: _busy
                      ? context.t('home.connecting')
                      : context.t('settings.connect'),
                  icon: Icons.link_rounded,
                  accent: AppColors.cyan,
                  onTap: _busy ? null : _connect,
                ),
              ),
              if (net.status != NetStatus.offline) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: HazardButton(
                    title: context.t('settings.disconnect'),
                    icon: Icons.link_off_rounded,
                    primary: false,
                    onTap: () =>
                        context.read<MultiplayerService>().disconnect(),
                  ),
                ),
              ],
            ],
          ),
          if (net.lastError != null && net.status == NetStatus.offline) ...[
            const SizedBox(height: 10),
            Text(
              net.lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
