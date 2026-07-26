import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_retriever/screen_retriever.dart';

class DisplayInfo {
  final String id;
  final String name;
  final int width;
  final int height;
  final bool isPrimary;
  final int refreshRate;
  final double dx;
  final double dy;

  DisplayInfo({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.isPrimary,
    this.refreshRate = 60,
    this.dx = 0.0,
    this.dy = 0.0,
  });

  String get resolution => '${width}x$height';
}

class DisplayManager extends ChangeNotifier {
  static final DisplayManager instance = DisplayManager._internal();
  static const MethodChannel _channel = MethodChannel('window_control');
  Timer? _refreshTimer;

  DisplayManager._internal() {
    _loadSettings();
    _detectDisplays();
    // Periodically search for connected monitors every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _detectDisplays();
    });
  }

  final List<DisplayInfo> _displays = [];
  List<DisplayInfo> get displays => _displays;

  DisplayInfo? _selectedDisplay;
  DisplayInfo? get selectedDisplay => _selectedDisplay;

  bool _simulateAudience = false;
  bool get simulateAudience => _simulateAudience;

  final List<String> _logs = [];
  List<String> get logs => _logs;

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $message');
    if (_logs.length > 50) _logs.removeAt(0);
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _simulateAudience = prefs.getBool('simulate_audience') ?? false;
    log('Settings loaded. Simulation Mode: $_simulateAudience');
    _detectDisplays();
  }

  Future<void> setSimulateAudience(bool value) async {
    _simulateAudience = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('simulate_audience', value);
    log('Simulation Mode updated: $value');
    _detectDisplays();
  }

  Future<void> refreshDisplays() async {
    await _detectDisplays();
  }

  Future<void> _detectDisplays() async {
    final List<DisplayInfo> newDisplays = [];
    try {
      if (Platform.isWindows) {
        log('Detecting displays via native Win32 API...');
        final List<dynamic>? nativeDisplays = await _channel.invokeMethod<List<dynamic>>('getDisplays');
        if (nativeDisplays != null && nativeDisplays.isNotEmpty) {
          log('Fetched ${nativeDisplays.length} display(s) from Win32 API');
          for (var i = 0; i < nativeDisplays.length; i++) {
            final Map<dynamic, dynamic> d = nativeDisplays[i] as Map<dynamic, dynamic>;
            final id = d['id'] as String;
            final name = d['name'] as String;
            final x = (d['x'] as int).toDouble();
            final y = (d['y'] as int).toDouble();
            final w = d['width'] as int;
            final h = d['height'] as int;
            final isPrimary = d['isPrimary'] as bool;
            log('Win32 Display [$i]: ID=$id, Name="$name", Size=${w}x${h}, Offset=$x,$y, isPrimary=$isPrimary');
            newDisplays.add(DisplayInfo(
              id: id,
              name: name,
              width: w,
              height: h,
              isPrimary: isPrimary,
              dx: x,
              dy: y,
            ));
          }
        }
      } else {
        log('Detecting displays via screenRetriever...');
        final primary = await screenRetriever.getPrimaryDisplay();
        log('Primary display detected: ID=${primary.id}, size=${primary.size}');
        final realDisplays = await screenRetriever.getAllDisplays();
        log('Fetched ${realDisplays.length} display(s) from OS');
        for (var i = 0; i < realDisplays.length; i++) {
          final d = realDisplays[i];
          final size = d.size;
          final pos = d.visiblePosition ?? const Offset(0, 0);
          final name = d.name ?? (d.id == primary.id ? 'Laptop Integrated Display' : 'External Display #${i}');
          log('Display [$i]: ID=${d.id}, Name="$name", Size=${size.width}x${size.height}, Offset=${pos.dx},${pos.dy}');
          newDisplays.add(DisplayInfo(
            id: d.id.toString(),
            name: name,
            width: size.width.toInt(),
            height: size.height.toInt(),
            isPrimary: d.id == primary.id,
            dx: pos.dx,
            dy: pos.dy,
          ));
        }
      }

      // If we only have the primary display detected, but simulation mode is enabled, add dummy displays
      if (_simulateAudience && newDisplays.length <= 1) {
        newDisplays.add(DisplayInfo(
          id: 'disp_1',
          name: 'Dell UltraSharp 4K (Simulated)',
          width: 3840,
          height: 2160,
          isPrimary: false,
          refreshRate: 60,
          dx: 1920.0,
          dy: 0.0,
        ));

        newDisplays.add(DisplayInfo(
          id: 'disp_2',
          name: 'Epson Projector H100 (Simulated)',
          width: 1920,
          height: 1080,
          isPrimary: false,
          refreshRate: 60,
          dx: 1920.0,
          dy: 1080.0,
        ));
      }
    } catch (e) {
      log('EXCEPTION during display detection: $e');
      newDisplays.add(DisplayInfo(
        id: 'disp_0',
        name: 'Laptop Integrated Display',
        width: 1920,
        height: 1080,
        isPrimary: true,
        refreshRate: 60,
        dx: 0.0,
        dy: 0.0,
      ));

      if (_simulateAudience) {
        newDisplays.add(DisplayInfo(
          id: 'disp_1',
          name: 'Dell UltraSharp 4K (Simulated)',
          width: 3840,
          height: 2160,
          isPrimary: false,
          refreshRate: 60,
          dx: 1920.0,
          dy: 0.0,
        ));

        newDisplays.add(DisplayInfo(
          id: 'disp_2',
          name: 'Epson Projector H100 (Simulated)',
          width: 1920,
          height: 1080,
          isPrimary: false,
          refreshRate: 60,
          dx: 1920.0,
          dy: 1080.0,
        ));
      }
    }

    bool changed = false;
    if (newDisplays.length != _displays.length) {
      changed = true;
    } else {
      for (int i = 0; i < newDisplays.length; i++) {
        if (newDisplays[i].id != _displays[i].id ||
            newDisplays[i].name != _displays[i].name ||
            newDisplays[i].width != _displays[i].width ||
            newDisplays[i].height != _displays[i].height ||
            newDisplays[i].dx != _displays[i].dx ||
            newDisplays[i].dy != _displays[i].dy) {
          changed = true;
          break;
        }
      }
    }

    if (changed) {
      _displays.clear();
      _displays.addAll(newDisplays);

      if (_displays.isNotEmpty) {
        if (_selectedDisplay != null) {
          final matching = _displays.where((d) => d.id == _selectedDisplay!.id);
          if (matching.isNotEmpty) {
            _selectedDisplay = matching.first;
          } else {
            _selectedDisplay = _displays.first;
          }
        } else {
          _selectedDisplay = _displays.first;
        }
      } else {
        _selectedDisplay = null;
      }
      log('Monitor discovery updated. Detected ${_displays.length} displays.');
      notifyListeners();
    }
  }

  void selectDisplay(String displayId) {
    final match = _displays.where((d) => d.id == displayId);
    if (match.isNotEmpty) {
      _selectedDisplay = match.first;
      log('Active target changed to: ${_selectedDisplay!.name}');
      notifyListeners();
    }
  }

  void simulateDisconnect(String displayId) {
    final matchIdx = _displays.indexWhere((d) => d.id == displayId);
    if (matchIdx >= 0) {
      final name = _displays[matchIdx].name;
      _displays.removeAt(matchIdx);
      log('Display disconnected: $name');
      if (_selectedDisplay?.id == displayId) {
        _selectedDisplay = _displays.isNotEmpty ? _displays.first : null;
        log('Target automatically reset to: ${_selectedDisplay?.name ?? "None"}');
      }
      notifyListeners();
    }
  }

  void simulateConnect(DisplayInfo display) {
    _displays.add(display);
    log('New display detected: ${display.name} (${display.resolution})');
    notifyListeners();
  }
}

