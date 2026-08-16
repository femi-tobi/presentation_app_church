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
      }).toList(),
      'sections': controller.sections.map((sec) => {
        'id': sec.id,
        'name': sec.name,
        'colorValue': sec.colorValue,
        'slideIds': sec.slideIds,
      }).toList(),
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
          // Clone SlideData elements to prevent empty slide template generation
          final clonedSlides = record.slides.map((s) => SlideData.fromJson(s.toJson())).toList();
          final clonedSections = (record.sections ?? []).map((sec) => SlideSection.fromJson(sec.toJson())).toList();
          
          // Set active slide state on controller
          controller.initialize(clonedSlides, clonedSections, 0, isAudience: false);
          
          // Also set settings active variables to match main app expectations
          AppSettings.instance.updateActiveSlides(clonedSlides);
          AppSettings.instance.activeSlideIndex = 0;
          break;
        case 'startPresentation':
          final activeSlides = controller.slides;
          // Ensure we have loaded a valid presentation from dropdown selection
          if (activeSlides.isNotEmpty) {
            controller.setMode(PresentationMode.live);
            controller.spawnAudienceWindow();
            
            final nav = appNavigatorKey.currentState;
            if (nav != null) {
              // Try to find the selected presentation from list to get correct metadata
              final currentActiveId = AppSettings.instance.recentPresentations.firstWhere(
                (p) => p.slides.isNotEmpty && p.slides.first.id == activeSlides.first.id,
                orElse: () => AppSettings.instance.recentPresentations.first,
              ).id;
              
              // 1. First push PreviewPage matching the selected slide deck
              nav.push(MaterialPageRoute(
                builder: (_) => PreviewPage(
                  presentationId: currentActiveId,
                  initialSlides: activeSlides,
                  initialSections: controller.sections,
                ),
              ));
              
              // 2. Next push the ProfessionalPresenterView (Presenter view dashboard window)
              nav.push(MaterialPageRoute(
                builder: (_) => const ProfessionalPresenterView(),
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
          
          // Construct SlideData element representing the selected verse
          final newSlide = SlideData(
            id: 'verse_${DateTime.now().millisecondsSinceEpoch}',
            title: reference,
            subtitle: verseText,
            imageUrl: '',
            opacity: 0.85,
            blur: 12.0,
            bgColorValue: 0xFF2E0052,
            textColorValue: 0xFFFFFFFF,
          );
          
          // Push instantly to active slides deck
          controller.initialize([newSlide], [], 0, isAudience: false);
          AppSettings.instance.updateActiveSlides([newSlide]);
          AppSettings.instance.activeSlideIndex = 0;
          controller.setMode(PresentationMode.live);
          controller.spawnAudienceWindow();
          break;
        case 'endPresentation':
          // Close presenter view dialog stack on desktop app and exit fullscreen view
          final nav = appNavigatorKey.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop(); // Pop FullscreenPresenterPage / ProfessionalPresenterView
            if (nav.canPop()) {
              nav.pop(); // Pop PreviewPage back to DashboardPage
            }
          }
          controller.setMode(PresentationMode.locked);
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

  <div class="card">
    <div class="card-title">📂 Select Presentation</div>
    <select id="pres-select" onchange="selectPresentation(this.value)">
      <option value="">Choose a file...</option>
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
      <input type="text" id="bible-search-input" placeholder="Search verse (e.g. John 3:16)" style="flex: 1; padding: 12px; border-radius: 8px; border: 1px solid $outlineColor; background: $surfaceColor; color: $textColor; outline: none; font-size: 14px;">
      <button class="btn btn-primary" onclick="searchBible()" style="margin: 0; padding: 0 16px; border-radius: 8px; font-size: 14px; width: auto;">Search</button>
    </div>
    <select id="bible-translation" style="margin-bottom: 12px; padding: 10px;">
      <option value="kjv">King James Version (KJV)</option>
      <option value="niv">New International Version (NIV)</option>
    </select>
    <div id="bible-results" style="max-height: 200px; overflow-y: auto; border: 1px solid $outlineColor; border-radius: 8px; background: $surfaceColor; display: none;"></div>
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
          currentSections = data.sections || [];
          updateSlideList(data.slides || [], data.liveIndex);
          updateSwitches(data.useLowerThird, data.usePiP);
          updateModeUI(data.mode);
        } else if (data.type === 'update') {
          updateSwitches(data.useLowerThird, data.usePiP);
          updateModeUI(data.mode);
          if (data.sections) currentSections = data.sections;
          if (data.slides) {
            updateSlideList(data.slides, data.liveIndex);
          } else {
            setActiveSlide(data.liveIndex);
          }
        } else if (data.type === 'searchResults') {
          displaySearchResults(data.results || []);
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
    function searchBible() {
      const query = document.getElementById('bible-search-input').value;
      const translation = document.getElementById('bible-translation').value;
      if (query.trim()) {
        send('searchBible', { query, translation });
      }
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
        div.style.cursor = 'pointer';
        div.style.fontSize = '13px';
        div.style.textAlign = 'left';
        const ref = r.book + ' ' + r.chapter + ':' + r.verse;
        div.innerHTML = '<strong>' + ref + '</strong><div style="color: $mutedColor; margin-top: 2px;">' + r.text + '</div>';
        div.onclick = () => {
          send('presentVerse', { text: r.text, reference: ref });
          container.style.display = 'none';
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
