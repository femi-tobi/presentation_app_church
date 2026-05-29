/// Web (dart:html) implementation — reads the browser's built-in online flag.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> checkConnectivity() async {
  return html.window.navigator.onLine ?? false;
}
