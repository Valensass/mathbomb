import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Tiny JSON-file persistence for player profiles and recent matches.
class Store {
  Store(this.dir);

  final Directory dir;
  late final File _playersFile = File('${dir.path}/players.json');
  late final File _matchesFile = File('${dir.path}/matches.json');

  final Map<String, Map<String, dynamic>> players = {};
  final List<Map<String, dynamic>> matches = [];

  /// Serializes all JSON writes so simultaneous hellos cannot race on the
  /// same temporary file.
  Future<void> _ioChain = Future<void>.value();

  Future<void> _serial(Future<void> Function() task) {
    final next = _ioChain.then((_) => task());
    _ioChain = next.catchError((Object e) {
      stderr.writeln('store write failed: $e');
    });
    return _ioChain;
  }

  Future<void> _writeJson(File target, Object data) async {
    final tmp = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(target.path);
    } catch (_) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> load() async {
    await dir.create(recursive: true);
    await _readPlayers();
    await _readMatches();
  }

  Future<void> _readPlayers() async {
    try {
      if (!await _playersFile.exists()) return;
      final raw = jsonDecode(await _playersFile.readAsString());
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map) players[k.toString()] = v.cast<String, dynamic>();
        });
      }
    } catch (e) {
      stderr.writeln('players.json unreadable: $e');
    }
  }

  Future<void> _readMatches() async {
    try {
      if (!await _matchesFile.exists()) return;
      final raw = jsonDecode(await _matchesFile.readAsString());
      if (raw is List) {
        matches.addAll(raw.whereType<Map>().map((e) => e.cast<String, dynamic>()));
      }
    } catch (e) {
      stderr.writeln('matches.json unreadable: $e');
    }
  }

  Future<void> upsertPlayer(Map<String, dynamic> profile) {
    final id = (profile['id'] ?? '').toString();
    if (id.isEmpty) return Future.value();
    players[id] = {
      'id': id,
      'name': (profile['name'] ?? 'OPERATIVE').toString(),
      'tag': (profile['tag'] ?? '????').toString(),
      'code': (profile['friendCode'] ?? '').toString(),
      'rating': (profile['rating'] as num?)?.toInt() ?? 1000,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    return _serial(() => _writeJson(_playersFile, players));
  }

  Future<void> recordMatch(Map<String, dynamic> record) {
    matches.insert(0, record);
    if (matches.length > 200) matches.removeRange(200, matches.length);
    return _serial(() => _writeJson(_matchesFile, matches));
  }

  Future<void> updateRating(String id, int rating) {
    final p = players[id];
    if (p == null) return Future.value();
    p['rating'] = rating;
    return _serial(() => _writeJson(_playersFile, players));
  }

  Map<String, dynamic>? byCode(String code) {
    final wanted = code.toUpperCase();
    for (final p in players.values) {
      if ((p['code'] ?? '').toString().toUpperCase() == wanted) return p;
    }
    return null;
  }

  List<Map<String, dynamic>> leaderboard({int limit = 20}) {
    final list = players.values.toList()
      ..sort(
        (a, b) => ((b['rating'] as num?)?.toInt() ?? 0)
            .compareTo((a['rating'] as num?)?.toInt() ?? 0),
      );
    return list.take(limit).toList();
  }
}

class Client {
  Client(this.ws) : connectionId = _newId();

  final WebSocketChannel ws;
  final String connectionId;

  String id = '';
  String name = 'OPERATIVE';
  String tag = '????';
  int rating = 1000;
  bool helloDone = false;
  bool inQueue = false;
  String? roomCode;
  String? matchId;
  final Set<String> friends = {};

  static int _counter = 0;
  static String _newId() => 'c${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  String get label => id.isEmpty ? connectionId : '$name#$tag';

  bool get online => helloDone && id.isNotEmpty;
}

class Room {
  Room(this.code, this.hostId);

  final String code;
  final String hostId;
  String? guestId;
}

class Match {
  Match(this.id, this.seed, this.a, this.b) {
    scores[a.id] = 0;
    scores[b.id] = 0;
  }

  static const int turnSeconds = 15;
  static const int pointsToWin = 4;
  static const int maxTurns = 20;

  final String id;
  final int seed;
  final Client a;
  final Client b;
  final Map<String, int> scores = {};
  int turnIndex = 0;
  String activeId = '';
  int? turnDeadlineMs;
  Timer? turnTimer;
  bool answeredThisTurn = false;
  bool ended = false;
}

class Hub {
  Hub(this.store);

  final Store store;
  final Map<String, Client> _clients = {};
  final Map<String, Client> _profiles = {};
  final List<Client> _queue = [];
  final Map<String, Room> _rooms = {};
  final Map<String, Match> _matches = {};
  final Random _rng = Random.secure();

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  int get onlineCount => _profiles.length;

