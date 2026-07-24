// lib/presenter_view.dart
// Professional Presenter View — 4-panel layout with current/next slide,
// speaker notes, section info, service clock, and progress bar.

import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';
import 'dashboard_page.dart';
import 'presentation_controller.dart';
import 'display_manager.dart';
import 'diagnostics_page.dart';
import 'audience_window.dart';

Uint8List _decodeDataUrlPresenter(String dataUrl) {
  return decodeDataUrl(dataUrl);
}

/// Professional Presenter View modeled after PowerPoint Presenter View.
/// Shows current slide, next slide, speaker notes, section info, and service clock.
class ProfessionalPresenterView extends StatefulWidget {
  const ProfessionalPresenterView({super.key});

  @override
  State<ProfessionalPresenterView> createState() => _ProfessionalPresenterViewState();
}

class _ProfessionalPresenterViewState extends State<ProfessionalPresenterView> {
  final FocusNode _focusNode = FocusNode();
  late Timer _blinkTimer;
  bool _liveDotVisible = true;
  bool _displaysSwapped = false;

  @override
  void initState() {
    super.initState();
    PresentationController.instance.initialize(
      AppSettings.instance.activeSlides,
      AppSettings.instance.activeSections,
      AppSettings.instance.activeSlideIndex,
    );
    PresentationController.instance.addListener(_onControllerChanged);
    DisplayManager.instance.addListener(_onDisplayChanged);
    _focusNode.requestFocus();

    // Blink the LIVE dot
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted && PresentationController.instance.mode == PresentationMode.live) {
        setState(() => _liveDotVisible = !_liveDotVisible);
      }
    });

    DisplayManager.instance.log('Presenter View initialized and synchronized.');
  }

  @override
  void dispose() {
    PresentationController.instance.removeListener(_onControllerChanged);
    DisplayManager.instance.removeListener(_onDisplayChanged);
    _blinkTimer.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onDisplayChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int get _currentIndex => PresentationController.instance.presenterIndex;

  List<SlideData> get _slides => PresentationController.instance.slides;
  List<SlideSection> get _sections => PresentationController.instance.sections;

  SlideData? get _currentSlide =>
      _slides.isNotEmpty && _currentIndex < _slides.length ? _slides[_currentIndex] : null;

  SlideData? get _nextSlide =>
      _currentIndex + 1 < _slides.length ? _slides[_currentIndex + 1] : null;

  SlideSection? get _currentSection {
    if (_currentSlide == null) return null;
    final idx = _sections.indexWhere(
      (s) => s.slideIds.contains(_currentSlide!.id),
    );
    return idx >= 0 ? _sections[idx] : null;
  }

  SlideSection? get _nextSection {
    if (_nextSlide == null) return null;
    final nextSec = _sections.indexWhere(
      (s) => s.slideIds.contains(_nextSlide!.id),
    );
    if (nextSec >= 0 && _sections[nextSec].id != _currentSection?.id) {
      return _sections[nextSec];
    }
    // Look ahead for the next different section
    for (int i = _currentIndex + 1; i < _slides.length; i++) {
      final sec = _sections.indexWhere((s) => s.slideIds.contains(_slides[i].id));
      if (sec >= 0 && _sections[sec].id != _currentSection?.id) {
        return _sections[sec];
      }
    }
    return null;
  }

  int get _currentSlideInSection {
    final sec = _currentSection;
    if (sec == null || _currentSlide == null) return 0;
    return sec.slideIds.indexOf(_currentSlide!.id) + 1;
  }

  int get _totalSlidesInSection => _currentSection?.slideIds.length ?? 0;

  double get _progress => _slides.isEmpty ? 0 : (_currentIndex + 1) / _slides.length;

  Duration get _elapsed => PresentationController.instance.elapsedTime;

  Duration get _estimatedRemaining {
    if (_slides.isEmpty || _currentIndex >= _slides.length - 1) return Duration.zero;
    final elapsedSec = _elapsed.inSeconds;
    if (elapsedSec == 0) return Duration.zero;
    final avgPerSlide = elapsedSec / (_currentIndex + 1);
    final remaining = avgPerSlide * (_slides.length - _currentIndex - 1);
    return Duration(seconds: remaining.round());
  }

  String get _estimatedFinish {
    final finish = DateTime.now().add(_estimatedRemaining);
    return '${finish.hour.toString().padLeft(2, '0')}:${finish.minute.toString().padLeft(2, '0')}';
  }

  bool get _isApproachingNewSection {
    if (_currentSection == null) return false;
    final slideIds = _currentSection!.slideIds;
    final posInSection = slideIds.indexOf(_currentSlide?.id ?? '');
    return posInSection >= slideIds.length - 2 && _nextSection != null;
  }

  void _goTo(int index) {
    PresentationController.instance.goTo(index);
  }

  void _next() => PresentationController.instance.next();
  void _prev() => PresentationController.instance.prev();
  void _goFirst() => PresentationController.instance.goFirst();
  void _goLast() => PresentationController.instance.goLast();

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (PresentationController.instance.mode == PresentationMode.locked) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.pageDown:
        _next();
        break;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.pageUp:
        _prev();
        break;
      case LogicalKeyboardKey.home:
        _goFirst();
        break;
      case LogicalKeyboardKey.end:
        _goLast();
        break;
      case LogicalKeyboardKey.escape:
        Navigator.pop(context);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(
          child: Text(
            'No slides available.',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 18),
          ),
        ),
      );
    }

    final mainLayout = Column(
      children: [
        // Top bar
        _buildTopBar(),

        // Main content
        Expanded(
          child: Row(
            children: [
              // Left: Current Slide (large)
              Expanded(
                flex: 3,
                child: _buildCurrentSlidePanel(),
              ),

              // Right column: Next slide + Notes
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Next Slide preview
                    Expanded(
                      flex: 2,
                      child: _buildNextSlidePanel(),
                    ),
                    // Speaker Notes
                    Expanded(
                      flex: 3,
                      child: _buildNotesPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Section Info Bar
        _buildSectionInfoBar(),

        // Bottom Clock / Progress Bar
        _buildBottomBar(),
      ],
    );

    Widget bodyContent;
    if (DisplayManager.instance.simulateAudience) {
      bodyContent = Column(
        children: [
          Expanded(
            flex: 3,
            child: mainLayout,
          ),
          Container(
            height: 6,
            color: Colors.white10,
          ),
          const Expanded(
            flex: 2,
            child: AudienceWindow(),
          ),
        ],
      );
    } else {
      bodyContent = mainLayout;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: bodyContent,
      ),
    );
  }

  // ─── Top Bar ─────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final pc = PresentationController.instance;
    final dm = DisplayManager.instance;
    final modeBadge = _getModeBadge();

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151528),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // Mode badge
          GestureDetector(
            onTap: _showModeToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: modeBadge.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: modeBadge.color.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedOpacity(
                    opacity: pc.mode == PresentationMode.live
                        ? (_liveDotVisible ? 1.0 : 0.2)
                        : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: modeBadge.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    modeBadge.label,
                    style: GoogleFonts.inter(
                      color: modeBadge.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 14, color: modeBadge.color),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Slide counter
          Text(
            'Slide ${_currentIndex + 1} of ${_slides.length}',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),

          const SizedBox(width: 16),

          // "Present To" Dropdown
          Text(
            'Present To:',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButton<String>(
              value: dm.selectedDisplay?.id,
              dropdownColor: const Color(0xFF151528),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white54),
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
              onChanged: (val) {
                if (val != null) {
                  dm.selectDisplay(val);
                }
              },
              items: dm.displays.map((disp) {
                return DropdownMenuItem<String>(
                  value: disp.id,
                  child: Text(
                    '${disp.name} (${disp.resolution})',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(width: 12),

          // Diagnostics Panel Launcher
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF222238),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DiagnosticsPage()),
              );
            },
            icon: const Icon(Icons.analytics_outlined, size: 14),
            label: const Text('Diagnostics'),
          ),

          const SizedBox(width: 12),

          // Start Presentation Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AudienceWindow()),
              );
            },
            icon: const Icon(Icons.play_arrow, size: 14),
            label: const Text('Start Presentation'),
          ),

          const Spacer(),

          // Navigation buttons
          _NavButton(icon: Icons.first_page, tooltip: 'First (Home)', onPressed: _goFirst),
          _NavButton(icon: Icons.chevron_left, tooltip: 'Previous (←)', onPressed: _prev),
          _NavButton(icon: Icons.chevron_right, tooltip: 'Next (→)', onPressed: _next),
          _NavButton(icon: Icons.last_page, tooltip: 'Last (End)', onPressed: _goLast),

          const SizedBox(width: 12),

          // Exit button
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 16, color: Colors.white54),
            label: Text(
              'Exit',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  _ModeBadge _getModeBadge() {
    final mode = PresentationController.instance.mode;
    switch (mode) {
      case PresentationMode.live:
        return _ModeBadge('LIVE', Colors.red);
      case PresentationMode.rehearsal:
        return _ModeBadge('REHEARSAL', Colors.amber);
      case PresentationMode.auto:
        return _ModeBadge('AUTO', Colors.green);
      case PresentationMode.locked:
        return _ModeBadge('LOCKED', Colors.blue);
    }
  }

  void _showModeToggle() {
    final modes = [
      (PresentationMode.live, 'LIVE', Colors.red, Icons.fiber_manual_record),
      (PresentationMode.rehearsal, 'REHEARSAL', Colors.amber, Icons.timer_outlined),
      (PresentationMode.auto, 'AUTO-PLAY', Colors.green, Icons.play_circle_outline),
      (PresentationMode.locked, 'LOCKED', Colors.blue, Icons.lock_outline),
    ];

    showMenu<PresentationMode>(
      context: context,
      position: const RelativeRect.fromLTRB(16, 52, 200, 0),
      color: const Color(0xFF1E1E32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: modes.map((m) => PopupMenuItem<PresentationMode>(
        value: m.$1,
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: m.$3, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Icon(m.$4, size: 16, color: m.$3),
            const SizedBox(width: 8),
            Text(m.$2, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            if (m.$1 == PresentationController.instance.mode) ...[
              const Spacer(),
              Icon(Icons.check, size: 14, color: m.$3),
            ],
          ],
        ),
      )).toList(),
    ).then((value) {
      if (value != null) {
        PresentationController.instance.setMode(value);
      }
    });
  }

  // ─── Current Slide Panel ─────────────────────────────────────────────────

  Widget _buildCurrentSlidePanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'CURRENT SLIDE',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          // Slide preview
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _currentSlide != null
                  ? _SlidePreviewWidget(slide: _currentSlide!, showDetails: true)
                  : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Next Slide Panel ────────────────────────────────────────────────────

  Widget _buildNextSlidePanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'NEXT SLIDE',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _next,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _nextSlide != null
                    ? _SlidePreviewWidget(slide: _nextSlide!)
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white24, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'End of Presentation',
                                style: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Speaker Notes Panel ─────────────────────────────────────────────────

  Widget _buildNotesPanel() {
    final notes = _currentSection?.notes ?? '';
    final sectionColor = _currentSection != null
        ? getSectionColor(_currentSection!.sectionType, isDarkMode: true)
        : Colors.blue;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notes header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sectionColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
            ),
            child: Row(
              children: [
                Icon(Icons.speaker_notes, size: 15, color: sectionColor),
                const SizedBox(width: 8),
                Text(
                  'SPEAKER NOTES',
                  style: GoogleFonts.inter(
                    color: sectionColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Notes content
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Text(
                      'No notes for this section',
                      style: GoogleFonts.inter(
                        color: Colors.white24,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      notes,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Section Info Bar ────────────────────────────────────────────────────

  Widget _buildSectionInfoBar() {
    final currentSec = _currentSection;
    final nextSec = _nextSection;
    final currentColor = currentSec != null
        ? getSectionColor(currentSec.sectionType, isDarkMode: true)
        : Colors.grey;
    final nextColor = nextSec != null
        ? getSectionColor(nextSec.sectionType, isDarkMode: true)
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151528),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          // Current section
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentSec?.name ?? 'No Section',
                      style: GoogleFonts.inter(
                        color: currentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (currentSec != null)
                      Text(
                        'Slide $_currentSlideInSection of $_totalSlidesInSection',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Upcoming section alert — highly visible
          if (_isApproachingNewSection && nextSec != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: nextColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: nextColor.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: nextColor.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: nextColor),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'UPCOMING TRANSITION',
                        style: GoogleFonts.inter(
                          color: nextColor.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        nextSec.name,
                        style: GoogleFonts.inter(
                          color: nextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(width: 16),

          // Next section
          if (nextSec != null)
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NEXT',
                      style: GoogleFonts.inter(
                        color: Colors.white30,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      nextSec.name,
                      style: GoogleFonts.inter(
                        color: nextColor.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: nextColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Bottom Bar (Clock, Progress) ────────────────────────────────────────

  Widget _buildBottomBar() {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final elapsedStr = _formatDuration(_elapsed);
    final remainingStr = _formatDuration(_estimatedRemaining);
    final progressPct = (_progress * 100).round();

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A18),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // Current time
          _ClockItem(icon: Icons.access_time, label: timeStr, color: Colors.white70),
          _divider(),

          // Elapsed
          _ClockItem(icon: Icons.timer_outlined, label: elapsedStr, color: Colors.cyan.withOpacity(0.8)),
          _divider(),

          // Remaining
          _ClockItem(icon: Icons.hourglass_bottom, label: remainingStr, color: Colors.amber.withOpacity(0.8)),
          _divider(),

          // Estimated finish
          _ClockItem(icon: Icons.flag_outlined, label: _estimatedFinish, color: Colors.green.withOpacity(0.8)),

          const Spacer(),

          // Progress bar
          SizedBox(
            width: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progress > 0.8 ? Colors.green : Colors.cyan,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$progressPct% complete',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withOpacity(0.08),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ─── Slide Preview Widget ──────────────────────────────────────────────────

class _SlidePreviewWidget extends StatelessWidget {
  final SlideData slide;
  final bool showDetails;

  const _SlidePreviewWidget({required this.slide, this.showDetails = false});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Color(slide.bgColorValue),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Stack(
          children: [
            // Background image
            if (slide.imageUrl.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Opacity(
                    opacity: slide.opacity,
                    child: slide.blur > 0
                        ? ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: slide.blur * 0.5,
                              sigmaY: slide.blur * 0.5,
                            ),
                            child: _buildImage(slide.imageUrl),
                          )
                        : _buildImage(slide.imageUrl),
                  ),
                ),
              ),

            // Text content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxHeight < 40 || constraints.maxWidth < 60) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (slide.title.isNotEmpty)
                          Flexible(
                            child: Text(
                              slide.title,
                              textAlign: slide.alignment,
                              maxLines: showDetails ? 4 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: slide.isBold ? FontWeight.bold : FontWeight.w600,
                                fontStyle: slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                fontSize: showDetails ? 20 : 14,
                                shadows: const [
                                  Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                        if (slide.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              slide.subtitle,
                              textAlign: slide.alignment,
                              maxLines: showDetails ? 8 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: slide.isBold ? FontWeight.w600 : FontWeight.normal,
                                fontStyle: slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                fontSize: showDetails ? 16 : 11,
                                height: 1.4,
                                shadows: const [
                                  Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('data:')) {
      try {
        return Image.memory(
          _decodeDataUrlPresenter(url),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const SizedBox(),
        );
      } catch (_) {
        return const SizedBox();
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => const SizedBox(),
    );
  }
}

// ─── Nav Button ────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NavButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: Colors.white60),
        ),
      ),
    );
  }
}

// ─── Clock Item ────────────────────────────────────────────────────────────

class _ClockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ClockItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.6)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ─── Mode Badge helper ─────────────────────────────────────────────────────

class _ModeBadge {
  final String label;
  final Color color;
  const _ModeBadge(this.label, this.color);
}
