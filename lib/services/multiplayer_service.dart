import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_state.dart';

enum NetStatus { offline, connecting, online }

/// WebSocket client for the local match server. Fails soft: the whole game
/// stays playable offline, with bot duels as the fallback.
class MultiplayerService extends ChangeNotifier {
  MultiplayerService(this._state);

  final AppState _state;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _ping;
  Timer? _retry;
  bool _wantOnline = false;
  int _attempt = 0;

  NetStatus status = NetStatus.offline;
  int onlinePlayers = 0;
  String? lastError;

  /// Last `match.turn` message, cached so a screen created right after
  /// `match.start` cannot miss the first turn due to subscription timing.
  Map<String, dynamic>? pendingTurn;

  bool get isOnline => status == NetStatus.online;

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<bool> connect({String? url}) async {
    final target = (url ?? _state.settings.serverUrl).trim();
    if (target.isEmpty) return false;
    _wantOnline = true;
    _attempt = 0;
    return _open(target);
  }

  Future<bool> _open(String target) async {
    await _closeSocket();
    status = NetStatus.connecting;
    lastError = null;
    notifyListeners();
    try {
      final uri = Uri.parse(target);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        throw const FormatException('Server URL must start with ws:// or wss://');
      }
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 7));
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: (Object e) {
          lastError = e.toString();
          _handleDrop();
        },
        onDone: _handleDrop,
        cancelOnError: false,
      );
      status = NetStatus.online;
      _attempt = 0;
      notifyListeners();
      _hello();
      _startPing();
      return true;
    } catch (e) {
      status = NetStatus.offline;
      lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      _scheduleRetry(target);
      return false;
    }
  }

  void _hello() {
    final p = _state.profile;
    if (p == null) return;
    _send({
      't': 'hello',
      'profile': p.toJson(),
      'friends': _state.friends.map((f) => f.id).toList(),
    });
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      msg = decoded;
    } catch (_) {
      return;
    }
    switch (msg['t']) {
      case 'welcome':
        onlinePlayers = (msg['online'] as num?)?.toInt() ?? 0;
        notifyListeners();
      case 'ready':
        onlinePlayers = (msg['online'] as num?)?.toInt() ?? onlinePlayers;
        notifyListeners();
      case 'presence':
        final ids = ((msg['online'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        onlinePlayers = ids.length;
        _state.setPresence(ids);
        notifyListeners();
      case 'queued':
        break;
      case 'match.turn':
        pendingTurn = msg;
      case 'match.start':
        pendingTurn = null;
      case 'error':
        lastError = (msg['message'] ?? 'Server error').toString();
        notifyListeners();
    }
    _events.add(msg);
  }

  void _handleDrop() {
    if (status == NetStatus.offline) return;
    status = NetStatus.offline;
    onlinePlayers = 0;
    notifyListeners();
    _ping?.cancel();
    if (_wantOnline) {
      _scheduleRetry(_state.settings.serverUrl);
    }
  }

  void _scheduleRetry(String target) {
    _retry?.cancel();
    if (!_wantOnline) return;
    _attempt = (_attempt + 1).clamp(1, 5);
    final seconds = (1 << _attempt).clamp(2, 20);
    _retry = Timer(Duration(seconds: seconds), () {
      if (_wantOnline && status != NetStatus.online) {
        _open(target);
      }
    });
  }

  void _startPing() {
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 20), (_) {
      _send({'t': 'ping'});
    });
  }

  void _send(Map<String, dynamic> msg) {
    final ch = _channel;
    if (ch == null || status != NetStatus.online) return;
    try {
      ch.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _wantOnline = false;
    _retry?.cancel();
    _ping?.cancel();
    await _closeSocket();
    status = NetStatus.offline;
    onlinePlayers = 0;
    notifyListeners();
  }

  Future<void> _closeSocket() async {
    _ping?.cancel();
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void joinQueue() => _send({'t': 'queue.join'});

  void cancelQueue() => _send({'t': 'queue.cancel'});

  void createRoom() => _send({'t': 'room.create'});

  void joinRoom(String code) =>
      _send({'t': 'room.join', 'code': code.toUpperCase()});

  void leaveRoom() => _send({'t': 'room.leave'});

  void challengeFriend(String friendId) =>
      _send({'t': 'invite.send', 'friendId': friendId});

  void respondInvite(String friendId, String roomCode, bool accept) => _send({
    't': 'invite.reply',
    'friendId': friendId,
    'roomCode': roomCode,
    'accept': accept,
  });

  void lookupFriend(String code) =>
      _send({'t': 'friend.lookup', 'code': code.toUpperCase()});

  void reportAnswer(bool correct) =>
      _send({'t': 'match.answer', 'correct': correct});

  void forfeit() => _send({'t': 'match.forfeit'});

  void sendEmote(String kind) => _send({'t': 'match.emote', 'kind': kind});

  @override
  void dispose() {
    _wantOnline = false;
    _retry?.cancel();
    _ping?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
    super.dispose();
  }
}