  String get _stats =>
      '${_profiles.length} online · ${_queue.length} queued · ${_matches.length} live';

  void attach(WebSocketChannel ws) {
    final client = Client(ws);
    _clients[client.connectionId] = client;
    _send(client, {'t': 'welcome', 'online': onlineCount, 'server': 'bomb-math/1'});
    ws.stream.listen(
      (dynamic raw) => _onMessage(client, raw),
      onDone: () => _detach(client),
      onError: (Object e) {
        stderr.writeln('socket error ${client.label}: $e');
        _detach(client);
      },
      cancelOnError: false,
    );
    stdout.writeln('+ connect ${client.connectionId} ($_stats)');
  }

  void _detach(Client client) {
    _clients.remove(client.connectionId);
    if (client.id.isNotEmpty && identical(_profiles[client.id], client)) {
      _profiles.remove(client.id);
    }
    _queue.remove(client);
    client.inQueue = false;

    final code = client.roomCode;
    if (code != null) {
      final room = _rooms[code];
      if (room != null) {
        if (room.hostId == client.id) {
          _rooms.remove(code);
        } else if (room.guestId == client.id) {
          room.guestId = null;
        }
      }
      client.roomCode = null;
    }

    final matchId = client.matchId;
    if (matchId != null) {
      final match = _matches[matchId];
      if (match != null && !match.ended) {
        final other = match.a.id == client.id ? match.b : match.a;
        _endMatch(match, other.id, 'opponent_left');
      }
    }

    _broadcastPresence();
    stdout.writeln('- disconnect ${client.label} ($_stats)');
  }

