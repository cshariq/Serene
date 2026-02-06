import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef DeviceEventHandler = void Function(Map<String, dynamic> event);

class RealtimeService {
  final String wsUrl;
  WebSocketChannel? _channel;
  DeviceEventHandler? onEvent;

  RealtimeService({this.wsUrl = 'ws://localhost:8080/ws'});

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        (data) {
          try {
            final event = jsonDecode(data as String) as Map<String, dynamic>;
            onEvent?.call(event);
          } catch (_) {}
        },
        onDone: () {
          _channel = null;
        },
        onError: (_) {
          _channel = null;
        },
      );
    } catch (_) {
      _channel = null;
    }
  }

  void dispose() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
