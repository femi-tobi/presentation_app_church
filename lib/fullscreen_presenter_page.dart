import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';
import 'dashboard_page.dart'; // For SacredColors / Shadows / Typography

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
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: slide.blur,
                                sigmaY: slide.blur,
                              ),
                              child: Image.network(
                                slide.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(color: const Color(0xFF0F172A)),
                              ),
                            ),
                          ),

                          // Translucent overlay blending
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 1.0 - slide.opacity),
                            ),
                          ),

                          // Spiritual purple overlay blending
                          Positioned.fill(
                            child: Container(
                              color: SacredColors.primary.withValues(alpha: 0.20),
                            ),
                          ),

                          // Content Layer
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 80.0, vertical: 48.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
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
                                  const SizedBox(height: 24),
                                  Container(
                                    width: 120,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: SacredColors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
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
                                ],
                              ),
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
