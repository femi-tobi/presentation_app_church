import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';
import 'dashboard_page.dart'; // For SacredColors / Shadows / Typography
import 'pptx_slide_renderer.dart';

Uint8List _decodeDataUrl(String dataUrl) {
  return decodeDataUrl(dataUrl);
}

class FullscreenPresenterPage extends StatefulWidget {
  const FullscreenPresenterPage({super.key});

  @override
  State<FullscreenPresenterPage> createState() => _FullscreenPresenterPageState();
}

class _FullscreenPresenterPageState extends State<FullscreenPresenterPage> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showControls = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = AppSettings.instance.activeSlideIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
    // Auto-request focus for keyboard navigation
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (_currentIndex < AppSettings.instance.activeSlides.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      AppSettings.instance.activeSlideIndex = _currentIndex;
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      AppSettings.instance.activeSlideIndex = _currentIndex;
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final settings = AppSettings.instance;
    final shortcuts = settings.customShortcuts;

    String getKeyName(LogicalKeyboardKey key) {
      if (key == LogicalKeyboardKey.arrowRight) return 'Arrow Right';
      if (key == LogicalKeyboardKey.arrowLeft) return 'Arrow Left';
      if (key == LogicalKeyboardKey.space) return 'Space';
      if (key == LogicalKeyboardKey.backspace) return 'Backspace';
      if (key == LogicalKeyboardKey.home) return 'Home';
      if (key == LogicalKeyboardKey.end) return 'End';
      if (key == LogicalKeyboardKey.escape) return 'Escape';
      return key.keyLabel;
    }

    final keyLabel = getKeyName(event.logicalKey);

    // Resolve which action corresponds to the pressed key label
    String? matchedAction;
    shortcuts.forEach((action, bindName) {
      if (bindName.toLowerCase() == keyLabel.toLowerCase()) {
        matchedAction = action;
      }
    });

    if (matchedAction == 'nextSlide') {
      _nextSlide();
    } else if (matchedAction == 'prevSlide') {
      _prevSlide();
    } else if (matchedAction == 'firstSlide') {
      setState(() {
        _currentIndex = 0;
      });
      _pageController.jumpToPage(0);
      AppSettings.instance.activeSlideIndex = 0;
    } else if (matchedAction == 'lastSlide') {
      final lastIdx = AppSettings.instance.activeSlides.length - 1;
      setState(() {
        _currentIndex = lastIdx;
      });
      _pageController.jumpToPage(lastIdx);
      AppSettings.instance.activeSlideIndex = lastIdx;
    } else if (matchedAction == 'exitPresentation') {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final slides = AppSettings.instance.activeSlides;

        if (slides.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'No slides available to present.',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
              ),
            ),
          );
        }

        // Keep index in bounds in case slides count changed
        if (_currentIndex >= slides.length) {
          _currentIndex = slides.length - 1;
        }
        if (_currentIndex < 0) {
          _currentIndex = 0;
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
          },
          child: Stack(
            children: [
              // Main Slides PageView
              PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  AppSettings.instance.activeSlideIndex = index;
                },
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double width = constraints.maxWidth;
                          final double height = constraints.maxHeight;

                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double pageOffset = 0.0;
                              if (_pageController.hasClients &&
                                  _pageController.position.haveDimensions) {
                                pageOffset = (_pageController.page ?? 0.0) - index;
                              } else {
                                pageOffset = _currentIndex.toDouble() - index;
                              }

                              // Calculate animation offset values based on transition selection
                              double dx = 0.0;
                              double dy = 0.0;
                              double opacity = 1.0;
                              double scale = 1.0;
                              double blurValue = 0.0;

                              switch (slide.transition) {
                                case 'Cross Dissolve':
                                  dx = -pageOffset * width;
                                  opacity = (1.0 - pageOffset.abs()).clamp(0.0, 1.0);
                                  break;
                                case 'Soft Fade':
                                  dx = -pageOffset * width;
                                  opacity = (1.0 - pageOffset.abs()).clamp(0.0, 1.0);
                                  scale = (1.0 - 0.08 * pageOffset.abs()).clamp(0.92, 1.0);
                                  break;
                                case 'Wipe Down':
                                  dx = -pageOffset * width;
                                  dy = pageOffset * height;
                                  break;
                                case 'Sacred Bloom':
                                  dx = -pageOffset * width;
                                  opacity = (1.0 - pageOffset.abs()).clamp(0.0, 1.0);
                                  scale = (1.0 + 0.12 * (1.0 - pageOffset.abs())).clamp(1.0, 1.12);
                                  blurValue = (15.0 * pageOffset.abs()).clamp(0.0, 15.0);
                                  break;
                                default:
                                  // Standard slide scroll transition
                                  break;
                              }

                              Widget mainContent = Stack(
                                children: [
                                  // Base Background Color & Image Layer (Repaint Isolated)
                                  Positioned.fill(
                                    child: RepaintBoundary(
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Container(
                                              color: Color(slide.bgColorValue),
                                            ),
                                          ),
                                          if (slide.bgImageBytes != null && slide.bgImageBytes!.isNotEmpty)
                                            Positioned.fill(
                                              child: Opacity(
                                                opacity: slide.opacity,
                                                child: slide.blur == 0.0
                                                    ? Image.memory(
                                                        slide.bgImageBytes!,
                                                        fit: BoxFit.cover,
                                                        filterQuality: FilterQuality.low,
                                                        errorBuilder: (c, e, s) => const SizedBox(),
                                                      )
                                                    : ImageFiltered(
                                                        imageFilter: ImageFilter.blur(
                                                          sigmaX: slide.blur,
                                                          sigmaY: slide.blur,
                                                        ),
                                                        child: Image.memory(
                                                          slide.bgImageBytes!,
                                                          fit: BoxFit.cover,
                                                          filterQuality: FilterQuality.low,
                                                          errorBuilder: (c, e, s) => const SizedBox(),
                                                        ),
                                                      ),
                                              ),
                                            )
                                          else if (slide.imageUrl.isNotEmpty)
                                            Positioned.fill(
                                              child: Opacity(
                                                opacity: slide.opacity,
                                                child: slide.blur == 0.0
                                                    ? (slide.imageUrl.startsWith('data:')
                                                        ? Image.memory(
                                                            _decodeDataUrl(slide.imageUrl),
                                                            fit: BoxFit.cover,
                                                            filterQuality: FilterQuality.low,
                                                            errorBuilder: (c, e, s) => const SizedBox(),
                                                          )
                                                        : Image.network(
                                                            slide.imageUrl,
                                                            fit: BoxFit.cover,
                                                            filterQuality: FilterQuality.low,
                                                            errorBuilder: (c, e, s) => const SizedBox(),
                                                          ))
                                                    : ImageFiltered(
                                                        imageFilter: ImageFilter.blur(
                                                          sigmaX: slide.blur,
                                                          sigmaY: slide.blur,
                                                        ),
                                                        child: slide.imageUrl.startsWith('data:')
                                                            ? Image.memory(
                                                                _decodeDataUrl(slide.imageUrl),
                                                                fit: BoxFit.cover,
                                                                filterQuality: FilterQuality.low,
                                                                errorBuilder: (c, e, s) => const SizedBox(),
                                                              )
                                                            : Image.network(
                                                                slide.imageUrl,
                                                                fit: BoxFit.cover,
                                                                filterQuality: FilterQuality.low,
                                                                errorBuilder: (c, e, s) => const SizedBox(),
                                                              ),
                                                      ),
                                              ),
                                            ),
                                          // Spiritual purple overlay blending
                                          if (slide.imageUrl.isNotEmpty)
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: Container(
                                                  color: SacredColors.primary.withValues(alpha: 0.20),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Logo
                                  if (slide.logoUrl != null && slide.logoUrl!.isNotEmpty)
                                    Positioned(
                                      left: slide.logoX * width,
                                      top: slide.logoY * height,
                                      width: slide.logoSize * (width / 960.0),
                                      height: slide.logoSize * (width / 960.0),
                                      child: slide.logoUrl!.startsWith('data:')
                                          ? Image.memory(_decodeDataUrl(slide.logoUrl!), fit: BoxFit.contain)
                                          : Image.network(slide.logoUrl!, fit: BoxFit.contain),
                                    ),

                                   // Content Layer
                                  Positioned.fill(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final double w = constraints.maxWidth;
                                        final double h = constraints.maxHeight;
                                        final double scale = w / 960.0;

                                        // ── PPTX imported: full-fidelity shape renderer ──
                                        if (slide.pptxShapes.isNotEmpty) {
                                          return PptxSlideRenderer(
                                            slide: slide,
                                            width: w,
                                            height: h,
                                          );
                                        }

                                        // ── Normal slide: same layout as preview canvas ──
                                        final hasSubtitle = slide.subtitle.trim().isNotEmpty;

                                        return Stack(
                                          children: [
                                            Positioned(
                                              left: (slide.textX * w) + (48.0 * scale),
                                              top: (slide.textY * h) + (32.0 * scale),
                                              width: w - (96.0 * scale),
                                              height: h - (64.0 * scale),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (slide.title.isNotEmpty)
                                                    Text(
                                                      slide.title,
                                                      textAlign: slide.alignment,
                                                      maxLines: 3,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.getFont(
                                                        AppSettings.instance.fontFamily,
                                                        textStyle: TextStyle(
                                                          fontSize: slide.titleFontSize * scale,
                                                          color: Color(slide.textColorValue),
                                                          fontWeight: slide.isBold ? FontWeight.bold : FontWeight.normal,
                                                          fontStyle: slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                                          shadows: const [
                                                            Shadow(
                                                              color: Colors.black54,
                                                              offset: Offset(0, 6),
                                                              blurRadius: 12,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  if (hasSubtitle && !slide.id.startsWith('imported_')) ...[
                                                    SizedBox(height: 16.0 * scale),
                                                    Container(
                                                      width: 60.0 * scale,
                                                      height: (2.0 * scale).clamp(2, 6),
                                                      decoration: BoxDecoration(
                                                        color: SacredColors.secondaryContainer,
                                                        borderRadius: BorderRadius.circular(999),
                                                      ),
                                                    ),
                                                  ],
                                                  if (hasSubtitle)
                                                    SizedBox(height: 16.0 * scale),
                                                  if (hasSubtitle)
                                                    Expanded(
                                                      child: SingleChildScrollView(
                                                        child: Text(
                                                          slide.subtitle,
                                                          textAlign: slide.alignment,
                                                          style: GoogleFonts.inter(
                                                            textStyle: TextStyle(
                                                              fontSize: slide.subtitleFontSize * scale,
                                                              color: Color(slide.textColorValue).withValues(alpha: 0.9),
                                                              fontStyle: slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                                              height: 1.4,
                                                              shadows: const [
                                                                Shadow(
                                                                  color: Colors.black54,
                                                                  offset: Offset(0, 4),
                                                                  blurRadius: 8,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),

                                  // Logo Layer
                                  if (slide.logoUrl != null && slide.logoUrl!.isNotEmpty)
                                    Positioned.fill(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final double w = constraints.maxWidth;
                                          final double h = constraints.maxHeight;
                                          final double logoSize = slide.logoSize;
                                          final double scale = w / 960.0;
                                          final double scaledLogoSize = (logoSize * scale).clamp(10.0, w);
                                          final double left = (slide.logoX * w).clamp(0.0, w - scaledLogoSize);
                                          final double top = (slide.logoY * h).clamp(0.0, h - scaledLogoSize);

                                          return Stack(
                                            children: [
                                              Positioned(
                                                left: left,
                                                top: top,
                                                width: scaledLogoSize,
                                                height: scaledLogoSize,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: slide.logoUrl!.startsWith('data:')
                                                      ? Image.memory(
                                                          _decodeDataUrl(slide.logoUrl!),
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (c, e, s) => const SizedBox(),
                                                        )
                                                      : (slide.logoUrl!.startsWith('assets/')
                                                          ? Image.asset(
                                                              slide.logoUrl!,
                                                              fit: BoxFit.contain,
                                                              errorBuilder: (c, e, s) => const SizedBox(),
                                                            )
                                                          : Image.network(
                                                              slide.logoUrl!,
                                                              fit: BoxFit.contain,
                                                              errorBuilder: (c, e, s) => const SizedBox(),
                                                            )),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              );

                              Widget transformedWidget = Transform.translate(
                                offset: Offset(dx, dy),
                                child: Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: mainContent,
                                  ),
                                ),
                              );

                              if (blurValue > 0.0) {
                                transformedWidget = ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: blurValue,
                                    sigmaY: blurValue,
                                  ),
                                  child: transformedWidget,
                                );
                              }

                              return transformedWidget;
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              // Left/Right invisible tap areas for easy touchscreen slide navigation
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.15,
                child: GestureDetector(
                  onTap: () {
                    _prevSlide();
                  },
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox(),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: MediaQuery.of(context).size.width * 0.15,
                child: GestureDetector(
                  onTap: () {
                    _nextSlide();
                  },
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox(),
                ),
              ),

              // Floating Controls Overlay (Fade Transition)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    children: [
                      // Floating Section Notes Card on the left
                      Positioned(
                        left: 24,
                        top: 24,
                        bottom: 120, // leave space for bottom controls
                        width: 280,
                        child: ListenableBuilder(
                          listenable: AppSettings.instance,
                          builder: (context, _) {
                            if (slides.isEmpty || _currentIndex >= slides.length) return const SizedBox.shrink();
                            final currentSlide = slides[_currentIndex];
                            final sectionId = currentSlide.sectionId;
                            
                            // Find the section this slide belongs to
                            final sections = AppSettings.instance.activeSections;
                            final sectionIdx = sections.indexWhere(
                              (s) => s.id == sectionId || s.slideIds.contains(currentSlide.id),
                            );
                            final section = sectionIdx >= 0 ? sections[sectionIdx] : null;

                            final notes = section?.notes ?? '';
                            if (notes.isEmpty) return const SizedBox.shrink();

                            final accentColor = section != null ? getSectionColor(getSectionTypeFromName(section.name), isDarkMode: true) : Colors.blue;

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: accentColor.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.notes, color: accentColor, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${section!.name.toUpperCase()} NOTES',
                                              style: GoogleFonts.inter(
                                                color: accentColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(color: Colors.white24, height: 1),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Text(
                                            notes,
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 13,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Exit Fullscreen Button in top right
                      Positioned(
                        top: 24,
                        right: 24,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.4),
                              child: IconButton(
                                icon: const Icon(Icons.close_fullscreen, color: Colors.white, size: 24),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                tooltip: 'Exit Fullscreen',
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Floating Control Bar at the bottom
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 1.0,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous, color: Colors.white, size: 20),
                                      onPressed: _currentIndex > 0 ? _prevSlide : null,
                                      disabledColor: Colors.white24,
                                      tooltip: 'Previous Slide',
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Slide ${_currentIndex + 1} of ${slides.length}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next, color: Colors.white, size: 20),
                                      onPressed: _currentIndex < slides.length - 1 ? _nextSlide : null,
                                      disabledColor: Colors.white24,
                                      tooltip: 'Next Slide',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}
