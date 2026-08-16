import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'settings_state.dart';

import 'display_manager.dart';
import 'connectors/remote_control_service.dart';

enum PresentationMode { live, rehearsal, auto, locked }

class PresentationController extends ChangeNotifier {
  static final PresentationController instance = PresentationController._internal();

  PresentationController._internal() {
    _startPresenterServer();
  }

  List<SlideData> _slides = [];
  List<SlideSection> _sections = [];

  List<SlideData> get slides => _slides;
  List<SlideSection> get sections => _sections;

  int _liveIndex = 0;
  int _presenterIndex = 0;

  int get liveIndex => _liveIndex;
  int get presenterIndex => _presenterIndex;

  PresentationMode _mode = PresentationMode.live;
  PresentationMode get mode => _mode;

  bool _isAutoplayRunning = false;
  Timer? _autoplayTimer;
  int _autoplayIntervalSeconds = 5;

  DateTime _startTime = DateTime.now();
  Duration _elapsedTime = Duration.zero;
  Timer? _elapsedTimer;

  int get autoplayIntervalSeconds => _autoplayIntervalSeconds;
  Duration get elapsedTime => _elapsedTime;

  // TCP Sync Server (Presenter) / Client (Audience) fields
  ServerSocket? _serverSocket;
  final List<Socket> _connectedClients = [];
  Socket? _audienceClientSocket;
  bool _isAudienceProcess = false;
  bool get isAudienceProcess => _isAudienceProcess;

  void initialize(List<SlideData> slidesList, List<SlideSection> sectionsList, int startIndex, {bool isAudience = false}) {
    _slides = slidesList;
    _sections = sectionsList;
    _liveIndex = startIndex;
    _presenterIndex = startIndex;
    _startTime = DateTime.now();
    _elapsedTime = Duration.zero;
    _mode = PresentationMode.live;
    _isAudienceProcess = isAudience;

    _stopAutoplayTimer();

    // Start the elapsed-time ticker only when a real presentation begins.
    _startElapsedTimeTimer();

    if (_isAudienceProcess) {
      _connectToPresenterServer();
    } else {
      _startPresenterServer();
    }

    notifyListeners();
  }

  void updateSlides(List<SlideData> slidesList) {
    _slides = List.from(slidesList);
    _broadcastSlides();
    notifyListeners();
  }

  void _broadcastSlides() {
    if (_isAudienceProcess) return;
    for (final client in _connectedClients) {
      try {
        final data = {
          'type': 'slides_update',
          'liveIndex': _liveIndex,
          'presenterIndex': _presenterIndex,
          'mode': _mode.index,
          'slides': _slides.map((s) => s.toJson()).toList(),
        };
        client.write(json.encode(data) + '\n');
      } catch (_) {}
    }
  }

  // --- Presenter Server Logic ---
  void _startPresenterServer() async {
    _closePresenterServer();
    try {
      _serverSocket = await ServerSocket.bind('127.0.0.1', 4321);
      _serverSocket!.listen((socket) {
        _connectedClients.add(socket);
        // Send initial handshake with all slides data
        _sendHandshakeToSocket(socket);

        socket.listen(
          (data) {},
          onError: (err) {
            _connectedClients.remove(socket);
            socket.destroy();
          },
          onDone: () {
            _connectedClients.remove(socket);
            socket.destroy();
          },
          cancelOnError: true,
        );
      });
    } catch (_) {
      // Server already running or port in use
    }
  }

  void _closePresenterServer() {
    for (final client in _connectedClients) {
      client.destroy();
    }
    _connectedClients.clear();
    _serverSocket?.close();
    _serverSocket = null;
  }

  void _broadcastState() {
    if (_isAudienceProcess) return; // Only parent broadcasts
    for (final client in _connectedClients) {
      _sendStateToSocket(client);
    }
  }

  void _sendHandshakeToSocket(Socket socket) {
    try {
      final data = {
        'type': 'handshake',
        'liveIndex': _liveIndex,
        'presenterIndex': _presenterIndex,
        'mode': _mode.index,
        'slides': _slides.map((s) => s.toJson()).toList(),
      };
      socket.write(json.encode(data) + '\n');
    } catch (_) {}
  }

  void _sendStateToSocket(Socket socket) {
    try {
      final data = {
        'type': 'sync',
        'liveIndex': _liveIndex,
        'presenterIndex': _presenterIndex,
        'mode': _mode.index,
      };
      socket.write(json.encode(data) + '\n');
    } catch (_) {}
  }

