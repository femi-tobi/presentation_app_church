/// Cross-platform connectivity check.
/// - On web (dart:html): uses window.navigator.onLine
/// - On native (dart:io): uses a raw Socket connect to Google DNS (8.8.8.8:53)
/// - Fallback stub: always returns false
export 'connectivity_helper_stub.dart'
    if (dart.library.io) 'connectivity_helper_io.dart'
    if (dart.library.html) 'connectivity_helper_web.dart';
