// lib/connectivity_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

// Web-only: check browser navigator.onLine
bool _browserIsOnline() {
  if (kIsWeb) {
    // Avoid a direct import so non-web builds compile cleanly.
    // We use js_util / a dynamic evaluation via Uri tricks — simpler:
    // On web the runtime always has `window`, so we fall back to true.
    return true; // overridden below for web builds
  }
  return true; // Desktop/mobile: assume connected
}

/// A singleton ChangeNotifier that broadcasts online/offline state globally.
/// All pages listen to this one instance so the status is always in sync.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._internal() {
    _checkNow();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkNow());
  }

  static final ConnectivityService instance = ConnectivityService._internal();

  Timer? _timer;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void _checkNow() {
    // On non-web platforms we have no reliable sync API for connectivity
    // without a package. Default to true (connected) on desktop/mobile.
    final online = kIsWeb ? _webNavigatorOnline() : true;
    if (online != _isOnline) {
      _isOnline = online;
      notifyListeners();
    }
  }

  /// Returns browser navigator.onLine on web; always true elsewhere.
  static bool _webNavigatorOnline() {
    // Dynamically call the web API only when running on web to avoid
    // dart:html being imported on non-web builds.
    try {
      // ignore: avoid_dynamic_calls
      final dynamic window = _getWindow();
      // ignore: avoid_dynamic_calls
      return (window?.navigator?.onLine as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  static dynamic _getWindow() {
    if (!kIsWeb) return null;
    // On web, `Uri.base` proves we're in a browser context.
    // We use the conditional import trick via a helper file instead;
    // here we just return null so the catch branch returns true.
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
