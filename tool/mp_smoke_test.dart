// End-to-end turn-based multiplayer smoke test.
//
// Starts the match server on a throwaway port, connects two WebSocket clients,
// matches them, plays alternating turns to 4 points, then verifies private rooms
// and forfeits.
//
// Run:  dart run tool/mp_smoke_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const port = 8099;

Future<void> main() async {
  final dataDir = Directory('build/mp_test_data');
  if (dataDir.existsSync()) dataDir.deleteSync(recursive: true);

  stdout.writeln('Starting server on $port ...');
  final server = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'bin/server.dart'],
    workingDirectory: 'server',
    environment: {
      'PORT': '$port',
      'DATA_DIR': dataDir.path,
    },
    mode: ProcessStartMode.normal,
  );
  server.stdout.transform(utf8.decoder).listen((s) => stdout.write('[srv] $s'));
  server.stderr.transform(utf8.decoder).listen((s) => stderr.write('[srv] $s'));

  try {
    await _waitHealthy();
    final a = await Client.connect('p_smoke_a', 'ALPHA', 'AAAA', 'BM-AAAAAA');
    final b = await Client.connect('p_smoke_b', 'BETA', 'BBBB', 'BM-BBBBBB');

    a.send({'t': 'queue.join'});
    b.send({'t': 'queue.join'});

    final startA = await a.waitFor('match.start');
    final startB = await b.waitFor('match.start');
    _check(startA['seed'] == startB['seed'], 'both clients got the same seed');
    _check(
      startA['opponentId'] == 'p_smoke_b',
      'A sees B as the opponent',
    );
    _check(
      startB['opponentId'] == 'p_smoke_a',
      'B sees A as the opponent',
    );
    _check(startA['pointsToWin'] == 4, 'match is first to four points');
    stdout.writeln('  match.start seed=${startA['seed']}');

    var aPoints = 0;
    var bPoints = 0;
    var turnCount = 0;

    while (aPoints < 4) {
      final turnA = await a.waitFor('match.turn');
      final turnB = await b.waitFor('match.turn');
      _check(
        turnA['index'] == turnB['index'],
        'both clients see the same turn index ${turnA['index']}',
      );
      final active = turnA['playerId'].toString();
      _check(
        active == turnB['playerId'].toString(),
        'both clients agree on the active player',
      );
      _check(
        turnA['deadline'] is num,
        'turn carries a server deadline',
      );
      turnCount++;

      if (turnCount == 1) {
        a.send({'t': 'match.emote', 'kind': 'fire'});
        final emote = await b.waitFor('match.emote');
        _check(emote['kind'] == 'fire', 'emote relayed');
      }

      if (active == 'p_smoke_a') {
        a.send({'t': 'match.answer', 'correct': true});
        aPoints++;
      } else {
        b.send({'t': 'match.answer', 'correct': false});
      }

      final scoreA = await a.waitFor('match.score');
      final scoreB = await b.waitFor('match.score');
      final scores = (scoreA['scores'] as Map).cast<String, dynamic>();
      final bScores = (scoreB['scores'] as Map).cast<String, dynamic>();
      _check(
        scores['p_smoke_a'] == aPoints && bScores['p_smoke_a'] == aPoints,
        'server score is A=$aPoints after turn $turnCount',
      );
      _check(
        (scores['p_smoke_b'] as num).toInt() == 0 && bPoints == 0,
        'B has no points from wrong answers',
      );
      if (aPoints >= 4) break;
    }

    final endA = await a.waitFor('match.end');
    final endB = await b.waitFor('match.end');
    _check(endA['winnerId'] == 'p_smoke_a', 'A wins 4 points');
    _check(endB['winnerId'] == 'p_smoke_a', 'B receives the same winner');
    _check(endA['reason'] == 'points', 'end reason is points');
    stdout.writeln('  turn-based match ended after $turnCount turns');

    // Private room flow + forfeit.
    a.send({'t': 'room.create'});
    final room = await a.waitFor('room.created');
    final code = room['code'].toString();
    _check(code.length == 6, 'room code has six characters');
    b.send({'t': 'room.join', 'code': code});
    final roomStartA = await a.waitFor('match.start');
    final roomStartB = await b.waitFor('match.start');
    _check(
      roomStartA['matchId'] == roomStartB['matchId'],
      'room joins the same match',
    );
    await a.waitFor('match.turn');
    await b.waitFor('match.turn');
    b.send({'t': 'match.forfeit'});
    final forfeitEnd = await a.waitFor('match.end');
    _check(
      forfeitEnd['winnerId'] == 'p_smoke_a',
      'forfeit awards the win to the opponent',
    );
    stdout.writeln('  private room $code matched and forfeited');

    await a.close();
    await b.close();
    stdout.writeln('\nTURN-BASED MULTIPLAYER SMOKE TEST PASSED');
  } finally {
    server.kill();
    await server.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        server.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}

Future<void> _waitHealthy() async {
  final client = HttpClient();
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/health'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        stdout.writeln('  server healthy: $body');
        client.close();
        return;
      }
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }
  client.close();
  throw StateError('server did not become healthy');
}

void _check(bool condition, String label) {
  if (!condition) {
    throw StateError('FAILED: $label');
  }
  stdout.writeln('  ✓ $label');
}

class Client {
  Client(this.ws, this.id);

  final WebSocket ws;
  final String id;
  final Map<String, List<Map<String, dynamic>>> _queues = {};
  final Map<String, List<Completer<Map<String, dynamic>>>> _waiters = {};

  static Future<Client> connect(
    String id,
    String name,
    String tag,
    String code,
  ) async {
    final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws');
    final client = Client(socket, id);
    socket.listen((dynamic data) {
      if (data is! String) return;
      final msg = (jsonDecode(data) as Map).cast<String, dynamic>();
      client._deliver(msg);
    });
    client.send({
      't': 'hello',
      'profile': {
        'id': id,
        'name': name,
        'tag': tag,
        'friendCode': code,
        'rating': 1000,
      },
      'friends': <String>[],
    });
    await client.waitFor('ready');
    return client;
  }

  void _deliver(Map<String, dynamic> msg) {
    final type = msg['t']?.toString() ?? '';
    final pending = _waiters[type];
    if (pending != null && pending.isNotEmpty) {
      pending.removeAt(0).complete(msg);
      return;
    }
    _queues.putIfAbsent(type, () => []).add(msg);
  }

  void send(Map<String, dynamic> msg) => ws.add(jsonEncode(msg));

  Future<Map<String, dynamic>> waitFor(
    String type, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final queued = _queues[type];
    if (queued != null && queued.isNotEmpty) {
      return Future.value(queued.removeAt(0));
    }
    final completer = Completer<Map<String, dynamic>>();
    _waiters.putIfAbsent(type, () => []).add(completer);
    return completer.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException('no "$type" message'),
    );
  }

  Future<void> close() async {
    await ws.close();
  }
}
