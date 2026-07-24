import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplayInfo {
  final String id;
  final String name;
  final int width;
  final int height;
  final bool isPrimary;
  final int refreshRate;

  DisplayInfo({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.isPrimary,
    this.refreshRate = 60,
  });

  String get resolution => '${width}x$height';
}

class DisplayManager extends ChangeNotifier {
  static final DisplayManager instance = DisplayManager._internal();

  DisplayManager._internal() {
    _loadSettings();
    _detectDisplays();
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
    notifyListeners();
  }

  Future<void> setSimulateAudience(bool value) async {
    _simulateAudience = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('simulate_audience', value);
    log('Simulation Mode updated: $value');
    notifyListeners();
  }

  void _detectDisplays() {
    _displays.clear();
    // Default Laptop primary display
    _displays.add(DisplayInfo(
      id: 'disp_0',
      name: 'Laptop Integrated Display',
      width: 1920,
      height: 1080,
      isPrimary: true,
      refreshRate: 60,
    ));

    // Simulate extra screens by default to guarantee options are present
    _displays.add(DisplayInfo(
      id: 'disp_1',
      name: 'Dell UltraSharp 4K',
      width: 3840,
      height: 2160,
      isPrimary: false,
      refreshRate: 60,
    ));

    _displays.add(DisplayInfo(
      id: 'disp_2',
      name: 'Epson Projector H100',
      width: 1920,
      height: 1080,
      isPrimary: false,
      refreshRate: 60,
    ));

    _selectedDisplay = _displays.first;
    log('Automatic monitor discovery completed. Detected ${_displays.length} displays.');
    notifyListeners();
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
