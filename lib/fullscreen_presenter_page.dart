import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';
import 'dashboard_page.dart'; // For SacredColors / Shadows / Typography

/// Safely decode a base64 data-URL to bytes.
Uint8List _decodeDataUrl(String dataUrl) {
  try {
    final uriData = Uri.parse(dataUrl).data;
    if (uriData != null) return uriData.contentAsBytes();
  } catch (_) {}
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex != -1) return base64Decode(dataUrl.substring(commaIndex + 1));
  return Uint8List(0);
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
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.pageDown) {
        _nextSlide();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                 event.logicalKey == LogicalKeyboardKey.pageUp) {
        _prevSlide();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      child: Stack(
                        children: [
                          // Background Image Layer with Blur
                          Positioned.fill(
                            child: slide.imageUrl.isEmpty
                                ? Container(color: Colors.black)
                                : ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: slide.blur,
                                      sigmaY: slide.blur,
                                    ),
                                    child: slide.imageUrl.startsWith('data:')
                                        ? Image.memory(
                                            _decodeDataUrl(slide.imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(color: const Color(0xFF0F172A)),
                                          )
                                        : Image.network(
                                            slide.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(color: const Color(0xFF0F172A)),
                                          ),
                                  ),
                          ),

                          // Translucent overlay blending
                          if (slide.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 1.0 - slide.opacity),
                              ),
                            ),

                          // Spiritual purple overlay blending
                          if (slide.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Container(
                                color: SacredColors.primary.withValues(alpha: 0.20),
                              ),
                            ),

                          // Content Layer
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double w = constraints.maxWidth;
                                final double h = constraints.maxHeight;
                                final double left = slide.textX * w;
                                final double top = slide.textY * h;
                                final hasSubtitle = slide.subtitle.trim().isNotEmpty;

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: left,
                                      top: top,
                                      width: w,
                                      height: h,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 80.0, vertical: 48.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              slide.title,
                                              textAlign: slide.alignment,
                                              style: GoogleFonts.getFont(
                                                AppSettings.instance.fontFamily,
                                                textStyle: TextStyle(
                                                  fontSize: 64,
                                                  color: Colors.white,
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
                                            if (hasSubtitle) ...[
                                              const SizedBox(height: 24),
                                              Container(
                                                width: 120,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: SacredColors.secondaryContainer,
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                              ),
                                              Expanded(
                                                child: Center(
                                                  child: Text(
                                                    slide.subtitle,
                                                    textAlign: slide.alignment,
                                                    style: GoogleFonts.inter(
                                                      textStyle: TextStyle(
                                                        fontSize: 28,
                                                        color: Colors.white.withValues(alpha: 0.9),
                                                        fontStyle: FontStyle.italic,
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
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          // Logo Layer — Positioned.fill is required so LayoutBuilder
                          // receives actual canvas dimensions (not zero from Stack).
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
                                              : Image.network(
                                                  slide.logoUrl!,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (c, e, s) => const SizedBox(),
                                                ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                        ],
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
  }
}