  // --- Audience Client Logic ---
  void _connectToPresenterServer() async {
    _disconnectFromPresenterServer();
    try {
      _audienceClientSocket = await Socket.connect('127.0.0.1', 4321);
      utf8.decoder
          .bind(_audienceClientSocket!)
          .transform(const LineSplitter())
          .listen((line) {
        try {
          final data = json.decode(line) as Map<String, dynamic>;
          if (data['type'] == 'handshake' || data['type'] == 'slides_update') {
            final slidesList = (data['slides'] as List)
                .map((s) => SlideData.fromJson(s as Map<String, dynamic>))
                .toList();
            _slides = slidesList;
          }
          _liveIndex = data['liveIndex'] as int;
          _presenterIndex = data['presenterIndex'] as int;
          _mode = PresentationMode.values[data['mode'] as int];
          notifyListeners();
        } catch (_) {}
      });
    } catch (_) {
      // Retry connection after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isAudienceProcess && _audienceClientSocket == null) {
          _connectToPresenterServer();
        }
      });
    }
  }

  void _disconnectFromPresenterServer() {
    _audienceClientSocket?.destroy();
    _audienceClientSocket = null;
  }

  Process? _audienceProcess;

  // Spawns a completely separate borderless fullscreen native window (process)
  void spawnAudienceWindow() {
    if (_isAudienceProcess) return;
    if (_audienceProcess != null) {
      // Already running, do not spawn another one
      return;
    }
    final display = DisplayManager.instance.selectedDisplay;
    final args = ['--audience'];
    if (display != null) {
      args.addAll([
        '--offset-x',
        display.dx.toInt().toString(),
        '--offset-y',
        display.dy.toInt().toString(),
        '--width',
        display.width.toString(),
        '--height',
        display.height.toString(),
      ]);
    }
    Process.start(Platform.executable, args).then((process) {
      _audienceProcess = process;
      // Handle process termination to allow spawning again if closed
      process.exitCode.then((_) {
        _audienceProcess = null;
      });
      // Force broadcast active slides to any connected clients including this newly spawned one
      Future.delayed(const Duration(milliseconds: 600), () {
        _broadcastSlides();
      });
    }).catchError((_) {
      _audienceProcess = null;
    });
  }

  void setMode(PresentationMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;

    if (_mode == PresentationMode.live) {
      _liveIndex = _presenterIndex;
    }

    if (_mode == PresentationMode.auto) {
      _startAutoplayTimer();
    } else {
      _stopAutoplayTimer();
    }

    _broadcastState();
    notifyListeners();
  }

  void setAutoplayInterval(int seconds) {
    _autoplayIntervalSeconds = seconds;
    if (_mode == PresentationMode.auto) {
      _startAutoplayTimer();
    }
    notifyListeners();
  }

  void next() {
    if (_mode == PresentationMode.locked) return;
    _goTo(_presenterIndex + 1);
  }

  void prev() {
    if (_mode == PresentationMode.locked) return;
    _goTo(_presenterIndex - 1);
  }

  void goFirst() {
    if (_mode == PresentationMode.locked) return;
    _goTo(0);
  }

  void goLast() {
    if (_mode == PresentationMode.locked) return;
    _goTo(_slides.isEmpty ? 0 : _slides.length - 1);
  }

  void goTo(int index) {
    if (_mode == PresentationMode.locked) return;
    _goTo(index);
  }

  void _goTo(int index) {
    if (index < 0 || index >= _slides.length) return;

    _presenterIndex = index;
    if (_mode != PresentationMode.rehearsal) {
      _liveIndex = index;
    }

    _broadcastState();
    try {
      // Import lazily at runtime or via simple condition to avoid circular dependency
      // Broadcast state to remote websocket clients
      final remote = _getRemoteService();
      if (remote != null) {
        remote.broadcastStateChange();
      }
    } catch (_) {}
    notifyListeners();
  }

  // Dynamic helper to fetch the RemoteControlService without circular dependencies
  dynamic _getRemoteService() {
    try {
      return RemoteControlService.instance;
    } catch (_) {
      return null;
    }
  }

  void _startElapsedTimeTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedTime = DateTime.now().difference(_startTime);
      notifyListeners();
    });
  }

  void _startAutoplayTimer() {
    _autoplayTimer?.cancel();
    _autoplayTimer = Timer.periodic(Duration(seconds: _autoplayIntervalSeconds), (_) {
      if (_presenterIndex + 1 < _slides.length) {
        next();
      } else {
        goTo(0);
      }
    });
  }

  void _stopAutoplayTimer() {
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
  }

  void closeAudienceWindow() {
    if (_audienceProcess != null) {
      _audienceProcess!.kill();
      _audienceProcess = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _autoplayTimer?.cancel();
    _closePresenterServer();
    _disconnectFromPresenterServer();
    super.dispose();
  }
}
