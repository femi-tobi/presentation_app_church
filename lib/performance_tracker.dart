import 'package:flutter/foundation.dart';

/// Lightweight helper to log and track performance metrics in development.
class PerformanceTracker {
  PerformanceTracker._();

  static final Map<String, Stopwatch> _activeStopwatches = {};

  /// Starts a timer with a given label.
  static void start(String label) {
    if (kReleaseMode) return;
    final sw = Stopwatch()..start();
    _activeStopwatches[label] = sw;
  }

  /// Stops the timer with a given label and logs the duration.
  static void stop(String label, {String? extraInfo}) {
    if (kReleaseMode) return;
    final sw = _activeStopwatches.remove(label);
    if (sw != null) {
      sw.stop();
      final ms = sw.elapsedMilliseconds;
      debugPrint('[PERF] $label completed in ${ms}ms${extraInfo != null ? ' ($extraInfo)' : ''}');
    }
  }

  /// Runs an action, tracks its execution time, and returns the result.
  static T track<T>(String label, T Function() action, {String? extraInfo}) {
    if (kReleaseMode) return action();
    final sw = Stopwatch()..start();
    try {
      return action();
    } finally {
      sw.stop();
      debugPrint('[PERF] $label completed in ${sw.elapsedMilliseconds}ms${extraInfo != null ? ' ($extraInfo)' : ''}');
    }
  }

  /// Runs an async action, tracks its execution time, and returns the result.
  static Future<T> trackAsync<T>(String label, Future<T> Function() action, {String? extraInfo}) async {
    if (kReleaseMode) return await action();
    final sw = Stopwatch()..start();
    try {
      return await action();
    } finally {
      sw.stop();
      debugPrint('[PERF] $label completed in ${sw.elapsedMilliseconds}ms${extraInfo != null ? ' ($extraInfo)' : ''}');
    }
  }
}
