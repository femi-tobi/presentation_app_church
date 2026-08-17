import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_page.dart';
import 'settings_state.dart';
import 'presentation_controller.dart';
import 'audience_window.dart';
import 'connectors/remote_control_service.dart';

/// Global navigator key for remote-triggered navigation
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[Main Startup] resolvedExecutable: ${Platform.resolvedExecutable}, args: $args');
  
  // Enable runtime fetching of Google Fonts to load fonts dynamically when online
  GoogleFonts.config.allowRuntimeFetching = true;

  // Global handler for synchronous errors
  FlutterError.onError = (FlutterErrorDetails details) {
    final errStr = details.exception.toString();
    if (errStr.contains('Failed to load font') || errStr.contains('fonts.gstatic.com')) {
      debugPrint('Silently caught and ignored font loading exception: ${details.exception}');
      return; // Handled, fallback automatically
    }
    FlutterError.presentError(details);
  };

  // Global handler for asynchronous errors (like background HTTP fetch crashes)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final errStr = error.toString();
    if (errStr.contains('Failed to load font') || errStr.contains('fonts.gstatic.com') || errStr.contains('ClientException')) {
      debugPrint('Silently caught and ignored async font fetching exception: $error');
      return true; // Handled
    }
    return false; // Propagate other exceptions
  };
  
  await AppSettings.instance.loadSettings();

  final bool isAudience = args.contains('--audience');
  String sessionId = 'unknown';
  final sessIdx = args.indexOf('--session-id');
  if (sessIdx != -1 && sessIdx + 1 < args.length) {
    sessionId = args[sessIdx + 1];
  }
  PresentationController.instance.setSessionId(sessionId);

  if (isAudience) {
    int port = 4321;
    final portIdx = args.indexOf('--port');
    if (portIdx != -1 && portIdx + 1 < args.length) {
      port = int.tryParse(args[portIdx + 1]) ?? 4321;
    }
    PresentationController.instance.serverPort = port;

    // Log startup info
    debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_PROCESS_STARTUP');
    debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_CURRENT_DIRECTORY: ${Directory.current.path}');
    debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_EXECUTABLE_PATH: ${Platform.resolvedExecutable}');

    // --- Audience process: load initial state from the temp handoff file ---
    // The parent process writes this file immediately before spawning us, so it
    // is always available and avoids any TCP timing race condition.
    List<SlideData> initialSlides = [];
    List<SlideSection> initialSections = [];
    int initialIndex = 0;
    try {
      final tmp = Platform.environment['TEMP'] ??
          Platform.environment['TMP'] ??
          Directory.systemTemp.path;
      final handoffFile = File('$tmp\\livedeck_handoff.json');
      debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_HANDOFF_PATH: ${handoffFile.path}');
      debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_HANDOFF_EXISTS: ${handoffFile.existsSync()}');
      if (handoffFile.existsSync()) {
        final size = handoffFile.lengthSync();
        debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_HANDOFF_SIZE: $size bytes');
        final content = handoffFile.readAsStringSync();
        debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_HANDOFF_PREVIEW: ${content.substring(0, content.length > 200 ? 200 : content.length)}...');
        
        final raw = json.decode(content) as Map<String, dynamic>;
        initialIndex = (raw['liveIndex'] as num?)?.toInt() ?? 0;
        final rawSlides = raw['slides'] as List<dynamic>? ?? [];
        initialSlides = rawSlides
            .map((s) => SlideData.fromJson(s as Map<String, dynamic>))
            .toList();
        debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_HANDOFF_PARSED: slidesCount=${initialSlides.length}, liveIndex=$initialIndex');
      } else {
        debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_HANDOFF_NOT_FOUND');
      }
    } catch (e) {
      debugPrint('[PRESENTATION][session=$sessionId] AUDIENCE_HANDOFF_ERROR: $e');
    }
    PresentationController.instance.initialize(
      initialSlides,
      initialSections,
      initialIndex,
      isAudience: true,
    );
  } else {
    // Start Remote Control server on startup
    RemoteControlService.instance.start().catchError((_) {});
  }

  runApp(MyApp(isAudience: isAudience));
}

class MyApp extends StatelessWidget {
  final bool isAudience;
  const MyApp({super.key, this.isAudience = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, child) {
        final settings = AppSettings.instance;
        return MaterialApp(
          navigatorKey: isAudience ? null : appNavigatorKey,
          title: isAudience ? 'LiveDeck - Presentation View' : 'LiveDeck',
          debugShowCheckedModeBanner: false,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.primaryColor,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.primaryColor,
              brightness: Brightness.dark,
            ),
          ),
          home: isAudience ? const AudienceWindow() : const DashboardPage(),
        );
      },
    );
  }
}
