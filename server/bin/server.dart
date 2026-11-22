import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:bomb_math_server/hub.dart';

const _cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

Response _json(Object data, {int status = 200}) =>
    Response(status, body: jsonEncode(data), headers: _cors);

Future<void> main(List<String> args) async {
  final port =
      int.tryParse(Platform.environment['PORT'] ?? '') ??
      int.tryParse(args.isNotEmpty ? args.first : '') ??
      8080;
  final dataDir = Platform.environment['DATA_DIR'] ?? 'data';

  final store = Store(Directory(dataDir));
  await store.load();
  final hub = Hub(store);

  final wsHandler = webSocketHandler(
    (WebSocketChannel ws, String? protocol) => hub.attach(ws),
    pingInterval: const Duration(seconds: 20),
  );

  Future<Response> route(Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: _cors);
    }
    final path = request.url.path;
    switch (path) {
      case 'ws':
        return wsHandler(request);
      case 'health':
        return _json({
          'ok': true,
          'service': 'bomb-math',
          'online': hub.onlineCount,
          'players': store.players.length,
          'matches': store.matches.length,
          'time': DateTime.now().toUtc().toIso8601String(),
        });
      case 'api/leaderboard':
        return _json({
          'players': store.leaderboard(limit: 20).map((p) => {
                'id': p['id'],
                'name': p['name'],
                'tag': p['tag'],
                'rating': p['rating'],
              }).toList(),
        });
      case 'api/matches':
        return _json({'matches': store.matches.take(20).toList()});
    }
    return _json({'error': 'not_found'}, status: 404);
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(route);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  server.autoCompress = true;
  stdout.writeln('BOMB MATH match server');
  stdout.writeln('  http://${server.address.address}:${server.port}');
  stdout.writeln('  ws://<host>:${server.port}/ws');
  stdout.writeln('  data: ${Directory(dataDir).absolute.path}');
  stdout.writeln('  online: ${hub.onlineCount}');
}
