import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../presentation_controller.dart';
import '../settings_state.dart';

class RemoteControlService {
  static final RemoteControlService instance = RemoteControlService._internal();
  RemoteControlService._internal();

  HttpServer? _httpServer;
  final List<WebSocket> _webSockets = [];
  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;
  int _port = 8080;
  bool _isRunning = false;
  String _ipAddress = '127.0.0.1';

  bool get isRunning => _isRunning;
  String get ipAddress => _ipAddress;
  int get port => _port;
  String get pairingUrl => 'http://$_ipAddress:$_port';

  Future<void> start() async {
    if (_isRunning) return;
    try {
      // Find local IP address
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            _ipAddress = addr.address;
            break;
          }
        }
      }

      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;
      _listenHttp();
      _startUdpDiscovery();
    } catch (_) {
      // Retry on fallback port
      _port = 8085;
      try {
        _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        _isRunning = true;
        _listenHttp();
        _startUdpDiscovery();
      } catch (__) {}
    }
  }

  void stop() {
    _beaconTimer?.cancel();
    _udpSocket?.close();
    for (final ws in _webSockets) {
      ws.close();
    }
    _webSockets.clear();
    _httpServer?.close(force: true);
    _httpServer = null;
    _isRunning = false;
  }

  void _listenHttp() async {
    _httpServer?.listen((HttpRequest request) async {
      if (request.uri.path == '/ws') {
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          _webSockets.add(socket);
          _sendInitState(socket);
          socket.listen(
            (message) => _handleWsMessage(message),
            onDone: () => _webSockets.remove(socket),
            onError: (_) => _webSockets.remove(socket),
          );
        } catch (_) {}
      } else {
        // Serve a responsive remote webapp
        request.response
          ..headers.contentType = ContentType.html
          ..write(_buildWebRemoteHtml())
          ..close();
      }
    });
  }

  void _startUdpDiscovery() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8888);
      _udpSocket!.broadcastEnabled = true;
      _beaconTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        final beaconData = json.encode({
          'type': 'presentation_remote_discovery',
          'url': pairingUrl,
          'ip': _ipAddress,
          'port': _port,
        });
        try {
          _udpSocket!.send(utf8.encode(beaconData), InternetAddress('255.255.255.255'), 8888);
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _sendInitState(WebSocket ws) {
    final controller = PresentationController.instance;
    final state = {
      'type': 'state',
      'liveIndex': controller.liveIndex,
      'slidesCount': controller.slides.length,
      'slides': controller.slides.map((s) => {'title': s.title, 'subtitle': s.subtitle}).toList(),
      'mode': controller.mode.name,
    };
    ws.add(json.encode(state));
  }

  void broadcastStateChange() {
    final controller = PresentationController.instance;
    final state = {
      'type': 'update',
      'liveIndex': controller.liveIndex,
      'slidesCount': controller.slides.length,
      'mode': controller.mode.name,
    };
    final raw = json.encode(state);
    for (final ws in _webSockets) {
      try {
        ws.add(raw);
      } catch (_) {}
    }
  }

  void _handleWsMessage(dynamic message) {
    try {
      final data = json.decode(message.toString()) as Map<String, dynamic>;
      final action = data['action'] as String;
      final controller = PresentationController.instance;

      switch (action) {
        case 'next':
          controller.next();
          break;
        case 'prev':
          controller.prev();
          break;
        case 'goTo':
          final index = data['index'] as int;
          controller.goTo(index);
          break;
        case 'blackScreen':
          if (controller.slides.isNotEmpty) {
            final current = controller.slides[controller.liveIndex];
            current.subtitle = current.subtitle.isEmpty ? 'Black Screen' : '';
          }
          break;
        case 'blankScreen':
          if (controller.slides.isNotEmpty) {
            final current = controller.slides[controller.liveIndex];
            current.title = '';
            current.subtitle = '';
          }
          break;
      }
      broadcastStateChange();
    } catch (_) {}
  }

  String _buildWebRemoteHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <title>LiveDeck Presentation Remote</title>
  <style>
    body {
      background-color: #0F0F1A;
      color: #E2E8F0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 16px;
      text-align: center;
      user-select: none;
    }
    h1 {
      font-size: 20px;
      color: #A78BFA;
      margin-bottom: 24px;
    }
    .btn {
      background-color: #1E1E38;
      border: 1px solid #3B3B5E;
      color: white;
      font-size: 18px;
      font-weight: bold;
      border-radius: 12px;
      padding: 20px;
      margin: 8px 0;
      width: 100%;
      box-sizing: border-box;
      touch-action: manipulation;
    }
    .btn:active {
      background-color: #312E81;
      border-color: #6366F1;
    }
    .btn-primary {
      background: linear-gradient(135deg, #7C3AED, #4F46E5);
      border: none;
      padding: 24px;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 24px;
    }
    .status {
      font-size: 12px;
      color: #64748B;
      margin-top: 16px;
    }
  </style>
</head>
<body>
  <h1>LiveDeck Remote</h1>
  
  <button class="btn btn-primary" onclick="send('next')">Next Slide ➔</button>
  <button class="btn" onclick="send('prev')">Prev Slide ↵</button>

  <div class="grid">
    <button class="btn" onclick="send('blackScreen')">Black Screen</button>
    <button class="btn" onclick="send('blankScreen')">Clear Text</button>
  </div>

  <div class="status" id="status">Connecting to Presentation...</div>

  <script>
    let ws;
    function connect() {
      ws = new WebSocket('ws://' + window.location.host + '/ws');
      ws.onopen = () => {
        document.getElementById('status').innerText = 'Connected';
        document.getElementById('status').style.color = '#10B981';
      };
      ws.onclose = () => {
        document.getElementById('status').innerText = 'Reconnecting...';
        document.getElementById('status').style.color = '#EF4444';
        setTimeout(connect, 2000);
      };
    }
    function send(action) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action: action }));
      }
    }
    connect();
  </script>
</body>
</html>
''';
  }
}
