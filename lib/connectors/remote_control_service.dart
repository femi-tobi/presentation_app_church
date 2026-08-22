import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../presentation_controller.dart';
import '../settings_state.dart';
import '../display_manager.dart';
import '../fullscreen_presenter_page.dart';
import '../preview_page.dart';
import '../presenter_view.dart';
import '../bible_service.dart';
import '../main.dart';

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
      } else if (request.uri.path == '/overlay') {
        request.response
          ..headers.contentType = ContentType.html
          ..write(_buildOverlayHtml())
          ..close();
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
      _beaconTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
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
      'slides': controller.slides.map((s) => {
        'id': s.id,
        'title': s.title,
        'subtitle': s.subtitle,
        'sectionId': s.sectionId,
        'imageUrl': s.imageUrl,
        'bgColorValue': s.bgColorValue,
        'textColorValue': s.textColorValue,
      }).toList(),
      'sections': controller.sections.map((sec) => {
        'id': sec.id,
        'name': sec.name,
        'colorValue': sec.colorValue,
        'slideIds': sec.slideIds,
      }).toList(),
      'mode': controller.mode.name,
      'themeColor': AppSettings.instance.primaryColor.value.toRadixString(16),
      'isDarkMode': AppSettings.instance.isDarkMode,
      'simulateAudience': DisplayManager.instance.simulateAudience,
      'useLowerThird': AppSettings.instance.useLowerThird,
      'usePiP': AppSettings.instance.usePiP,
      'presentations': AppSettings.instance.recentPresentations.map((p) => {
        'id': p.id,
        'title': p.title,
      }).toList(),
      'displays': DisplayManager.instance.displays.map((d) => {
        'id': d.id,
        'name': d.name,
        'isPrimary': d.isPrimary,
        'width': d.width,
        'height': d.height,
      }).toList(),
      'selectedDisplayId': DisplayManager.instance.selectedDisplay?.id,
      'bibleOverlay': (controller.bibleOverlaySlide != null && controller.bibleOverlayTarget != 'display') ? {
        'title': controller.bibleOverlaySlide!.title,
        'subtitle': controller.bibleOverlaySlide!.subtitle,
        'isFullscreen': controller.isBibleFullscreen,
      } : null,
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
      'useLowerThird': AppSettings.instance.useLowerThird,
      'usePiP': AppSettings.instance.usePiP,
      'slides': controller.slides.map((s) => {
        'id': s.id,
        'title': s.title,
        'subtitle': s.subtitle,
        'sectionId': s.sectionId,
        'imageUrl': s.imageUrl,
        'bgColorValue': s.bgColorValue,
        'textColorValue': s.textColorValue,
      }).toList(),
      'sections': controller.sections.map((sec) => {
        'id': sec.id,
        'name': sec.name,
        'colorValue': sec.colorValue,
        'slideIds': sec.slideIds,
      }).toList(),
      'displays': DisplayManager.instance.displays.map((d) => {
        'id': d.id,
        'name': d.name,
        'isPrimary': d.isPrimary,
        'width': d.width,
        'height': d.height,
      }).toList(),
      'selectedDisplayId': DisplayManager.instance.selectedDisplay?.id,
      'bibleOverlay': (controller.bibleOverlaySlide != null && controller.bibleOverlayTarget != 'display') ? {
        'title': controller.bibleOverlaySlide!.title,
        'subtitle': controller.bibleOverlaySlide!.subtitle,
        'isFullscreen': controller.isBibleFullscreen,
      } : null,
    };
    final raw = json.encode(state);
    for (final ws in _webSockets) {
      try {
        ws.add(raw);
      } catch (_) {}
    }
  }

  void _handleWsMessage(dynamic message) async {
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
          // Load slides asynchronously from disk if they are not already loaded in memory
          final slides = await AppSettings.instance.getSlidesForPresentation(pId);
          // Clone SlideData elements to prevent empty slide template generation
          final clonedSlides = slides.map((s) => SlideData.fromJson(s.toJson())).toList();
          final clonedSections = (record.sections ?? []).map((sec) => SlideSection.fromJson(sec.toJson())).toList();
          
          // Set active slide state on controller
          controller.currentPresentationId = pId;
          controller.initialize(clonedSlides, clonedSections, 0, isAudience: false);
          
          // Also set settings active variables to match main app expectations
          AppSettings.instance.updateActiveSlides(clonedSlides);
          AppSettings.instance.activeSlideIndex = 0;
          break;
        case 'selectDisplay':
          final displayId = data['displayId'] as String;
          DisplayManager.instance.selectDisplay(displayId);
          broadcastStateChange();
          break;
        case 'startPresentation':
          final activeSlides = controller.slides;
          // Ensure we have loaded a valid presentation from dropdown selection
          if (activeSlides.isNotEmpty) {
            // Synchronously populate active settings state to avoid race condition with dashboard initialization
            AppSettings.instance.updateActiveSlides(activeSlides);
            AppSettings.instance.updateActiveSections(controller.sections);
            AppSettings.instance.activeSlideIndex = 0;

            controller.setMode(PresentationMode.live);
            controller.spawnAudienceWindow();
            
            final nav = appNavigatorKey.currentState;
            if (nav != null) {
              // Try to find the selected presentation from list to get correct metadata
              final currentActiveId = controller.currentPresentationId ?? 
                  AppSettings.instance.recentPresentations.firstWhere(
                    (p) => p.slides.isNotEmpty && p.slides.first.id == activeSlides.first.id,
                    orElse: () => AppSettings.instance.recentPresentations.first,
                  ).id;
              
              // 1. First push PreviewPage matching the selected slide deck
              nav.push(PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => PreviewPage(
                  presentationId: currentActiveId,
                  initialSlides: activeSlides,
                  initialSections: controller.sections,
                ),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ));
              
              // 2. Next push the ProfessionalPresenterView (Presenter view dashboard window)
              nav.push(PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const ProfessionalPresenterView(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ));
            }
          }
          break;
        case 'searchBible':
          final query = data['query'] as String;
          final translation = data['translation'] as String? ?? 'kjv';
          final searchResults = await BibleService.instance.searchVerses(translation, query);
          
          // Send results back to the requesting client socket
          final wsMessage = {
            'type': 'searchResults',
            'results': searchResults,
          };
          for (final ws in _webSockets) {
            try {
              ws.add(json.encode(wsMessage));
            } catch (_) {}
          }
          break;
        case 'presentVerse':
          final verseText = data['text'] as String;
          final reference = data['reference'] as String;
          final fullscreen = data['fullscreen'] as bool? ?? false;
          controller.showBibleOverlay(reference, verseText, fullscreen: fullscreen);
          break;
        case 'clearBibleOverlay':
          controller.clearBibleOverlay();
          break;
        case 'nextVerse':
          controller.navigateBibleVerse(true);
          break;
        case 'prevVerse':
          controller.navigateBibleVerse(false);
          break;
        case 'endPresentation':
          // Close presenter view dialog stack on desktop app and exit fullscreen view
          final nav = appNavigatorKey.currentState;
          if (nav != null) {
            nav.popUntil((route) => route.isFirst);
          }
          controller.closeAudienceWindow();
          break;
        case 'toggleLowerThird':
          final val = data['value'] as bool;
          AppSettings.instance.useLowerThird = val;
          if (val) AppSettings.instance.usePiP = false;
          break;
        case 'togglePiP':
          final val = data['value'] as bool;
          AppSettings.instance.usePiP = val;
          if (val) AppSettings.instance.useLowerThird = false;
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
    final settings = AppSettings.instance;
    final isDark = settings.isDarkMode;
    // Theme-matched colors from SacredColors
    final bgColor = isDark ? '#0A0F1D' : '#F9F9FF';
    final surfaceColor = isDark ? '#0F1629' : '#F0F3FF';
    final cardColor = isDark ? '#16203A' : '#E7EEFE';
    final textColor = isDark ? '#F1F5F9' : '#151C27';
    final mutedColor = isDark ? '#8FA0BA' : '#4C4451';
    final outlineColor = isDark ? '#1E293B' : '#CEC3D3';
    final primaryHex = isDark ? '#DDB7FF' : '#2E0052';
    final secondaryHex = '#FED65B'; // Gold/yellow accent from secondaryContainer
    final primaryContainerHex = '#4B0082';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <title>LiveDeck Remote</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: $bgColor;
      color: $textColor;
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      padding: 20px;
      padding-bottom: 100px;
      user-select: none;
      -webkit-user-select: none;
    }
    .header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 24px;
    }
    .header-icon {
      width: 40px; height: 40px;
      background: $primaryContainerHex;
      border-radius: 12px;
      display: flex; align-items: center; justify-content: center;
      font-size: 20px;
    }
    .header h1 {
      font-size: 22px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .header small {
      font-size: 12px;
      color: $mutedColor;
      font-weight: 500;
    }
    .card {
      background: $cardColor;
      border: 1px solid $outlineColor;
      border-radius: 16px;
      padding: 20px;
      margin-bottom: 16px;
    }
    #monitor-card {
      position: sticky;
      top: 10px;
      z-index: 1000;
      background: $cardColor;
      box-shadow: 0 8px 24px rgba(0,0,0,0.4);
      border-color: $outlineColor;
    }
    .card-title {
      font-size: 11px;
      font-weight: 700;
      color: $mutedColor;
      text-transform: uppercase;
      letter-spacing: 1.2px;
      margin-bottom: 14px;
    }
    select {
      width: 100%;
      background: $surfaceColor;
      color: $textColor;
      border: 1px solid $outlineColor;
      padding: 14px 16px;
      border-radius: 12px;
      font-size: 15px;
      font-family: 'Inter', sans-serif;
      font-weight: 500;
      outline: none;
      appearance: none;
      -webkit-appearance: none;
    }
    .btn {
      display: block;
      width: 100%;
      background: $surfaceColor;
      border: 1px solid $outlineColor;
      color: $textColor;
      font-size: 15px;
      font-weight: 600;
      font-family: 'Inter', sans-serif;
      border-radius: 12px;
      padding: 16px;
      margin: 8px 0;
      cursor: pointer;
      transition: all 0.15s ease;
      text-align: center;
    }
    .btn:active {
      transform: scale(0.97);
      opacity: 0.85;
    }
    .btn-primary {
      background: $primaryContainerHex;
      color: #FFFFFF;
      border: none;
      font-size: 16px;
      padding: 18px;
    }
    .btn-gold {
      background: linear-gradient(135deg, $secondaryHex, #E9C349);
      color: #241A00;
      border: none;
      font-size: 16px;
      font-weight: 700;
      padding: 18px;
    }
    .btn-danger {
      background: transparent;
      border: 1px solid #DC2626;
      color: #DC2626;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
    }
    .grid .btn { margin: 0; }
    .slide-item {
      padding: 14px 16px;
      margin: 6px 0;
      border-radius: 12px;
      background: $surfaceColor;
      border-left: 4px solid transparent;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .slide-item.active {
      background: ${isDark ? 'rgba(221,183,255,0.1)' : 'rgba(75,0,130,0.08)'};
      border-left-color: $primaryHex;
    }
    .slide-item strong {
      font-size: 13px;
      color: $primaryHex;
    }
    .slide-item small {
      font-size: 12px;
      color: $mutedColor;
      display: block;
      margin-top: 2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .status-bar {
      position: fixed;
      bottom: 0; left: 0; right: 0;
      padding: 12px 20px;
      background: $cardColor;
      border-top: 1px solid $outlineColor;
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 12px;
      font-weight: 600;
    }
    .status-dot {
      width: 8px; height: 8px;
      border-radius: 50%;
      display: inline-block;
      margin-right: 6px;
    }
    .dot-red { background: #DC2626; }
    .dot-green { background: #10B981; }
    .empty-state {
      text-align: center;
      padding: 32px 16px;
      color: $mutedColor;
      font-size: 14px;
    }
    .preview-container {
      width: 100%;
      aspect-ratio: 16 / 9;
      background: #000;
      border-radius: 12px;
      border: 2px solid $outlineColor;
      overflow: hidden;
      position: relative;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 8px 24px rgba(0,0,0,0.5);
    }
    .preview-slide-content {
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      padding: 16px;
      text-align: center;
      box-sizing: border-box;
      background-size: cover;
      background-position: center;
      transition: all 0.3s ease;
    }
    .preview-title {
      font-size: 14px;
      font-weight: 800;
      margin-bottom: 6px;
      text-shadow: 0 2px 4px rgba(0,0,0,0.6);
    }
    .preview-subtitle {
      font-size: 10px;
      opacity: 0.85;
      text-shadow: 0 1px 2px rgba(0,0,0,0.6);
    }
    .preview-bible-overlay {
      position: absolute;
      left: 12px;
      right: 12px;
      bottom: 12px;
      background: rgba(0,0,0,0.9);
      border: 1px solid rgba(255,255,255,0.2);
      border-radius: 8px;
      padding: 8px;
      text-align: left;
      font-size: 9px;
      color: #fff;
      box-shadow: 0 4px 10px rgba(0,0,0,0.5);
    }
    .preview-bible-fullscreen {
      position: absolute;
      inset: 0;
      background: #2E0052;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      padding: 16px;
      text-align: center;
      box-sizing: border-box;
    }
    .preview-badge {
      position: absolute;
      top: 8px;
      left: 8px;
      background: rgba(220, 38, 38, 0.85);
      color: white;
      font-size: 9px;
      font-weight: 800;
      padding: 3px 6px;
      border-radius: 4px;
      display: flex;
      align-items: center;
      gap: 4px;
      z-index: 10;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .preview-badge .blink-dot {
      width: 6px;
      height: 6px;
      background: white;
      border-radius: 50%;
      animation: preview-blink 1s infinite alternate;
    }
    @keyframes preview-blink {
      from { opacity: 0.2; }
      to { opacity: 1; }
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="header-icon">🎯</div>
    <div>
      <h1>LiveDeck Remote</h1>
      <small>Presentation Control</small>
    </div>
  </div>

  <div class="card" id="monitor-card" style="padding: 12px;">
    <div class="card-title" style="margin-bottom: 8px; display: flex; align-items: center; justify-content: space-between;">
      <span>📱 Live Monitor</span>
      <span style="font-size: 8px; opacity: 0.6; text-transform: none; letter-spacing: 0;">Pinch to resize / Double-tap reset</span>
    </div>
    <div class="preview-container">
      <div id="preview-badge" class="preview-badge" style="display: none;">
        <span class="blink-dot"></span>Live
      </div>
      <div id="preview-screen" class="preview-slide-content" style="background-color: #1E1E32; color: #888;">
        <div style="font-size: 13px;">No Active Presentation</div>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="card-title">📂 Select Presentation</div>
    <select id="pres-select" onchange="selectPresentation(this.value)">
      <option value="">Choose a file...</option>
    </select>
  </div>

  <div class="card">
    <div class="card-title">📺 Select Output Display</div>
    <select id="display-select" onchange="selectDisplay(this.value)">
      <option value="">Detecting displays...</option>
    </select>
  </div>

  <div class="card" id="start-card" style="display:none;">
    <button class="btn btn-gold" onclick="send('startPresentation')">▶ Start Presentation</button>
  </div>

  <div class="card" id="end-card" style="display:none;">
    <button class="btn btn-danger" onclick="send('endPresentation')" style="background-color: #DC2626; color: white; border: none; font-size: 16px; font-weight: 700; padding: 18px;">🛑 End Presentation</button>
  </div>

  <div class="card">
    <div class="card-title">📖 Bible Search & Present</div>
    <div style="display: flex; gap: 8px; margin-bottom: 12px;">
      <input type="text" id="bible-search-input" oninput="searchBible()" placeholder="Search verse (e.g. John 3:16)" style="flex: 1; padding: 12px; border-radius: 8px; border: 1px solid $outlineColor; background: $surfaceColor; color: $textColor; outline: none; font-size: 14px;">
      <button class="btn btn-primary" onclick="searchBible()" style="margin: 0; padding: 0 16px; border-radius: 8px; font-size: 14px; width: auto;">Search</button>
    </div>
    <select id="bible-translation" style="margin-bottom: 12px; padding: 10px;">
      <option value="kjv">King James Version (KJV)</option>
      <option value="niv">New International Version (NIV)</option>
    </select>
    <div id="bible-results" style="max-height: 200px; overflow-y: auto; border: 1px solid $outlineColor; border-radius: 8px; background: $surfaceColor; display: none;"></div>
    <button class="btn btn-danger" id="dismiss-overlay-btn" onclick="send('clearBibleOverlay')" style="margin-top: 10px; display: none; background-color: #DC2626; color: white; border: none; font-size: 14px; font-weight: 700; padding: 12px; border-radius: 8px;">Dismiss Bible Overlay</button>
  </div>

  <div class="card" id="bible-nav-card" style="display: none;">
    <div class="card-title" style="color: #FED65B; margin-bottom: 8px;">📖 Active Verse Controls</div>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
      <button class="btn" style="background-color: #1E293B; color: #FED65B; border: 1px solid #FED65B; padding: 12px; font-size: 14px; margin: 0; border-radius: 8px;" onclick="send('prevVerse')">← Prev Verse</button>
      <button class="btn" style="background-color: #4B0082; color: white; border: none; padding: 12px; font-size: 14px; margin: 0; border-radius: 8px;" onclick="send('nextVerse')">Next Verse →</button>
    </div>
  </div>

  <div class="card">
    <div class="card-title">🎛️ Controls</div>
    <button class="btn btn-primary" onclick="send('next')">Next Slide →</button>
    <button class="btn" onclick="send('prev')">← Previous Slide</button>
    <div style="height:8px"></div>
    <div class="grid">
      <button class="btn btn-danger" onclick="send('blackScreen')">⬛ Black</button>
      <button class="btn" onclick="send('blankScreen')">🧹 Clear</button>
    </div>
  </div>

  <div class="card">
    <div class="card-title">📺 Stream Layouts</div>
    <div style="display: flex; flex-direction: column; gap: 12px; text-align: left;">
      <label style="display: flex; justify-content: space-between; align-items: center; cursor: pointer; font-size: 14px;">
        <span>Lower Third Overlay</span>
        <input type="checkbox" id="lt-switch" onchange="send('toggleLowerThird', {value: this.checked})" style="width: 20px; height: 20px; cursor: pointer;">
      </label>
      <label style="display: flex; justify-content: space-between; align-items: center; cursor: pointer; font-size: 14px;">
        <span>Picture-in-Picture (PiP)</span>
        <input type="checkbox" id="pip-switch" onchange="send('togglePiP', {value: this.checked})" style="width: 20px; height: 20px; cursor: pointer;">
      </label>
    </div>
  </div>

  <div class="card">
    <div class="card-title">📑 Slide Deck</div>
    <div id="slide-list">
      <div class="empty-state">Select a presentation to view slides</div>
    </div>
  </div>

  <div class="status-bar">
    <div id="status">
      <span class="status-dot dot-red"></span>
      Connecting...
    </div>
    <div style="color:$mutedColor">LiveDeck</div>
  </div>

  <script>
    let currentSections = [];
    let currentSlides = [];
    function connect() {
      ws = new WebSocket('ws://' + window.location.host + '/ws');
      ws.onopen = () => {
        document.getElementById('status').innerHTML = '<span class="status-dot dot-green"></span> Connected';
      };
      ws.onclose = () => {
        document.getElementById('status').innerHTML = '<span class="status-dot dot-red"></span> Reconnecting...';
        setTimeout(connect, 2000);
      };
      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.type === 'state') {
          populateDropdown(data.presentations || []);
          populateDisplayDropdown(data.displays || [], data.selectedDisplayId);
          currentSections = data.sections || [];
          currentSlides = data.slides || [];
          updateSlideList(currentSlides, data.liveIndex);
          updateSwitches(data.useLowerThird, data.usePiP);
          updateModeUI(data.mode);
          updateLivePreview(currentSlides, data.liveIndex, data.bibleOverlay, data.mode);
        } else if (data.type === 'update') {
          updateSwitches(data.useLowerThird, data.usePiP);
          updateModeUI(data.mode);
          if (data.displays) populateDisplayDropdown(data.displays, data.selectedDisplayId);
          if (data.sections) currentSections = data.sections;
          if (data.slides) {
            currentSlides = data.slides;
            updateSlideList(currentSlides, data.liveIndex);
          } else {
            setActiveSlide(data.liveIndex);
          }
          updateLivePreview(currentSlides, data.liveIndex, data.bibleOverlay, data.mode);
        } else if (data.type === 'searchResults') {
          displaySearchResults(data.results || []);
        }

        // Update overlay button visibility and verse controls
        const dismissBtn = document.getElementById('dismiss-overlay-btn');
        const bibleNavCard = document.getElementById('bible-nav-card');
        if (dismissBtn) {
          if (data.bibleOverlay) {
            dismissBtn.style.display = 'block';
            if (bibleNavCard) bibleNavCard.style.display = 'block';
          } else {
            dismissBtn.style.display = 'none';
            if (bibleNavCard) bibleNavCard.style.display = 'none';
          }
        }
      };
    }
    function send(action, extra = {}) {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(Object.assign({ action }, extra)));
      }
    }
    function populateDropdown(list) {
      const select = document.getElementById('pres-select');
      select.innerHTML = '<option value="">Choose a file...</option>';
      list.forEach(p => {
        const opt = document.createElement('option');
        opt.value = p.id;
        opt.innerText = p.title;
        select.appendChild(opt);
      });
    }
    function populateDisplayDropdown(displays, selectedId) {
      const select = document.getElementById('display-select');
      if (!select) return;
      select.innerHTML = '';
      displays.forEach(d => {
        const opt = document.createElement('option');
        opt.value = d.id;
        opt.innerText = d.name + (d.isPrimary ? ' (Primary)' : '') + ' [' + d.width + 'x' + d.height + ']';
        if (d.id === selectedId) opt.selected = true;
        select.appendChild(opt);
      });
    }
    function selectDisplay(displayId) {
      send('selectDisplay', { displayId });
    }
    function selectPresentation(id) {
      const startCard = document.getElementById('start-card');
      if (id) {
        send('selectPresentation', { id });
        startCard.style.display = 'block';
      } else {
        startCard.style.display = 'none';
      }
    }
    function updateSwitches(lt, pip) {
      document.getElementById('lt-switch').checked = !!lt;
      document.getElementById('pip-switch').checked = !!pip;
    }
    function updateModeUI(mode) {
      const startCard = document.getElementById('start-card');
      const endCard = document.getElementById('end-card');
      if (mode === 'live') {
        startCard.style.display = 'none';
        endCard.style.display = 'block';
      } else {
        const select = document.getElementById('pres-select');
        if (select.value) {
          startCard.style.display = 'block';
        }
        endCard.style.display = 'none';
      }
    }
    let searchTimeout;
    function searchBible() {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(() => {
        const query = document.getElementById('bible-search-input').value;
        const translation = document.getElementById('bible-translation').value;
        if (query.trim()) {
          send('searchBible', { query, translation });
        } else {
          document.getElementById('bible-results').style.display = 'none';
        }
      }, 250);
    }
    function displaySearchResults(results) {
      const container = document.getElementById('bible-results');
      container.innerHTML = '';
      if (!results.length) {
        container.innerHTML = '<div style="padding: 12px; text-align: center; color: $mutedColor; font-size: 13px;">No verses found</div>';
        container.style.display = 'block';
        return;
      }
      results.forEach(r => {
        const div = document.createElement('div');
        div.style.padding = '10px 12px';
        div.style.borderBottom = '1px solid $outlineColor';
        div.style.fontSize = '13px';
        div.style.textAlign = 'left';
        const ref = r.book + ' ' + r.chapter + ':' + r.verse;
        
        div.innerHTML = '<div style="display: flex; justify-content: space-between; align-items: center;">' +
                        '<div style="flex-grow: 1; padding-right: 10px;"><strong>' + ref + '</strong><div style="color: $mutedColor; margin-top: 2px; font-size: 12px; line-height: 1.4;">' + r.text + '</div></div>' +
                        '<div style="display: flex; gap: 6px; flex-shrink: 0;">' +
                        '<button class="btn btn-overlay" style="padding: 6px 10px; font-size: 11px; margin: 0; background-color: #10B981; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: bold;">Overlay</button>' +
                        '<button class="btn btn-fullscreen" style="padding: 6px 10px; font-size: 11px; margin: 0; background-color: #4B0082; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: bold;">Fullscreen</button>' +
                        '</div>' +
                        '</div>';
                        
        div.querySelector('.btn-overlay').onclick = () => {
          send('presentVerse', { text: r.text, reference: ref, fullscreen: false });
          document.getElementById('bible-results').style.display = 'none';
        };
        div.querySelector('.btn-fullscreen').onclick = () => {
          send('presentVerse', { text: r.text, reference: ref, fullscreen: true });
          document.getElementById('bible-results').style.display = 'none';
        };
        
        container.appendChild(div);
      });
      container.style.display = 'block';
    }
    function updateSlideList(slides, liveIndex) {
      const list = document.getElementById('slide-list');
      if (!slides.length) {
        list.innerHTML = '<div class="empty-state">Select a presentation to view slides</div>';
        return;
      }
      list.innerHTML = '';
      
      if (currentSections && currentSections.length > 0) {
        // Group slides by sections
        currentSections.forEach(sec => {
          const secSlides = slides.filter(s => sec.slideIds.includes(s.id));
          if (secSlides.length > 0) {
            // Render section header
            const header = document.createElement('div');
            header.style.fontSize = '11px';
            header.style.fontWeight = '700';
            header.style.color = '#7B41B3';
            header.style.textTransform = 'uppercase';
            header.style.letterSpacing = '1px';
            header.style.margin = '16px 0 8px 0';
            header.style.textAlign = 'left';
            header.innerText = sec.name;
            list.appendChild(header);

            secSlides.forEach(s => {
              const globalIdx = slides.findIndex(gs => gs.id === s.id);
              const item = document.createElement('div');
              item.className = 'slide-item' + (globalIdx === liveIndex ? ' active' : '');
              item.onclick = () => send('goTo', { index: globalIdx });
              item.innerHTML = '<strong>Slide ' + (globalIdx+1) + '</strong><small>' + (s.subtitle || s.title || '(Empty)') + '</small>';
              list.appendChild(item);
            });
          }
        });
      } else {
        // Fallback to flat listing
        slides.forEach((s, idx) => {
          const item = document.createElement('div');
          item.className = 'slide-item' + (idx === liveIndex ? ' active' : '');
          item.onclick = () => send('goTo', { index: idx });
          item.innerHTML = '<strong>Slide ' + (idx+1) + '</strong><small>' + (s.subtitle || s.title || '(Empty)') + '</small>';
          list.appendChild(item);
        });
      }
    }
    function setActiveSlide(index) {
      document.querySelectorAll('.slide-item').forEach((item, idx) => {
        item.classList.toggle('active', idx === index);
      });
      // Trigger preview update on manual slide switch if currentSlides is loaded
      const dismissBtn = document.getElementById('dismiss-overlay-btn');
      const hasBible = dismissBtn && dismissBtn.style.display === 'block';
      // If we don't have socket update yet, update preview anyway
      if (currentSlides && currentSlides.length > 0) {
        updateLivePreview(currentSlides, index, null, 'live');
      }
    }
    
    function updateLivePreview(slides, liveIndex, bibleOverlay, mode) {
      const screen = document.getElementById('preview-screen');
      const badge = document.getElementById('preview-badge');
      
      if (mode === 'locked' || !slides || slides.length === 0 || liveIndex < 0 || liveIndex >= slides.length) {
        badge.style.display = 'none';
        screen.style.backgroundColor = '#151528';
        screen.style.backgroundImage = 'none';
        screen.style.color = '#5A5A75';
        screen.innerHTML = '<div style="font-size: 13px; font-weight: bold;">No Active Slide</div>';
        return;
      }
      
      badge.style.display = 'flex';
      const slide = slides[liveIndex];
      
      const toHexColor = (val) => {
        if (val === undefined || val === null) return '#ffffff';
        const hex = (val & 0xFFFFFF).toString(16).padStart(6, '0');
        return '#' + hex;
      };
      
      const bgColor = toHexColor(slide.bgColorValue !== undefined ? slide.bgColorValue : 0xFF1E1E32);
      const textColor = toHexColor(slide.textColorValue !== undefined ? slide.textColorValue : 0xFFFFFFFF);
      
      screen.style.backgroundColor = bgColor;
      screen.style.color = textColor;
      
      if (slide.imageUrl) {
        screen.style.backgroundImage = "url('" + slide.imageUrl + "')";
      } else {
        screen.style.backgroundImage = 'none';
      }
      
      let html = '';
      if (slide.title) {
        html += '<div class="preview-title" style="color: ' + textColor + '">' + slide.title + '</div>';
      }
      if (slide.subtitle) {
        html += '<div class="preview-subtitle" style="color: ' + textColor + '; opacity: 0.85;">' + slide.subtitle + '</div>';
      }
      
      if (bibleOverlay) {
        if (bibleOverlay.isFullscreen) {
          html = '<div class="preview-bible-fullscreen">' +
                 '<div style="font-size: 12px; font-weight: 800; color: #FED65B; margin-bottom: 6px; display: flex; align-items: center; gap: 4px; justify-content: center;">📖 ' + bibleOverlay.title + '</div>' +
                 '<div style="font-size: 11px; color: white; line-height: 1.4;">' + bibleOverlay.subtitle + '</div>' +
                 '</div>';
        } else {
          html += '<div class="preview-bible-overlay">' +
                  '<div style="font-weight: 800; color: #FED65B; margin-bottom: 2px;">📖 ' + bibleOverlay.title + '</div>' +
                  '<div style="color: white; line-height: 1.3;">' + bibleOverlay.subtitle + '</div>' +
                  '</div>';
        }
      }
      
      screen.innerHTML = html;
    }
    
    connect();

    // Pinch-to-zoom / Resize support on Live Monitor card
    const monitorCard = document.getElementById('monitor-card');
    let startDistance = 0;
    let startWidth = 0;
    let lastTap = 0;

    monitorCard.addEventListener('touchstart', (e) => {
      if (e.touches.length === 2) {
        startDistance = Math.hypot(
          e.touches[0].pageX - e.touches[1].pageX,
          e.touches[0].pageY - e.touches[1].pageY
        );
        startWidth = monitorCard.offsetWidth;
      }
    });

    monitorCard.addEventListener('touchmove', (e) => {
      if (e.touches.length === 2 && startDistance > 0) {
        e.preventDefault();
        const distance = Math.hypot(
          e.touches[0].pageX - e.touches[1].pageX,
          e.touches[0].pageY - e.touches[1].pageY
        );
        const factor = distance / startDistance;
        let newWidth = startWidth * factor;
        const minWidth = window.innerWidth * 0.35;
        const maxWidth = window.innerWidth * 0.95;
        newWidth = Math.max(minWidth, Math.min(newWidth, maxWidth));
        
        monitorCard.style.width = newWidth + 'px';
        monitorCard.style.margin = '0 auto 16px auto';
      }
    }, { passive: false });

    monitorCard.addEventListener('touchend', (e) => {
      if (e.touches.length < 2) {
        startDistance = 0;
      }
      const currentTime = new Date().getTime();
      const tapLength = currentTime - lastTap;
      if (tapLength < 300 && tapLength > 0) {
        monitorCard.style.width = '';
        monitorCard.style.margin = '0 0 16px 0';
      }
      lastTap = currentTime;
    });
  </script>
</body>
</html>
''';
  }

  String _buildOverlayHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>LiveDeck OBS Overlay</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body, html {
      width: 100%;
      height: 100%;
      background: transparent !important;
      overflow: hidden;
      font-family: 'Outfit', sans-serif;
    }
    #overlay-container {
      width: 100%;
      height: 100%;
      position: relative;
      display: flex;
      flex-direction: column;
      justify-content: flex-end;
      align-items: center;
      padding: 60px;
    }
    
    /* Lower Third Overlay */
    .lower-third {
      width: 90%;
      max-width: 1200px;
      background: rgba(10, 15, 30, 0.85);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border-left: 6px solid #FED65B;
      border-radius: 16px;
      padding: 24px 36px;
      box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5);
      opacity: 0;
      transform: translateY(40px) scale(0.98);
      transition: opacity 0.4s cubic-bezier(0.16, 1, 0.3, 1), transform 0.4s cubic-bezier(0.16, 1, 0.3, 1);
    }
    
    .lower-third.show {
      opacity: 1;
      transform: translateY(0) scale(1);
    }

    .lower-third .reference {
      font-size: 22px;
      font-weight: 800;
      color: #FED65B;
      text-transform: uppercase;
      letter-spacing: 1.5px;
      margin-bottom: 8px;
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .lower-third .text {
      font-size: 28px;
      font-weight: 500;
      color: #FFFFFF;
      line-height: 1.5;
      font-family: 'Inter', sans-serif;
    }

    /* Fullscreen Overlay */
    .fullscreen-overlay {
      position: absolute;
      inset: 0;
      background: rgba(46, 0, 82, 0.95);
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      text-align: center;
      padding: 80px;
      opacity: 0;
      pointer-events: none;
      transform: scale(1.02);
      transition: opacity 0.4s cubic-bezier(0.16, 1, 0.3, 1), transform 0.4s cubic-bezier(0.16, 1, 0.3, 1);
      z-index: 100;
    }
    
    .fullscreen-overlay.show {
      opacity: 1;
      transform: scale(1);
      pointer-events: auto;
    }

    .fullscreen-overlay .reference {
      font-size: 32px;
      font-weight: 800;
      color: #FED65B;
      text-transform: uppercase;
      letter-spacing: 2px;
      margin-bottom: 24px;
    }

    .fullscreen-overlay .text {
      font-size: 42px;
      font-weight: 700;
      color: #FFFFFF;
      line-height: 1.6;
      max-width: 1400px;
      font-family: 'Inter', sans-serif;
    }
  </style>
</head>
<body>
  <div id="overlay-container">
    <div id="lt-card" class="lower-third">
      <div class="reference">
        <span class="icon">📖</span>
        <span id="lt-ref"></span>
      </div>
      <div id="lt-text" class="text"></div>
    </div>
  </div>

  <div id="fs-card" class="fullscreen-overlay">
    <div id="fs-ref" class="reference"></div>
    <div id="fs-text" class="text"></div>
  </div>

  <script>
    let ws;
    function connect() {
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      ws = new WebSocket(protocol + '//' + window.location.host + '/ws');
      
      ws.onopen = () => {
        console.log('LiveDeck OBS Overlay Connected');
      };
      
      ws.onclose = () => {
        console.log('Connection closed. Reconnecting...');
        setTimeout(connect, 2000);
      };
      
      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          if (data.type === 'state' || data.type === 'update') {
            handleBibleOverlayUpdate(data.bibleOverlay);
          }
        } catch (e) {
          console.error(e);
        }
      };
    }

    const ltCard = document.getElementById('lt-card');
    const ltRef = document.getElementById('lt-ref');
    const ltText = document.getElementById('lt-text');

    const fsCard = document.getElementById('fs-card');
    const fsRef = document.getElementById('fs-ref');
    const fsText = document.getElementById('fs-text');

    function handleBibleOverlayUpdate(bibleOverlay) {
      if (!bibleOverlay) {
        ltCard.classList.remove('show');
        fsCard.classList.remove('show');
        return;
      }

      const { title, subtitle, isFullscreen } = bibleOverlay;

      if (isFullscreen) {
        ltCard.classList.remove('show');
        fsRef.innerText = title;
        fsText.innerText = subtitle;
        fsCard.classList.add('show');
      } else {
        fsCard.classList.remove('show');
        ltRef.innerText = title;
        ltText.innerText = subtitle;
        ltCard.classList.add('show');
      }
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
