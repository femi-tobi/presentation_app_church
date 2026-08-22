import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Describes the state of a pending update.
enum UpdateStatus {
  idle,           // No update found or check not done yet
  checking,       // Currently querying GitHub
  available,      // Update found, not yet downloading
  downloading,    // Actively downloading the installer
  readyToInstall, // Installer downloaded, waiting for user to restart
  error,          // Something went wrong
}

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool mandatory;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.mandatory,
  });
}

class AutoUpdateState {
  final UpdateStatus status;
  final UpdateInfo? info;
  final double downloadProgress; // 0.0 – 1.0
  final String? installerPath;
  final String? errorMessage;

  const AutoUpdateState({
    this.status = UpdateStatus.idle,
    this.info,
    this.downloadProgress = 0.0,
    this.installerPath,
    this.errorMessage,
  });

  AutoUpdateState copyWith({
    UpdateStatus? status,
    UpdateInfo? info,
    double? downloadProgress,
    String? installerPath,
    String? errorMessage,
  }) {
    return AutoUpdateState(
      status: status ?? this.status,
      info: info ?? this.info,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      installerPath: installerPath ?? this.installerPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AutoUpdateService extends ChangeNotifier {
  AutoUpdateService._();
  static final AutoUpdateService instance = AutoUpdateService._();

  // ── Configuration ─────────────────────────────────────────────────────────
  // Replace with your actual GitHub username/repo. The service will call the
  // GitHub Releases API to find the latest release tag and download URL.
  static const String _githubOwner = 'YOUR_GITHUB_USERNAME';
  static const String _githubRepo  = 'YOUR_GITHUB_REPO';

  // Asset filename extension to look for in the release assets list.
  static const String _assetNamePattern = '.exe';
  // ──────────────────────────────────────────────────────────────────────────

  AutoUpdateState _state = const AutoUpdateState();
  AutoUpdateState get state => _state;

  Timer? _periodicTimer;
  bool _started = false;

  /// Call once from main() or dashboard initState.
  void start() {
    if (_started) return;
    _started = true;

    // First check after 5 seconds (let the app fully initialize)
    Future.delayed(const Duration(seconds: 5), _checkForUpdate);

    // Re-check every 4 hours while the app is open
    _periodicTimer = Timer.periodic(const Duration(hours: 4), (_) {
      _checkForUpdate();
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    if (_state.status == UpdateStatus.downloading ||
        _state.status == UpdateStatus.readyToInstall) {
      return; // Don't interrupt an active download
    }

    _setState(_state.copyWith(status: UpdateStatus.checking));

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      final url = 'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _setState(_state.copyWith(status: UpdateStatus.idle));
        return;
      }

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (jsonBody['tag_name'] as String? ?? '').replaceFirst('v', '');
      final releaseNotes = jsonBody['body'] as String? ?? '';
      final assets = jsonBody['assets'] as List<dynamic>? ?? [];

      // Find the .exe asset
      String? downloadUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().endsWith(_assetNamePattern)) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (downloadUrl == null || tagName.isEmpty) {
        _setState(_state.copyWith(status: UpdateStatus.idle));
        return;
      }

      if (_isNewerVersion(tagName, currentVersion)) {
        final info = UpdateInfo(
          latestVersion: tagName,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          mandatory: false,
        );
        _setState(_state.copyWith(status: UpdateStatus.available, info: info));
        // Immediately start silent background download
        _downloadInstaller(info);
      } else {
        _setState(_state.copyWith(status: UpdateStatus.idle));
      }
    } catch (e) {
      debugPrint('[AutoUpdate] Check failed: $e');
      _setState(_state.copyWith(status: UpdateStatus.idle));
    }
  }

  Future<void> _downloadInstaller(UpdateInfo info) async {
    try {
      _setState(_state.copyWith(
        status: UpdateStatus.downloading,
        downloadProgress: 0.0,
      ));

      final tempDir = await getTemporaryDirectory();
      final fileName = 'livedeck_update_${info.latestVersion}.exe';
      final filePath = '${tempDir.path}\\$fileName';
      final file = File(filePath);

      final request = http.Request('GET', Uri.parse(info.downloadUrl));
      final response = await request.send().timeout(const Duration(minutes: 10));

      if (response.statusCode != 200) {
        _setState(_state.copyWith(
          status: UpdateStatus.available,
          errorMessage: 'Download failed (HTTP ${response.statusCode})',
        ));
        return;
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _setState(_state.copyWith(downloadProgress: received / total));
        }
      });

      await sink.close();

      _setState(_state.copyWith(
        status: UpdateStatus.readyToInstall,
        installerPath: filePath,
        downloadProgress: 1.0,
      ));
    } catch (e) {
      debugPrint('[AutoUpdate] Download failed: $e');
      _setState(_state.copyWith(
        status: UpdateStatus.available,
        errorMessage: 'Download error: $e',
      ));
    }
  }

  /// Launch the downloaded installer and exit the app.
  Future<void> installAndRestart() async {
    final path = _state.installerPath;
    if (path == null || !File(path).existsSync()) return;

    try {
      // /SILENT flag for Inno Setup — installs without UI prompts
      await Process.start(
        path,
        ['/SILENT', '/CLOSEAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (e) {
      debugPrint('[AutoUpdate] Install launch failed: $e');
    }
  }

  void _setState(AutoUpdateState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Returns true if [candidate] is a strictly higher semver than [current].
  bool _isNewerVersion(String candidate, String current) {
    try {
      final c   = _parseVersion(candidate);
      final cur = _parseVersion(current);
      for (int i = 0; i < 3; i++) {
        if (c[i] > cur[i]) return true;
        if (c[i] < cur[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  List<int> _parseVersion(String v) {
    final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }
}
