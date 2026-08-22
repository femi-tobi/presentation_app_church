import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'settings_state.dart';
import 'performance_tracker.dart';

import 'display_manager.dart';
import 'connectors/remote_control_service.dart';
import 'bible_service.dart';

enum PresentationMode { live, rehearsal, auto, locked }

class PresentationController extends ChangeNotifier {
  static final PresentationController instance = PresentationController._internal();

  PresentationController._internal();

  List<SlideData> _slides = [];
  List<SlideSection> _sections = [];

  List<SlideData> get slides => _slides;
  List<SlideSection> get sections => _sections;

  int _liveIndex = 0;
  int _presenterIndex = 0;

  SlideData? _bibleOverlaySlide;
  SlideData? get bibleOverlaySlide => _bibleOverlaySlide;

  String _bibleOverlayTarget = 'both'; // 'both', 'obs', 'display'
  String get bibleOverlayTarget => _bibleOverlayTarget;
  set bibleOverlayTarget(String val) {
    _bibleOverlayTarget = val;
    notifyListeners();
    _broadcastState();
    _getRemoteService()?.broadcastStateChange();
  }

  String _bibleTranslation = 'kjv';
  String get bibleTranslation => _bibleTranslation;
  set bibleTranslation(String val) {
    _bibleTranslation = val;
    notifyListeners();
  }

  bool _isBibleFullscreen = false;
  bool get isBibleFullscreen => _isBibleFullscreen;
  set isBibleFullscreen(bool val) {
    _isBibleFullscreen = val;
    notifyListeners();
    _broadcastState();
    _getRemoteService()?.broadcastStateChange();
  }

  Future<void> showBibleOverlay(String title, String subtitle, {bool fullscreen = false}) async {
    _isBibleFullscreen = fullscreen;
    _bibleOverlaySlide = SlideData(
      id: 'bible_overlay_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subtitle: subtitle,
      imageUrl: '',
      bgColorValue: AppSettings.instance.bibleBgColor,
      textColorValue: AppSettings.instance.bibleTextColor,
    );
    await _writeHandoffFile();
    notifyListeners();
    _broadcastState();
    _getRemoteService()?.broadcastStateChange();
  }

  Future<void> navigateBibleVerse(bool next) async {
    if (_bibleOverlaySlide == null) return;
    final title = _bibleOverlaySlide!.title;
    
    // Parse title, e.g. "Genesis 1:1" or "1 Samuel 2:3" or "Song of Solomon 4:5"
    final regex = RegExp(r'^(.+)\s+(\d+):(\d+)$');
    final match = regex.firstMatch(title);
    if (match == null) return;

    final bookName = match.group(1)!;
    final chapterNum = int.tryParse(match.group(2)!) ?? 1;
    final verseNum = int.tryParse(match.group(3)!) ?? 1;

    final result = await BibleService.instance.getNextOrPrevVerse(
      translation: _bibleTranslation,
      bookName: bookName,
      chapterNum: chapterNum,
      verseNum: verseNum,
      next: next,
    );

    if (result != null) {
      final ref = '${result['book']} ${result['chapter']}:${result['verse']}';
      final text = result['text'] as String;
      showBibleOverlay(ref, text, fullscreen: _isBibleFullscreen);
    }
  }

  Future<void> clearBibleOverlay() async {
    _bibleOverlaySlide = null;
    await _writeHandoffFile();
    notifyListeners();
    _broadcastState();
    _getRemoteService()?.broadcastStateChange();
  }

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
  int _serverPort = 4321;
  int get serverPort => _serverPort;
  set serverPort(int val) {
    _serverPort = val;
  }

  ServerSocket? _serverSocket;
  final List<Socket> _connectedClients = [];
  Socket? _audienceClientSocket;
  bool _isAudienceProcess = false;
  bool get isAudienceProcess => _isAudienceProcess;
  int get connectedClientsCount => _connectedClients.length;
  String _currentSessionId = 'unknown';
  String get currentSessionId => _currentSessionId;
  
  String? _currentPresentationId;
  String? get currentPresentationId => _currentPresentationId;
  set currentPresentationId(String? val) {
    _currentPresentationId = val;
  }

