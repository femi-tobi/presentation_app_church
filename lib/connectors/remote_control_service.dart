import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../presentation_controller.dart';
import '../settings_state.dart';
import '../display_manager.dart';

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
      // Find local IP address with network priority routing filters
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      String? bestIp;
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        // Skip virtual networks and VM loopback bridges
        if (name.contains('hyper-v') ||
            name.contains('vethernet') ||
            name.contains('virtualbox') ||
            name.contains('vmware') ||
            name.contains('docker') ||
            name.contains('wsl') ||
            name.contains('bluetooth')) {
          continue;
        }
        for (final addr in interface.addresses) {
          if (addr.isLoopback) continue;
          
          // Absolute priority: Windows Mobile Hotspot default subnet
          if (addr.address.startsWith('192.168.137.')) {
            bestIp = addr.address;
            break;
          }
          // Secondary priority: Standard local WiFi/Ethernet subnet
          if (bestIp == null || bestIp.startsWith('169.254')) {
            bestIp = addr.address;
          }
        }
        if (bestIp != null && bestIp.startsWith('192.168.137.')) {
          break; // Found preferred hotspot subnet, stop search
        }
      }
      _ipAddress = bestIp ?? '127.0.0.1';

      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      print("SERVER INITIALIZED. Listening on: ${_httpServer!.address.address}:${_httpServer!.port}");
      print("PAIRING URL: $pairingUrl");
      _isRunning = true;
      _listenHttp();
      _startUdpDiscovery();
      _registerWindowsFirewallRule();
    } catch (e) {
      print("SERVER BIND ERROR: $e. Retrying on fallback port...");
      // Retry on fallback port
      _port = 8085;
      try {
        _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        print("SERVER INITIALIZED ON FALLBACK. Listening on: ${_httpServer!.address.address}:${_httpServer!.port}");
        print("PAIRING URL: $pairingUrl");
        _isRunning = true;
        _listenHttp();
        _startUdpDiscovery();
        _registerWindowsFirewallRule();
      } catch (err) {
        print("SERVER CRITICAL BIND ERROR: $err");
      }
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
      'themeColor': AppSettings.instance.primaryColor.value.toRadixString(16),
      'isDarkMode': AppSettings.instance.isDarkMode,
      'simulateAudience': DisplayManager.instance.simulateAudience,
      'presentations': AppSettings.instance.recentPresentations.map((p) => {
        'id': p.id,
        'title': p.title,
      }).toList(),
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
      'slides': controller.slides.map((s) => {'title': s.title, 'subtitle': s.subtitle}).toList(),
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
        case 'selectPresentation':
          final pId = data['id'] as String;
          final record = AppSettings.instance.recentPresentations.firstWhere((p) => p.id == pId);
          controller.updateSlides(record.slides);
          controller.goTo(0);
          controller.setMode(PresentationMode.live);
          controller.spawnAudienceWindow();
          break;
        case 'toggleSimulate':
          final simulate = data['value'] as bool;
          DisplayManager.instance.setSimulateAudience(simulate);
          break;
      }
      broadcastStateChange();
    } catch (_) {}
  }

  String _buildWebRemoteHtml() {
    final hexColor = '#' + AppSettings.instance.primaryColor.value.toRadixString(16).substring(2);
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <title>LiveDeck Premium Remote</title>
  <style>
    :root {
      --primary-color: $hexColor;
      --surface-color: #0F1629;
      --card-color: #1D2A4C;
      --text-color: #F1F5F9;
      --muted-color: #8FA0BA;
    }
    body {
      background-color: #0A0F1D;
      color: var(--text-color);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 20px;
      user-select: none;
    }
    h1 {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
      color: var(--text-color);
      margin-bottom: 24px;
      text-align: left;
    }
    .panel {
      background-color: var(--surface-color);
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 20px;
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.25);
    }
    .panel-title {
      font-size: 14px;
      font-weight: 700;
      color: var(--muted-color);
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 16px;
      text-align: left;
    }
    .btn {
      background-color: var(--card-color);
      border: 1px solid rgba(255,255,255,0.1);
      color: var(--text-color);
      font-size: 16px;
      font-weight: 600;
      border-radius: 12px;
      padding: 16px;
      margin: 6px 0;
      width: 100%;
      box-sizing: border-box;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .btn:active {
      transform: scale(0.98);
      background-color: var(--primary-color);
      border-color: transparent;
    }
    .btn-primary {
      background: linear-gradient(135deg, var(--primary-color), #4F46E5);
      border: none;
      padding: 20px;
      font-size: 18px;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
    }
    .status {
      font-size: 12px;
      font-weight: 600;
      color: #EF4444;
      text-align: center;
      margin-top: 16px;
    }
    select {
      background-color: var(--card-color);
      color: var(--text-color);
      border: 1px solid rgba(255,255,255,0.1);
      padding: 14px;
      border-radius: 12px;
      width: 100%;
      font-size: 16px;
      margin-bottom: 12px;
      outline: none;
    }
    .slide-item {
      padding: 12px;
      margin: 8px 0;
      border-radius: 10px;
      background-color: rgba(255,255,255,0.03);
      border-left: 4px solid transparent;
      text-align: left;
      cursor: pointer;
    }
    .slide-item.active {
      background-color: rgba(255,255,255,0.08);
      border-left-color: var(--primary-color);
    }
  </style>
</head>
<body>
  <h1>LiveDeck Portal</h1>
  
  <div class="panel">
    <div class="panel-title">Presentation Select</div>
    <select id="pres-select" onchange="selectPresentation(this.value)">
      <option>Select a File...</option>
    </select>
  </div>

  <div class="panel">
    <div class="panel-title">Deck Controls</div>
    <button class="btn btn-primary" onclick="send('next')">Next Slide ➔</button>
    <button class="btn" onclick="send('prev')">Prev Slide ↵</button>
    <div class="grid">
      <button class="btn" onclick="send('blackScreen')">Black Screen</button>
      <button class="btn" onclick="send('blankScreen')">Clear text</button>
    </div>
  </div>

  <div class="panel">
    <div class="panel-title">Active Slide Deck</div>
    <div id="slide-list"></div>
  </div>

  <div class="status" id="status">Connecting...</div>

  <script>
    let ws;
    function connect() {
      ws = new WebSocket('ws://' + window.location.host + '/ws');
      ws.onopen = () => {
        document.getElementById('status').innerText = 'Connected';
        document.getElementById('status').style.color = '#10B981';
      };
      ws.onclose = () => {
        document.getElementById('status').innerText = 'Disconnected. Reconnecting...';
        document.getElementById('status').style.color = '#EF4444';
        setTimeout(connect, 2000);
      };
      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.type === 'state') {
          populateDropdown(data.presentations);
          updateSlideList(data.slides, data.liveIndex);
        } else if (data.type === 'update') {
          if (data.slides) {
            updateSlideList(data.slides, data.liveIndex);
          } else {
            setActiveSlide(data.liveIndex);
          }
        }
      };
    }
    function send(action, extra = {}) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(Object.assign({ action: action }, extra)));
      }
    }
    function populateDropdown(list) {
      const select = document.getElementById('pres-select');
      select.innerHTML = '<option>Select a File...</option>';
      list.forEach(p => {
        const opt = document.createElement('option');
        opt.value = p.id;
        opt.innerText = p.title;
        select.appendChild(opt);
      });
    }
    function selectPresentation(id) {
      if (id) send('selectPresentation', { id: id });
    }
    function updateSlideList(slides, liveIndex) {
      const list = document.getElementById('slide-list');
      list.innerHTML = '';
      slides.forEach((s, idx) => {
        const item = document.createElement('div');
        item.className = 'slide-item' + (idx === liveIndex ? ' active' : '');
        item.onclick = () => send('goTo', { index: idx });
        item.innerHTML = `<strong>Slide \${idx + 1}</strong>: \${s.title || '(No Title)'}<br/><small>\${s.subtitle}</small>`;
        list.appendChild(item);
      });
    }
    function setActiveSlide(index) {
      const items = document.querySelectorAll('.slide-item');
      items.forEach((item, idx) => {
        if (idx === index) {
          item.classList.add('active');
        } else {
          item.classList.remove('active');
        }
      });
    }
    connect();
  </script>
</body>
</html>
''';
  }

  void _registerWindowsFirewallRule() async {
    if (!Platform.isWindows) return;
    try {
      final cmd = 'netsh advfirewall firewall add rule name="LiveDeck Presentation Remote" dir=in action=allow protocol=TCP localport=$_port';
      await Process.run('powershell', ['-Command', 'Start-Process', 'cmd', '-ArgumentList', '"/c $cmd"', '-Verb', 'RunAs']);
    } catch (_) {}
  }
}