  void _onMessage(Client client, dynamic raw) {
    if (raw is! String || raw.length > 8192) return;
    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      msg = decoded;
    } catch (_) {
      _error(client, 'bad_json', 'Malformed message.');
      return;
    }
    try {
      switch (msg['t']) {
        case 'hello':
          _hello(client, msg);
        case 'ping':
          _send(client, {'t': 'pong'});
        case 'queue.join':
          _joinQueue(client);
        case 'queue.cancel':
          _queue.remove(client);
          client.inQueue = false;
          _send(client, {'t': 'queued', 'state': 'idle'});
        case 'room.create':
          _createRoom(client);
        case 'room.join':
          _joinRoom(client, (msg['code'] ?? '').toString());
        case 'room.leave':
          _leaveRoom(client);
        case 'invite.send':
          _invite(client, (msg['friendId'] ?? '').toString());
        case 'invite.reply':
          _inviteReply(client, msg);
        case 'friend.lookup':
          _lookupFriend(client, (msg['code'] ?? '').toString());
        case 'match.answer':
          _answer(client, msg['correct'] == true);
        case 'match.forfeit':
          _forfeit(client);
        case 'match.emote':
          _emote(client, (msg['kind'] ?? '').toString());
        default:
          _error(client, 'unknown', 'Unknown message type.');
      }
    } catch (e, st) {
      stderr.writeln('handler error for $msg: $e\n$st');
      _error(client, 'internal', 'Server handler error.');
    }
  }

  void _hello(Client client, Map<String, dynamic> msg) {
    final profile = (msg['profile'] as Map?)?.cast<String, dynamic>();
    if (profile == null) {
      _error(client, 'bad_hello', 'Profile required.');
      return;
    }
    final id = (profile['id'] ?? '').toString();
    if (id.isEmpty) {
      _error(client, 'bad_hello', 'Profile id required.');
      return;
    }
    // Replace any previous connection for the same account.
    final previous = _profiles[id];
    if (previous != null && previous != client) {
      previous.matchId = null;
      _clients.remove(previous.connectionId);
    }
    client
      ..id = id
      ..name = (profile['name'] ?? 'OPERATIVE').toString()
      ..tag = (profile['tag'] ?? '????').toString()
      ..rating = (profile['rating'] as num?)?.toInt() ?? 1000
      ..helloDone = true;
    final friends = (msg['friends'] as List?) ?? const [];
    client.friends
      ..clear()
      ..addAll(friends.map((e) => e.toString()));
    _profiles[id] = client;
    unawaited(store.upsertPlayer(profile));
    _send(client, {'t': 'ready', 'online': onlineCount});
    _broadcastPresence();
    stdout.writeln('* hello ${client.label} ($_stats)');
  }

  void _broadcastPresence() {
    final online = _profiles.keys.toList();
    for (final c in _profiles.values) {
      _send(c, {'t': 'presence', 'online': online});
    }
  }

  void _joinQueue(Client client) {
    if (!client.online) {
      _error(client, 'not_ready', 'Send hello first.');
      return;
    }
    if (client.matchId != null || client.roomCode != null) {
      _error(client, 'busy', 'Already in a room or match.');
      return;
    }
    if (client.inQueue) return;
    client.inQueue = true;
    _queue.add(client);
    _send(client, {'t': 'queued', 'state': 'waiting'});
    _tryPair();
  }

  void _tryPair() {
    while (_queue.length >= 2) {
      final a = _queue.removeAt(0);
      final b = _queue.removeAt(0);
      if (!a.online || !b.online) continue;
      _startMatch(a, b);
    }
  }

  void _createRoom(Client client) {
    if (!client.online) {
      _error(client, 'not_ready', 'Send hello first.');
      return;
    }
    _leaveRoom(client);
    var code = _newCode();
    var guard = 0;
    while (_rooms.containsKey(code) && guard++ < 50) {
      code = _newCode();
    }
    final room = Room(code, client.id);
    _rooms[code] = room;
    client.roomCode = code;
    _send(client, {'t': 'room.created', 'code': code});
    stdout.writeln('room $code created by ${client.label}');
  }

  void _joinRoom(Client client, String code) {
    final room = _rooms[code.toUpperCase()];
    if (room == null) {
      _error(client, 'room_not_found', 'No room with that code.');
      return;
    }
    if (room.hostId == client.id) {
      _error(client, 'room_self', 'You already host this room.');
      return;
    }
    final host = _profiles[room.hostId];
    if (host == null) {
      _rooms.remove(room.code);
      _error(client, 'host_offline', 'The host is offline.');
      return;
    }
    room.guestId = client.id;
    client.roomCode = room.code;
    _rooms.remove(room.code);
    host.roomCode = null;
    client.roomCode = null;
    _startMatch(host, client);
  }

  void _leaveRoom(Client client) {
    final code = client.roomCode;
    if (code == null) return;
    final room = _rooms[code];
    if (room != null) {
      if (room.hostId == client.id) {
        _rooms.remove(code);
      } else if (room.guestId == client.id) {
        room.guestId = null;
      }
    }
    client.roomCode = null;
  }

  void _invite(Client client, String friendId) {
    if (!client.online) {
      _error(client, 'not_ready', 'Send hello first.');
      return;
    }
    final target = _profiles[friendId];
    if (target == null) {
      _error(client, 'friend_offline', 'That friend is not online.');
      return;
    }
    _createRoom(client);
    final code = client.roomCode;
    if (code == null) return;
    _send(target, {
      't': 'invite',
      'roomCode': code,
      'from': {'id': client.id, 'name': client.name, 'tag': client.tag},
    });
  }

  void _inviteReply(Client client, Map<String, dynamic> msg) {
    final roomCode = (msg['roomCode'] ?? '').toString().toUpperCase();
    final accept = msg['accept'] == true;
    final room = _rooms[roomCode];
    if (room == null) {
      _error(client, 'room_not_found', 'The invite expired.');
      return;
    }
    final host = _profiles[room.hostId];
    if (host == null) {
      _error(client, 'host_offline', 'The host is offline.');
      return;
    }
    if (!accept) {
      _rooms.remove(roomCode);
      host.roomCode = null;
      _send(host, {'t': 'invite.declined', 'by': client.name});
      return;
    }
    room.guestId = client.id;
    client.roomCode = roomCode;
    _rooms.remove(roomCode);
    host.roomCode = null;
    client.roomCode = null;
    _startMatch(host, client);
  }

  void _lookupFriend(Client client, String code) {
    if (!client.online) {
      _error(client, 'not_ready', 'Send hello first.');
      return;
    }
    final profile = store.byCode(code);
    if (profile == null || profile['id'] == client.id) {
      _error(client, 'not_found', 'No player with that code.');
      return;
    }
    final online = _profiles.containsKey(profile['id']);
    _send(client, {
      't': 'friend.added',
      'friend': {
        'id': profile['id'],
        'name': profile['name'],
        'tag': profile['tag'],
        'code': profile['code'],
        'rating': profile['rating'],
        'online': online,
      },
    });
  }

  void _startMatch(Client a, Client b) {
    final id = _newId('m');
    final seed = _rng.nextInt(1 << 31);
    final match = Match(id, seed, a, b);
    _matches[id] = match;
    a.matchId = id;
    b.matchId = id;
    a.inQueue = false;
    b.inQueue = false;
    _sendMatchStart(match, a, b);
    _sendMatchStart(match, b, a);
    _beginTurn(match);
    stdout.writeln('match $id: ${a.label} vs ${b.label} seed=$seed');
  }

  void _sendMatchStart(Match match, Client to, Client opponent) {
    _send(to, {
      't': 'match.start',
      'matchId': match.id,
      'seed': match.seed,
      'pointsToWin': Match.pointsToWin,
      'turnSeconds': Match.turnSeconds,
      'opponentId': opponent.id,
      'opponentName': opponent.name,
      'opponentTag': opponent.tag,
      'opponentRating': opponent.rating,
    });
  }

  Client _opponent(Match match, Client client) =>
      match.a.id == client.id ? match.b : match.a;

  void _beginTurn(Match match) {
    if (match.ended) return;
    if (match.turnIndex >= Match.maxTurns) {
      _finishByTurnLimit(match);
      return;
    }
    match.activeId = match.turnIndex.isEven ? match.a.id : match.b.id;
    match.answeredThisTurn = false;
    match.turnDeadlineMs =
        DateTime.now().millisecondsSinceEpoch + Match.turnSeconds * 1000;
    final payload = {
      't': 'match.turn',
      'index': match.turnIndex,
      'playerId': match.activeId,
      'deadline': match.turnDeadlineMs,
    };
    _send(match.a, payload);
    _send(match.b, payload);
    match.turnTimer?.cancel();
    final turnIndex = match.turnIndex;
    match.turnTimer = Timer(const Duration(seconds: Match.turnSeconds), () {
      if (match.ended || match.turnIndex != turnIndex) return;
      for (final c in [match.a, match.b]) {
        _send(c, {'t': 'match.timeout', 'playerId': match.activeId});
      }
      match.turnIndex++;
      _beginTurn(match);
    });
  }

  void _answer(Client client, bool correct) {
    final match = _matchFor(client);
    if (match == null || match.ended) return;
    if (match.activeId != client.id) {
      _error(client, 'not_your_turn', 'It is not your turn.');
      return;
    }
    if (match.answeredThisTurn) return;
    match.answeredThisTurn = true;
    match.turnTimer?.cancel();
    if (correct) {
      match.scores[client.id] = (match.scores[client.id] ?? 0) + 1;
    }
    for (final c in [match.a, match.b]) {
      _send(c, {'t': 'match.answer', 'playerId': client.id, 'correct': correct});
      _send(c, {'t': 'match.score', 'scores': match.scores});
    }
    if ((match.scores[client.id] ?? 0) >= Match.pointsToWin) {
      _endMatch(match, client.id, 'points');
      return;
    }
    match.turnIndex++;
    final index = match.turnIndex;
    Timer(const Duration(milliseconds: 320), () {
      if (match.ended || match.turnIndex != index) return;
      _beginTurn(match);
    });
  }

  void _forfeit(Client client) {
    final match = _matchFor(client);
    if (match == null || match.ended) return;
    _endMatch(match, _opponent(match, client).id, 'forfeit');
  }

  void _finishByTurnLimit(Match match) {
    if (match.a.id.isEmpty || match.b.id.isEmpty) {
      _endMatch(match, 'draw', 'turn_limit');
      return;
    }
    final aScore = match.scores[match.a.id] ?? 0;
    final bScore = match.scores[match.b.id] ?? 0;
    if (aScore == bScore) {
      _endMatch(match, 'draw', 'turn_limit');
    } else {
      _endMatch(match, aScore > bScore ? match.a.id : match.b.id, 'turn_limit');
    }
  }

  void _emote(Client client, String kind) {
    final match = _matchFor(client);
    if (match == null) return;
    if (!const {'gg', 'fire', 'shock'}.contains(kind)) return;
    _send(_opponent(match, client), {'t': 'match.emote', 'kind': kind});
  }

  Match? _matchFor(Client client) {
    final id = client.matchId;
    if (id == null) return null;
    return _matches[id];
  }

  void _endMatch(Match match, String winnerId, String reason) {
    if (match.ended) return;
    match.ended = true;
    match.turnTimer?.cancel();
    match.activeId = '';
    _matches.remove(match.id);
    for (final c in [match.a, match.b]) {
      c.matchId = null;
      _send(c, {
        't': 'match.end',
        'matchId': match.id,
        'winnerId': winnerId,
        'reason': reason,
      });
    }
    final aId = match.a.id;
    final bId = match.b.id;
    if (aId.isNotEmpty && bId.isNotEmpty) {
      final record = {
        'matchId': match.id,
        'at': DateTime.now().toUtc().toIso8601String(),
        'winnerId': winnerId,
        'reason': reason,
        'players': [aId, bId],
        'scores': match.scores,
      };
      unawaited(store.recordMatch(record));
    }
    stdout.writeln(
      'match ${match.id} ended: winner=$winnerId reason=$reason '
      'score=${match.scores} ($_stats)',
    );
  }

  void _error(Client client, String code, String message) {
    _send(client, {'t': 'error', 'code': code, 'message': message});
  }

  void _send(Client client, Map<String, dynamic> msg) {
    try {
      client.ws.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  String _newCode() {
    final b = StringBuffer();
    for (var i = 0; i < 6; i++) {
      b.write(_codeAlphabet[_rng.nextInt(_codeAlphabet.length)]);
    }
    return b.toString();
  }

  static String _newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}${_counter++}';
  static int _counter = 0;
}