  void setSessionId(String id) {
    _currentSessionId = id;
  }

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
      debugPrint('[PRESENTATION][session=$_currentSessionId] Initialized as AUDIENCE PROCESS. Connecting to server...');
      _connectToPresenterServer();
    } else {
      debugPrint('[PRESENTATION][session=$_currentSessionId] Initialized as PRESENTER PROCESS. Starting server...');
      _startPresenterServer();
      // Pre-spawn the audience window in the background (hidden) so it is ready instantly
      spawnAudienceWindow(startHidden: true);
    }

    // Defer notifyListeners to the next microtask so we never call it
    // during a widget build phase (which would throw markNeedsBuild assertion).
    Future.microtask(notifyListeners);
  }

  void updateSlides(List<SlideData> slidesList) {
    _slides = List.from(slidesList);
    notifyListeners();
    // Defer the heavy file write off the current synchronous call stack so the
    // UI (e.g. the Present dialog) can render its first frame before we start
    // any work. This prevents the "Not Responding" freeze on low-RAM systems.
    Future.microtask(_broadcastSlides);
  }

  Future<void> _broadcastSlides() async {
    if (_isAudienceProcess) return;
    await _writeHandoffFile();
    _broadcastReloadHandoff();
  }



  // Converts a SlideData to a full wire-format map containing background images and shapes.
  Map<String, dynamic> _slideToFullJson(SlideData s) {
    return {
      'id': s.id,
      'title': s.title,
      'subtitle': s.subtitle,
      'imageUrl': s.imageUrl,
      'opacity': s.opacity,
      'blur': s.blur,
      'isBold': s.isBold,
      'isItalic': s.isItalic,
      'alignment': s.alignment.name,
      'transition': s.transition,
      'titleFontSize': s.titleFontSize,
      'subtitleFontSize': s.subtitleFontSize,
      'logoUrl': s.logoUrl,
      'logoX': s.logoX,
      'logoY': s.logoY,
      'logoSize': s.logoSize,
      'textX': s.textX,
      'textY': s.textY,
      'bgColorValue': s.bgColorValue,
      'textColorValue': s.textColorValue,
      'sectionId': s.sectionId,
      'pptxShapes': s.pptxShapes.map((shape) => shape.toJson()).toList(),
      'pptxSlideHeightEmu': s.pptxSlideHeightEmu,
    };
  }

  Future<void> _writeHandoffFile() async {
    try {
      final path = _slidesHandoffPath;
      final liveIndexVal = _liveIndex;
      final presenterIndexVal = _presenterIndex;
      final modeVal = _mode.index;
      final isBibleFullscreenVal = _isBibleFullscreen;
      final bibleOverlayTargetVal = _bibleOverlayTarget;

      // Serialize slides in small chunks, yielding to the event loop between
      // each chunk so the UI thread can process frames and stay responsive on
      // low-RAM / low-core machines.
      const int chunkSize = 2;
      final List<Map<String, dynamic>> serializedSlides = [];
      for (int i = 0; i < _slides.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, _slides.length);
        for (int j = i; j < end; j++) {
          serializedSlides.add(_slideToFullJson(_slides[j]));
        }
        // Yield between chunks so frames can paint
        if (end < _slides.length) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      final Map<String, dynamic>? serializedBible =
          _bibleOverlaySlide != null ? _slideToFullJson(_bibleOverlaySlide!) : null;

      // Perform the heavy JSON string encoding in the background isolate
      final jsonStr = await Isolate.run(() {
        final handoff = {
          'liveIndex': liveIndexVal,
          'presenterIndex': presenterIndexVal,
          'mode': modeVal,
          'slides': serializedSlides,
          'bibleOverlay': serializedBible,
          'isBibleFullscreen': isBibleFullscreenVal,
          'bibleOverlayTarget': bibleOverlayTargetVal,
        };
        return json.encode(handoff);
      });

      await PerformanceTracker.trackAsync('Handoff write', () async {
        await File(path).writeAsString(jsonStr);
      });
      debugPrint('[PRESENTATION][session=$_currentSessionId] Handoff file written: $path (${_slides.length} slides)');
    } catch (e) {
      debugPrint('[PRESENTATION][session=$_currentSessionId] ERROR writing/serializing handoff file: $e');
    }
  }

  Future<void> _reloadFromHandoffFile() async {
    try {
      final path = _slidesHandoffPath;
      final file = File(path);
      if (await file.exists()) {
        final content = await PerformanceTracker.trackAsync('Handoff read', () async {
          return await file.readAsString();
        });
        
        final Map<String, dynamic> raw = await Isolate.run(() => json.decode(content) as Map<String, dynamic>);
        _liveIndex = (raw['liveIndex'] as num?)?.toInt() ?? _liveIndex;
        _presenterIndex = (raw['presenterIndex'] as num?)?.toInt() ?? _presenterIndex;
        _mode = PresentationMode.values[(raw['mode'] as num?)?.toInt() ?? _mode.index];
        
        final rawSlides = raw['slides'] as List<dynamic>? ?? [];
        final parsedSlides = await Isolate.run(() {
          return rawSlides
              .map((s) => SlideData.fromJson(s as Map<String, dynamic>))
              .toList();
        });
        _slides = parsedSlides;
        final bo = raw['bibleOverlay'];
        _bibleOverlaySlide = bo != null ? SlideData.fromJson(bo as Map<String, dynamic>) : null;
        _isBibleFullscreen = raw['isBibleFullscreen'] as bool? ?? false;
        _bibleOverlayTarget = raw['bibleOverlayTarget'] as String? ?? 'both';
        debugPrint('[PresentationController] Reloaded ${_slides.length} slides from handoff file');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PresentationController] ERROR reloading handoff file: $e');
    }
  }

  // --- Presenter Server Logic ---
  void _startPresenterServer() async {
    if (_serverSocket != null) {
      _broadcastSlides();
      _broadcastState();
      return;
    }
    _closePresenterServer();
    try {
      // Bind to port 0 to assign any available free port dynamically
      _serverSocket = await ServerSocket.bind('127.0.0.1', 0);
      _serverPort = _serverSocket!.port;
      debugPrint('[PresentationController] Presenter server started successfully on port $_serverPort');
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
    } catch (e) {
      debugPrint('[PresentationController] ERROR starting presenter server: $e');
    }
  }

  void _closePresenterServer() {
    final clients = List<Socket>.from(_connectedClients);
    _connectedClients.clear();
    for (final client in clients) {
      try {
        client.destroy();
      } catch (_) {}
    }
    _serverSocket?.close();
    _serverSocket = null;
  }

  void _broadcastState() {
    if (_isAudienceProcess) return; // Only parent broadcasts
    for (final client in _connectedClients) {
      _sendStateToSocket(client);
    }
  }

  void _broadcastReloadHandoff() {
    if (_isAudienceProcess) return;
    for (final client in _connectedClients) {
      try {
        final data = {
          'type': 'reload_handoff',
          'liveIndex': _liveIndex,
          'presenterIndex': _presenterIndex,
          'mode': _mode.index,
          'bibleOverlay': _bibleOverlaySlide != null ? _slideToFullJson(_bibleOverlaySlide!) : null,
          'isBibleFullscreen': _isBibleFullscreen,
          'bibleOverlayTarget': _bibleOverlayTarget,
        };
        client.write(json.encode(data) + '\n');
      } catch (_) {}
    }
  }

  void _sendHandshakeToSocket(Socket socket) {
    try {
      final data = {
        'type': 'reload_handoff',
        'liveIndex': _liveIndex,
        'presenterIndex': _presenterIndex,
        'mode': _mode.index,
        'bibleOverlay': _bibleOverlaySlide != null ? _slideToFullJson(_bibleOverlaySlide!) : null,
        'isBibleFullscreen': _isBibleFullscreen,
        'bibleOverlayTarget': _bibleOverlayTarget,
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
        'bibleOverlay': _bibleOverlaySlide != null ? _slideToFullJson(_bibleOverlaySlide!) : null,
        'isBibleFullscreen': _isBibleFullscreen,
        'bibleOverlayTarget': _bibleOverlayTarget,
      };
      socket.write(json.encode(data) + '\n');
    } catch (_) {}
  }

  void _connectToPresenterServer() async {
    _disconnectFromPresenterServer();
    try {
      debugPrint('[PresentationController] Connecting to presenter server at 127.0.0.1:$_serverPort...');
      _audienceClientSocket = await Socket.connect('127.0.0.1', _serverPort);
      debugPrint('[PresentationController] Connected successfully to presenter server!');
      utf8.decoder
          .bind(_audienceClientSocket!)
          .transform(const LineSplitter())
          .listen((line) {
        try {
          final data = json.decode(line) as Map<String, dynamic>;
          final type = data['type'] as String? ?? '';
          if (data.containsKey('bibleOverlay')) {
            final bo = data['bibleOverlay'];
            _bibleOverlaySlide = bo != null ? SlideData.fromJson(bo as Map<String, dynamic>) : null;
          }
          if (data.containsKey('isBibleFullscreen')) {
            _isBibleFullscreen = data['isBibleFullscreen'] as bool? ?? false;
          }
          if (data.containsKey('bibleOverlayTarget')) {
            _bibleOverlayTarget = data['bibleOverlayTarget'] as String? ?? 'both';
          }
          if (type == 'handshake' || type == 'slides_update') {
            final slidesList = (data['slides'] as List)
                .map((s) => SlideData.fromJson(s as Map<String, dynamic>))
                .toList();
            _slides = slidesList;
            _liveIndex = (data['liveIndex'] as num?)?.toInt() ?? _liveIndex;
            _presenterIndex = (data['presenterIndex'] as num?)?.toInt() ?? _presenterIndex;
            _mode = PresentationMode.values[(data['mode'] as num?)?.toInt() ?? _mode.index];
            notifyListeners();
          } else if (type == 'reload_handoff') {
            _reloadFromHandoffFile();
          } else if (type == 'sync' || type == 'state') {
            _liveIndex = (data['liveIndex'] as num?)?.toInt() ?? _liveIndex;
            _presenterIndex = (data['presenterIndex'] as num?)?.toInt() ?? _presenterIndex;
            _mode = PresentationMode.values[(data['mode'] as num?)?.toInt() ?? _mode.index];
            notifyListeners();
          }
        } catch (_) {}
      }, onDone: () {
        _disconnectFromPresenterServer();
        _retryConnection();
      }, onError: (err) {
        _disconnectFromPresenterServer();
        _retryConnection();
      });
    } catch (_) {
      _retryConnection();
    }
  }

  void _retryConnection() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isAudienceProcess && _audienceClientSocket == null) {
        _connectToPresenterServer();
      }
    });
  }

  void _disconnectFromPresenterServer() {
    _audienceClientSocket?.destroy();
    _audienceClientSocket = null;
  }

  Process? _audienceProcess;

  // Path used to share slide data with the spawned audience process.
  // Uses TEMP env var first (more reliable on Windows), falls back to Directory.systemTemp.
  static String get _slidesHandoffPath {
    final tmp = Platform.environment['TEMP'] ??
        Platform.environment['TMP'] ??
        Directory.systemTemp.path;
    return '$tmp\\livedeck_handoff.json';
  }

  // Spawns a completely separate borderless fullscreen native window (process)
  void spawnAudienceWindow({bool startHidden = false}) async {
    if (_isAudienceProcess) return;
    
    // Generate unique session ID for this presentation session
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _currentSessionId = sessionId;
    debugPrint('[PRESENTATION][session=$sessionId] START clicked (spawnAudienceWindow, startHidden: $startHidden)');

    if (_audienceProcess != null) {
      debugPrint('[PRESENTATION][session=$sessionId] Audience process already running (PID: ${_audienceProcess!.pid}). Requesting reload.');
      if (!startHidden) {
        setMode(PresentationMode.live);
      }
      await _writeHandoffFile();
      _broadcastReloadHandoff();
      return;
    }
    
    // ---- Write slide state to a shared temp file ----
    await _writeHandoffFile();

    // Verify file properties on disk
    final path = _slidesHandoffPath;
    final exists = File(path).existsSync();
    final size = exists ? File(path).lengthSync() : 0;
    debugPrint('[PRESENTATION][session=$sessionId] File verification before process start: path=$path, exists=$exists, size=$size bytes');

    final display = DisplayManager.instance.selectedDisplay;
    final args = ['--audience', '--port', _serverPort.toString(), '--session-id', sessionId];
    if (startHidden) {
      args.add('--hidden');
    }
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
    
    debugPrint('[PRESENTATION][session=$sessionId] Launching audience process: ${Platform.executable} with args: $args');
    Process.start(Platform.executable, args).then((process) {
      _audienceProcess = process;
      debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_PROCESS_START: PID=${process.pid}');
      
      // Pipe outputs to presenter console for debugging
      process.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('[AudienceProcess STDOUT][session=$sessionId] $data');
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('[AudienceProcess STDERR][session=$sessionId] $data');
      });

      // Handle process termination to allow spawning again if closed
      process.exitCode.then((code) {
        debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_PROCESS_EXIT: code=$code');
        _audienceProcess = null;
      });
      // Also broadcast via TCP at multiple intervals as a fallback.
      Future.delayed(const Duration(milliseconds: 1500), () => _broadcastSlides());
      Future.delayed(const Duration(milliseconds: 3000), () => _broadcastSlides());
      Future.delayed(const Duration(milliseconds: 5000), () => _broadcastSlides());
    }).catchError((err) {
      debugPrint('[PRESENTATION][session=$sessionId] ERROR spawning audience window: $err');
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
    setMode(PresentationMode.locked);
    if (_audienceProcess != null) {
      debugPrint('[PRESENTATION] Killing audience process (PID: ${_audienceProcess!.pid})');
      _audienceProcess!.kill();
      _audienceProcess = null;
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _autoplayTimer?.cancel();
    _closePresenterServer();
    _disconnectFromPresenterServer();
    if (_audienceProcess != null) {
      _audienceProcess!.kill();
      _audienceProcess = null;
    }
    super.dispose();
  }
}
