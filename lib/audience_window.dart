import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';
import 'presentation_controller.dart';
import 'dashboard_page.dart'; // SacredColors
import 'pptx_slide_renderer.dart';

class CloseIntent extends Intent {
  const CloseIntent();
}
class NextIntent extends Intent {
  const NextIntent();
}
class PrevIntent extends Intent {
  const PrevIntent();
}
class FirstIntent extends Intent {
  const FirstIntent();
}
class LastIntent extends Intent {
  const LastIntent();
}

class AudienceWindow extends StatefulWidget {
  const AudienceWindow({super.key});

  @override
  State<AudienceWindow> createState() => _AudienceWindowState();
}

class _AudienceWindowState extends State<AudienceWindow> {
  static const _channel = MethodChannel('window_control');
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    final sessId = PresentationController.instance.currentSessionId;
    debugPrint('[PRESENTATION][session=$sessId] AudienceWindow initState');
    // Enter native borderless fullscreen and topmost mode only for standalone audience process
    if (PresentationController.instance.isAudienceProcess) {
      _channel.invokeMethod('setFullscreen', {'fullscreen': true}).catchError((e) {
        debugPrint('[PRESENTATION][session=$sessId] setFullscreen error: $e');
      });
      PresentationController.instance.addListener(_onControllerChanged);
      // Run initial check for visibility based on starting mode
      _onControllerChanged();
    }
  }

  void _onControllerChanged() {
    final mode = PresentationController.instance.mode;
    final sessId = PresentationController.instance.currentSessionId;
    if (mode == PresentationMode.locked) {
      debugPrint('[PRESENTATION][session=$sessId] AudienceWindow: Locking presentation, calling hideWindow');
      _channel.invokeMethod('hideWindow').catchError((e) {
        debugPrint('[PRESENTATION][session=$sessId] hideWindow error: $e');
      });
    } else {
      debugPrint('[PRESENTATION][session=$sessId] AudienceWindow: Mode active ($mode), calling showWindow');
      _channel.invokeMethod('showWindow').catchError((e) {
        debugPrint('[PRESENTATION][session=$sessId] showWindow error: $e');
      });
    }
  }

  @override
  void dispose() {
    final sessId = PresentationController.instance.currentSessionId;
    debugPrint('[PRESENTATION][session=$sessId] AudienceWindow dispose');
    // Restore original window style and topmost state
    if (PresentationController.instance.isAudienceProcess) {
      PresentationController.instance.removeListener(_onControllerChanged);
      _channel.invokeMethod('setFullscreen', {'fullscreen': false}).catchError((e) {
        debugPrint('[PRESENTATION][session=$sessId] restore setFullscreen error: $e');
      });
    }
    super.dispose();
  }

  TextStyle _getSafeFont(String fontFamily, {required double fontSize, required FontWeight fontWeight, FontStyle? fontStyle, Color? color, double? height, double? letterSpacing}) {
    try {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    } catch (_) {
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: PresentationController.instance,
      builder: (context, _) {
        final pc = PresentationController.instance;
        final slides = pc.slides;
        final index = pc.liveIndex;
        final sessId = pc.currentSessionId;

        _buildCount++;
        debugPrint('[PRESENTATION][session=$sessId] AudienceWindow build #$_buildCount: index=$index, slides.length=${slides.length}');
        if (slides.isNotEmpty && index < slides.length) {
          final slide = slides[index];
          final shapesInfo = slide.pptxShapes.map((sh) => 'Shape(text="${sh.text}", color=0x${sh.colorValue.toRadixString(16)}, rect=[${sh.left.toStringAsFixed(3)}, ${sh.top.toStringAsFixed(3)}, ${sh.width.toStringAsFixed(3)}, ${sh.height.toStringAsFixed(3)}])').toList();
          debugPrint('[PRESENTATION][session=$sessId] AudienceWindow build #$_buildCount: Slide ID=${slide.id}, title="${slide.title}", shapesCount=${slide.pptxShapes.length}, bgColor=0x${slide.bgColorValue.toRadixString(16)}, shapes=$shapesInfo');
        }

        if (slides.isEmpty || index >= slides.length) {
          // Diagnostic: show a loading screen instead of black to help diagnose issues
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D1A),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white54),
                  const SizedBox(height: 24),
                  Text(
                    slides.isEmpty
                        ? 'Loading slides... (${pc.slides.length} loaded)'
                        : 'Slide index out of range ($index / ${slides.length})',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        final slide = slides[index];

        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.escape): const CloseIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowRight): const NextIntent(),
            const SingleActivator(LogicalKeyboardKey.space): const NextIntent(),
            const SingleActivator(LogicalKeyboardKey.enter): const NextIntent(),
            const SingleActivator(LogicalKeyboardKey.pageDown): const NextIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): const PrevIntent(),
            const SingleActivator(LogicalKeyboardKey.pageUp): const PrevIntent(),
            const SingleActivator(LogicalKeyboardKey.home): const FirstIntent(),
            const SingleActivator(LogicalKeyboardKey.end): const LastIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              CloseIntent: CallbackAction<CloseIntent>(onInvoke: (_) => exit(0)),
              NextIntent: CallbackAction<NextIntent>(onInvoke: (_) {
                if (pc.mode != PresentationMode.locked) {
                  if (pc.bibleOverlaySlide != null) {
                    pc.navigateBibleVerse(true);
                  } else {
                    pc.next();
                  }
                }
                return null;
              }),
              PrevIntent: CallbackAction<PrevIntent>(onInvoke: (_) {
                if (pc.mode != PresentationMode.locked) {
                  if (pc.bibleOverlaySlide != null) {
                    pc.navigateBibleVerse(false);
                  } else {
                    pc.prev();
                  }
                }
                return null;
              }),
              FirstIntent: CallbackAction<FirstIntent>(onInvoke: (_) {
                if (pc.mode != PresentationMode.locked) pc.goFirst();
                return null;
              }),
              LastIntent: CallbackAction<LastIntent>(onInvoke: (_) {
                if (pc.mode != PresentationMode.locked) pc.goLast();
                return null;
              }),
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: ListenableBuilder(
                  listenable: slide,
                  builder: (context, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final double width = constraints.maxWidth;
                        final double height = constraints.maxHeight;
                        final double scale = width / 960.0;

                        const double slideAspectRatio = 16.0 / 9.0;

                        double renderWidth = width;
                        double renderHeight = width / slideAspectRatio;
                        if (renderHeight > height) {
                          renderHeight = height;
                          renderWidth = height * slideAspectRatio;
                        }

                        debugPrint('[PRESENTATION][session=$sessId] LayoutBuilder constraints: minW=${constraints.minWidth}, maxW=${constraints.maxWidth}, minH=${constraints.minHeight}, maxH=${constraints.maxHeight}');
                        return SizedBox(
                          width: width,
                          height: height,
                          child: Stack(
                            children: [
                              // Slide Background Stack matching the preview canvas
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: Stack(
                                    children: [
                                      // Base Background Color
                                      Positioned.fill(
                                        child: Container(
                                          color: Color(slide.bgColorValue),
                                        ),
                                      ),
                                      // Background Image Layer with custom opacity and blurs
                                      if (slide.imageUrl.isNotEmpty)
                                        Positioned.fill(
                                          child: Opacity(
                                            opacity: slide.opacity,
                                            child: slide.blur == 0.0
                                                ? (slide.imageUrl.startsWith('data:')
                                                    ? Image.memory(
                                                        decodeDataUrl(slide.imageUrl),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (c, e, s) => const SizedBox(),
                                                      )
                                                    : Image.network(
                                                        slide.imageUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (c, e, s) => const SizedBox(),
                                                      ))
                                                : ImageFiltered(
                                                    imageFilter: ImageFilter.blur(
                                                      sigmaX: slide.blur,
                                                      sigmaY: slide.blur,
                                                    ),
                                                    child: slide.imageUrl.startsWith('data:')
                                                        ? Image.memory(
                                                            decodeDataUrl(slide.imageUrl),
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (c, e, s) => const SizedBox(),
                                                          )
                                                        : Image.network(
                                                            slide.imageUrl,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (c, e, s) => const SizedBox(),
                                                          ),
                                                  ),
                                          ),
                                        ),
                                      // Purple spiritual overlay blending
                                      if (slide.imageUrl.isNotEmpty && !slide.imageUrl.startsWith('data:'))
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
                                  width: slide.logoSize * scale,
                                  height: slide.logoSize * scale,
                                  child: slide.logoUrl!.startsWith('data:')
                                      ? Image.memory(decodeDataUrl(slide.logoUrl!), fit: BoxFit.contain)
                                      : Image.network(slide.logoUrl!, fit: BoxFit.contain),
                                ),

                              // Lower Third Layout Mode
                              if (AppSettings.instance.useLowerThird)
                                Positioned(
                                  left: 32,
                                  right: 32,
                                  bottom: 32,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (slide.title.isNotEmpty)
                                          Text(
                                            slide.title,
                                            style: GoogleFonts.inter(
                                              fontSize: slide.titleFontSize * 0.7,
                                              fontWeight: FontWeight.bold,
                                              color: Color(slide.textColorValue).withOpacity(0.8),
                                            ),
                                          ),
                                        Text(
                                          slide.subtitle,
                                          style: GoogleFonts.inter(
                                            fontSize: slide.subtitleFontSize * 0.75,
                                            color: Color(slide.textColorValue),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              // Picture in Picture Overlay Layout Mode
                              else if (AppSettings.instance.usePiP)
                                Positioned(
                                  right: 24,
                                  top: 24,
                                  width: width * 0.35,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Color(slide.textColorValue).withOpacity(0.3)),
                                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          slide.title,
                                          style: GoogleFonts.inter(fontSize: 12, color: Color(slide.textColorValue).withOpacity(0.6)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          slide.subtitle,
                                          style: GoogleFonts.inter(fontSize: 14, color: Color(slide.textColorValue)),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (slide.pptxShapes.isNotEmpty)
                                Positioned.fill(
                                  child: Center(
                                    child: SizedBox(
                                      width: renderWidth,
                                      height: renderHeight,
                                      child: AudienceSlideView(
                                        slide: slide,
                                        width: renderWidth,
                                        height: renderHeight,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                 // Standard Fullscreen Layout
                                Positioned(
                                  left: 64.0 * scale,
                                  top: 32.0 * scale,
                                  width: width - 128.0 * scale,
                                  height: height - 64.0 * scale,
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
                                              fontWeight: slide.isBold ? FontWeight.bold : FontWeight.normal,
                                              fontStyle: slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                              color: Color(slide.textColorValue),
                                              shadows: const [
                                                Shadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 6),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (slide.subtitle.trim().isNotEmpty && !slide.id.startsWith('imported_')) ...[
                                        SizedBox(height: 8.0 * scale),
                                        Container(
                                          width: 48.0 * scale,
                                          height: (2.0 * scale).clamp(1.0, 6.0),
                                          color: SacredColors.secondaryContainer,
                                        ),
                                      ],
                                      if (slide.subtitle.trim().isNotEmpty)
                                        SizedBox(height: 8.0 * scale),
                                      if (slide.subtitle.trim().isNotEmpty)
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Text(
                                              slide.subtitle,
                                              textAlign: slide.alignment,
                                              style: GoogleFonts.inter(
                                                textStyle: TextStyle(
                                                  fontSize: slide.subtitleFontSize * scale,
                                                  fontWeight: slide.isBold ? FontWeight.bold : FontWeight.normal,
                                                  fontStyle: slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                                  color: Color(slide.textColorValue).withValues(alpha: 0.9),
                                                  height: 1.4,
                                                  shadows: const [
                                                    Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 4),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              // Countdown Timer Overlay Layer
                              if (AppSettings.instance.showTimerOnAudience)
                                ListenableBuilder(
                                  listenable: AppSettings.instance,
                                  builder: (context, _) {
                                    final settings = AppSettings.instance;
                                    if (!settings.isTimerRunning || settings.timerRemainingSeconds <= 0) {
                                      return const SizedBox.shrink();
                                    }
                                    final minutes = (settings.timerRemainingSeconds / 60).floor().toString().padLeft(2, '0');
                                    final seconds = (settings.timerRemainingSeconds % 60).toString().padLeft(2, '0');
                                    return Positioned(
                                      right: 24,
                                      top: 24,
                                      child: Container(
                                        width: settings.timerOverlayWidth,
                                        height: settings.timerOverlayHeight,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.85),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Color(slide.textColorValue).withOpacity(0.3)),
                                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.timer, color: Colors.orangeAccent, size: settings.timerOverlayFontSize * 0.9),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$minutes:$seconds',
                                              style: GoogleFonts.firaCode(
                                                fontWeight: FontWeight.bold,
                                                fontSize: settings.timerOverlayFontSize,
                                                color: Colors.orangeAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              if (pc.bibleOverlaySlide != null && pc.bibleOverlayTarget != 'obs')
                                 Positioned.fill(
                                   child: pc.isBibleFullscreen
                                       ? Container(
                                           color: Color(pc.bibleOverlaySlide!.bgColorValue),
                                           padding: EdgeInsets.symmetric(horizontal: 64 * scale, vertical: 48 * scale),
                                           child: Column(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: [
                                               Row(
                                                 mainAxisAlignment: MainAxisAlignment.center,
                                                 children: [
                                                   Icon(Icons.menu_book, color: const Color(0xFFFED65B), size: 44 * scale),
                                                   SizedBox(width: 14 * scale),
                                                   Text(
                                                     pc.bibleOverlaySlide!.title,
                                                     style: _getSafeFont(
                                                       settings.bibleFontFamily,
                                                       fontSize: 36 * scale,
                                                       fontWeight: FontWeight.w800,
                                                       color: const Color(0xFFFED65B),
                                                       letterSpacing: 1.0,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                               SizedBox(height: 40 * scale),
                                               Text(
                                                 pc.bibleOverlaySlide!.subtitle,
                                                 textAlign: TextAlign.center,
                                                 style: _getSafeFont(
                                                   settings.bibleFontFamily,
                                                   fontSize: settings.bibleFontSize * scale,
                                                   fontWeight: settings.bibleIsBold ? FontWeight.bold : FontWeight.w500,
                                                   fontStyle: settings.bibleIsItalic ? FontStyle.italic : FontStyle.normal,
                                                   color: Color(settings.bibleTextColor),
                                                   height: 1.5,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         )
                                       : Align(
                                           alignment: Alignment.bottomCenter,
                                           child: Padding(
                                             padding: EdgeInsets.symmetric(horizontal: 48 * scale, vertical: 48 * scale),
                                             child: Container(
                                               padding: EdgeInsets.all(24 * scale),
                                               decoration: BoxDecoration(
                                                 color: Color(settings.bibleL3BgColor),
                                                 borderRadius: BorderRadius.circular(settings.bibleL3BorderRadius * scale),
                                                 border: settings.bibleL3ShowBorder
                                                     ? Border.all(color: Colors.white24, width: 2)
                                                     : null,
                                                 boxShadow: [
                                                   BoxShadow(
                                                     color: Colors.black54,
                                                     blurRadius: 15 * scale,
                                                     spreadRadius: 2 * scale,
                                                   )
                                                 ],
                                               ),
                                               child: Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   Row(
                                                     children: [
                                                       Icon(Icons.menu_book, color: const Color(0xFFFED65B), size: 24 * scale),
                                                       SizedBox(width: 10 * scale),
                                                       Text(
                                                         pc.bibleOverlaySlide!.title,
                                                         style: _getSafeFont(
                                                           settings.bibleFontFamily,
                                                           fontSize: 20 * scale,
                                                           fontWeight: FontWeight.w800,
                                                           color: const Color(0xFFFED65B),
                                                           letterSpacing: 1.0,
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                   SizedBox(height: 12 * scale),
                                                   Text(
                                                     pc.bibleOverlaySlide!.subtitle,
                                                     style: _getSafeFont(
                                                       settings.bibleFontFamily,
                                                       fontSize: settings.bibleL3FontSize * scale,
                                                       fontWeight: settings.bibleIsBold ? FontWeight.bold : FontWeight.w500,
                                                       fontStyle: settings.bibleIsItalic ? FontStyle.italic : FontStyle.normal,
                                                       color: Color(settings.bibleL3TextColor),
                                                       height: 1.4,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                           ),
                                         ),
                                 ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AudienceSlideView extends StatelessWidget {
  final SlideData slide;
  final double width;
  final double height;

  const AudienceSlideView({
    super.key,
    required this.slide,
    required this.width,
    required this.height,
  });

  double _ptToPx(double fontPt) {
    final slideH = slide.pptxSlideHeightEmu > 0
        ? slide.pptxSlideHeightEmu
        : 6858000.0;
    return (fontPt * 12700.0 / slideH * height).clamp(4.0, height * 0.5);
  }

  static Uint8List _decodeUri(String dataUri) {
    return decodeDataUrl(dataUri);
  }

  static Alignment _toAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.center:  return Alignment.topCenter;
      case TextAlign.right:   return Alignment.topRight;
      default:                return Alignment.topLeft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Background ──
            Positioned.fill(
              child: RepaintBoundary(child: _buildBackground()),
            ),

            // ── Shapes ──
            for (final shape in slide.pptxShapes)
              Positioned(
                left: shape.left * width,
                top: shape.top * height,
                width: shape.width * width,
                height: shape.height * height,
                child: _buildShape(shape),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (slide.bgImageBytes != null && slide.bgImageBytes!.isNotEmpty) {
      return Image.memory(
        slide.bgImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(color: Color(slide.bgColorValue)),
      );
    }
    if (slide.imageUrl.isNotEmpty) {
      return slide.imageUrl.startsWith('data:')
          ? Image.memory(
              _decodeUri(slide.imageUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: Color(slide.bgColorValue)),
            )
          : Image.network(
              slide.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: Color(slide.bgColorValue)),
            );
    }
    return ColoredBox(color: Color(slide.bgColorValue));
  }

  Widget _buildShape(PptxShape shape) {
    if (shape.imageDataUri.isNotEmpty) {
      if (shape.imageBytes != null && shape.imageBytes!.isNotEmpty) {
        return Image.memory(
          shape.imageBytes!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return Image.memory(
        _decodeUri(shape.imageDataUri),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (shape.fillColorValue != 0x00000000)
          Positioned.fill(
            child: ColoredBox(color: Color(shape.fillColorValue)),
          ),
        if (shape.text.isNotEmpty)
          Positioned.fill(
            child: _buildTextBox(shape),
          ),
      ],
    );
  }

  Widget _buildTextBox(PptxShape shape) {
    final double pxSize = _ptToPx(shape.fontSize);

    final baseStyle = TextStyle(
      fontSize: pxSize,
      fontWeight: shape.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: shape.isItalic ? FontStyle.italic : FontStyle.normal,
      color: Color(shape.colorValue),
      height: 1.15,
      shadows: const [
        Shadow(
          color: Color(0x22000000),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );

    TextStyle textStyle;
    try {
      textStyle = GoogleFonts.getFont(shape.fontFamily, textStyle: baseStyle);
    } catch (_) {
      textStyle = baseStyle.copyWith(fontFamily: shape.fontFamily);
    }

    return Align(
      alignment: _toAlignment(shape.align),
      child: Text(
        shape.text,
        textAlign: shape.align,
        softWrap: true,
        style: textStyle,
      ),
    );
  }
}
