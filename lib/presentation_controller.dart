import 'dart:async';
import 'package:flutter/material.dart';
import 'settings_state.dart';

enum PresentationMode { live, rehearsal, auto, locked }

class PresentationController extends ChangeNotifier {
  static final PresentationController instance = PresentationController._internal();

  PresentationController._internal() {
    _startElapsedTimeTimer();
  }

  List<SlideData> _slides = [];
  List<SlideSection> _sections = [];

  List<SlideData> get slides => _slides;
  List<SlideSection> get sections => _sections;

  // Track two slide indices:
  // - _liveIndex: what the audience sees (frozen during Rehearsal)
  // - _presenterIndex: what the presenter sees
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

  void initialize(List<SlideData> slidesList, List<SlideSection> sectionsList, int startIndex) {
    _slides = slidesList;
    _sections = sectionsList;
    _liveIndex = startIndex;
    _presenterIndex = startIndex;
    _startTime = DateTime.now();
    _elapsedTime = Duration.zero;
    _mode = PresentationMode.live;
    _stopAutoplayTimer();
    notifyListeners();
  }

  void setMode(PresentationMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;

    if (_mode == PresentationMode.live) {
      // Sync live view with current presenter state when switching back to live
      _liveIndex = _presenterIndex;
    }

    if (_mode == PresentationMode.auto) {
      _startAutoplayTimer();
    } else {
      _stopAutoplayTimer();
    }

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
      // Rehearsal mode keeps audience frozen on the live index
      _liveIndex = index;
    }

    notifyListeners();
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
        // Loop back or stop
        goTo(0);
      }
    });
  }

  void _stopAutoplayTimer() {
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _autoplayTimer?.cancel();
    super.dispose();
  }
}
