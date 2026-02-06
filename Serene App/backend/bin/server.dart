import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

void main(List<String> args) async {
  final app = Router();

  String? issuedToken;
  Map<String, String> profile = {
    'name': 'Serene User',
    'email': 'user@example.com',
  };
  final devices = <Map<String, dynamic>>[]; // in-memory devices

  app.post('/auth/login', (Request req) async {
    final body = await req.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final email = (data['email'] as String?)?.trim() ?? '';
    final password = data['password'] as String?;
    if (email.isEmpty || (password?.isEmpty ?? true)) {
      return Response(400, body: jsonEncode({'error': 'invalid_credentials'}));
    }
    issuedToken = 'demo-token-${DateTime.now().millisecondsSinceEpoch}';
    profile['email'] = email;
    return Response.ok(
      jsonEncode({'token': issuedToken}),
      headers: {'content-type': 'application/json'},
    );
  });

  app.get('/auth/profile', (Request req) {
    final auth = req.headers['authorization'] ?? '';
    if (!auth.startsWith('Bearer ') || issuedToken == null) {
      return Response(401);
    }
    final token = auth.substring(7);
    if (token != issuedToken) return Response(401);
    return Response.ok(
      jsonEncode(profile),
      headers: {'content-type': 'application/json'},
    );
  });

  // Devices API
  app.get('/devices', (Request req) {
    return Response.ok(
      jsonEncode({'devices': devices}),
      headers: {'content-type': 'application/json'},
    );
  });

  app.post('/devices', (Request req) async {
    final body = await req.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final id = data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    final device = {
      'id': id,
      'name': data['name'] ?? 'Device',
      'model': data['model'] ?? 'Unknown',
      'vehicleId': data['vehicleId'] ?? 'global',
      'status': data['status'] ?? 'Disconnected',
      'batteryLevel': data['batteryLevel'] ?? 1.0,
      'isConnected': data['isConnected'] ?? false,
    };
    devices.removeWhere((d) => d['id'] == id);
    devices.add(device);
    _broadcast({'type': 'device_registered', 'device': device});
    return Response.ok(
      jsonEncode(device),
      headers: {'content-type': 'application/json'},
    );
  });

  app.patch('/devices/<id>', (Request req, String id) async {
    final body = await req.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final index = devices.indexWhere((d) => d['id'] == id);
    if (index == -1) return Response(404);
    devices[index].addAll(data);
    _broadcast({'type': 'device_updated', 'device': devices[index]});
    return Response.ok(
      jsonEncode(devices[index]),
      headers: {'content-type': 'application/json'},
    );
  });

  // WebSocket realtime updates
  final wsHandler = webSocketHandler((webSocket) {
    _sockets.add(webSocket);
    webSocket.add(jsonEncode({'type': 'hello', 'devices': devices}));
    webSocket.done.then((_) => _sockets.remove(webSocket));
  });
  app.get('/ws', (Request req) => wsHandler(req));

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(app.call);

  final port = 8080;
  await io.serve(handler, '0.0.0.0', port);
  print('Backend listening on http://localhost:$port');
}

final _sockets = <dynamic>[]; // WebSocket sinks
void _broadcast(Map<String, dynamic> message) {
  final data = jsonEncode(message);
  for (final s in List.of(_sockets)) {
    try {
      s.add(data);
    } catch (_) {}
  }
}
