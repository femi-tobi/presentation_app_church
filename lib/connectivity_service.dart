// lib/connectivity_service.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// A singleton ChangeNotifier that broadcasts online/offline state globally.
/// All pages listen to this one instance so the status is always in sync.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._internal() {
    _checkNow();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkNow());
  }

  static final ConnectivityService instance = ConnectivityService._internal();

  Timer? _timer;
  bool _isOnline = false;

  bool get isOnline => _isOnline;

  void _checkNow() {
    final online = html.window.navigator.onLine ?? false;
    if (online != _isOnline) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
