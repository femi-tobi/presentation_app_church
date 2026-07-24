import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';
import 'presentation_controller.dart';
import 'dashboard_page.dart';

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

  @override
  void initState() {
    super.initState();
    // Enter native borderless fullscreen and topmost mode
    _channel.invokeMethod('setFullscreen', {'fullscreen': true}).catchError((_) {});
  }

  @override
  void dispose() {
    // Restore original window style and topmost state
    _channel.invokeMethod('setFullscreen', {'fullscreen': false}).catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PresentationController.instance,
      builder: (context, _) {
        final pc = PresentationController.instance;
        final slides = pc.slides;
        final index = pc.liveIndex;

        if (slides.isEmpty || index >= slides.length) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white24),
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
                if (pc.mode != PresentationMode.locked) pc.next();
                return null;
              }),
              PrevIntent: CallbackAction<PrevIntent>(onInvoke: (_) {
                if (pc.mode != PresentationMode.locked) pc.prev();
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
                    return Stack(
                      children: [
                        // Slide Background
                        Positioned.fill(
                          child: slide.imageUrl.isNotEmpty
                              ? Image.memory(
                                  decodeDataUrl(slide.imageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    color: Color(slide.bgColorValue),
                                  ),
                                )
                              : Container(
                                  color: Color(slide.bgColorValue),
                                ),
                        ),

                        // Overlay Opacity & Blur
                        if (slide.opacity > 0.0)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(slide.opacity),
                            ),
                          ),

                        // Lyrics / Content Layout
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 48.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (slide.title.isNotEmpty) ...[
                                  Text(
                                    slide.title,
                                    style: GoogleFonts.inter(
                                      fontSize: slide.titleFontSize,
                                      fontWeight: slide.isBold ? FontWeight.bold : FontWeight.normal,
                                      fontStyle: slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                      color: Colors.white70,
                                    ),
                                    textAlign: slide.alignment,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                Text(
                                  slide.subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: slide.subtitleFontSize,
                                    fontWeight: slide.isBold ? FontWeight.bold : FontWeight.normal,
                                    fontStyle: slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                  textAlign: slide.alignment,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
