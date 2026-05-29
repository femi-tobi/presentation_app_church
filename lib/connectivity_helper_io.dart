/// Native (dart:io) implementation — uses a raw socket connect to Google DNS.
import 'dart:io';

Future<bool> checkConnectivity() async {
  try {
    final socket = await Socket.connect(
      '8.8.8.8',
      53,
      timeout: const Duration(seconds: 3),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
