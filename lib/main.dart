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
  if (isAudience) {
    // Initialize presentation controller as audience client process
    PresentationController.instance.initialize([], [], 0, isAudience: true);
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
