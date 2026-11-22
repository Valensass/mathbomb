import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/audio.dart';
import 'core/l10n.dart';
import 'data/models.dart';
import 'services/app_state.dart';
import 'services/multiplayer_service.dart';
import 'ui/screens/duel_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class BombMathApp extends StatefulWidget {
  const BombMathApp({super.key, required this.state});

  final AppState state;

  @override
  State<BombMathApp> createState() => _BombMathAppState();
}

class _BombMathAppState extends State<BombMathApp> {
  late final MultiplayerService _net = MultiplayerService(widget.state);
  StreamSubscription<Map<String, dynamic>>? _netSub;
  bool _showingInvite = false;
  bool _autoConnected = false;

  @override
  void initState() {
    super.initState();
    _netSub = _net.events.listen(_onServerEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
    if (widget.state.settings.music) {
      AudioManager.instance.startMusic();
    }
  }

  Future<void> _autoConnect() async {
    if (_autoConnected) return;
    _autoConnected = true;
    final url = widget.state.settings.serverUrl.trim();
    if (url.isEmpty) return;
    await _net.connect(url: url);
  }

  void _onServerEvent(Map<String, dynamic> msg) {
    if (msg['t'] == 'invite') {
      _showInvite(msg);
    } else if (msg['t'] == 'match.start') {
      _launchOnlineMatch(msg);
    }
  }

  void _showInvite(Map<String, dynamic> msg) {
    if (_showingInvite) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    _showingInvite = true;
    final from = (msg['from'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = (from['name'] ?? 'OPERATIVE').toString();
    final friendId = (from['id'] ?? '').toString();
    final roomCode = (msg['roomCode'] ?? '').toString();
    final l10n = _currentL10n(nav.context);
    showDialog<void>(
      context: nav.context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.f('friends.invite', {'name': name})),
        content: Text(l10n.t('friends.inviteBody')),
        actions: [
          TextButton(
            onPressed: () {
              _net.respondInvite(friendId, roomCode, false);
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.t('friends.decline')),
          ),
          FilledButton(
            onPressed: () {
              _net.respondInvite(friendId, roomCode, true);
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.t('friends.accept')),
          ),
        ],
      ),
    ).whenComplete(() => _showingInvite = false);
  }

  L10n _currentL10n(BuildContext context) {
    final settings = widget.state.settings;
    final sys = Localizations.localeOf(context);
    final code = settings.language == 'system'
        ? (sys.languageCode == 'tr' ? 'tr' : 'en')
        : settings.language;
    return L10n(Locale(code));
  }

  void _launchOnlineMatch(Map<String, dynamic> msg) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    final start = OnlineMatchStart.fromJson(msg);
    nav.popUntil((route) => route.isFirst);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => DuelScreen(
          config: DuelConfig.online(start),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _netSub?.cancel();
    _net.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<MultiplayerService>.value(value: _net),
      ],
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final s = state.settings;
          final locale = s.language == 'system' ? null : Locale(s.language);
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'BOMB MATH',
            theme: buildTheme(highContrast: s.highContrast),
            darkTheme: buildTheme(highContrast: s.highContrast),
            themeMode: ThemeMode.dark,
            locale: locale,
            supportedLocales: L10n.supported,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final resolved = Localizations.localeOf(context);
              final code = resolved.languageCode == 'tr' ? 'tr' : 'en';
              return L10nScope(
                l10n: L10n(Locale(code)),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const _RootGate(),
          );
        },
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return state.onboarded ? const HomeScreen() : const OnboardingScreen();
  }
}
