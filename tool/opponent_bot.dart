// Scripted online opponent for manual/automated turn-based testing.
//
// Connects to the local match server, queues, and answers on its turns.
//
// Run:  dart run tool/opponent_bot.dart [--easy] [--name VIPER]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main(List<String> args) async {
  final name = args.contains('--name')
      ? args[args.indexOf('--name') + 1]
      : 'VIPER';
  final easy = args.contains('--easy');
  final rng = Random(DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF);
  final socket = await WebSocket.connect('ws://127.0.0.1:8080/ws');
  stdout.writeln('opponent connected as $name');

  final done = Completer<void>();
  var answering = false;

  socket.listen((dynamic raw) async {
    if (raw is! String) return;
    final msg = (jsonDecode(raw) as Map).cast<String, dynamic>();
    stdout.writeln('<- ${msg['t']}');
    switch (msg['t']) {
      case 'ready':
        socket.add(jsonEncode({'t': 'queue.join'}));
        stdout.writeln('-> queue.join');
      case 'match.start':
        stdout.writeln(
          'MATCH START vs ${msg['opponentName']} (first to ${msg['pointsToWin']})',
        );
      case 'match.turn':
        final active = (msg['playerId'] ?? '').toString();
        if (active != 'p_opponent' || answering) break;
        answering = true;
        final think = easy ? 3800 : 1600 + rng.nextInt(1400);
        await Future<void>.delayed(Duration(milliseconds: think));
        final correct = rng.nextDouble() < (easy ? 0.55 : 0.85);
        socket.add(jsonEncode({'t': 'match.answer', 'correct': correct}));
        stdout.writeln('-> answer ${correct ? 'CORRECT' : 'WRONG'}');
        answering = false;
      case 'match.score':
        stdout.writeln('   score ${msg['scores']}');
      case 'match.end':
        stdout.writeln('MATCH END winner=${msg['winnerId']}');
        await socket.close();
        if (!done.isCompleted) done.complete();
      case 'error':
        stdout.writeln('   error: ${msg['message']}');
    }
  });

  socket.add(
    jsonEncode({
      't': 'hello',
      'profile': {
        'id': 'p_opponent',
        'name': name,
        'tag': 'VPR',
        'friendCode': 'BM-VIPER1',
        'rating': 1120,
      },
      'friends': <String>[],
    }),
  );

  await done.future.timeout(
    const Duration(seconds: 180),
    onTimeout: () {
      stderr.writeln('timed out');
      exit(1);
    },
  );
  stdout.writeln('opponent finished');
}
