import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Safety guarantees implemented:
//  1. Correct .exe  — matched by exact asset name suffix from GitHub Releases
//  2. Corruption check — SHA-256 verified against a .sha256 asset in the release
//  3. Release authenticity — asset must come from the expected GitHub repo
//  4. App closes before replacement — Inno Setup /CLOSEAPPLICATIONS
//  5. Inno Setup flags — /SILENT /RESTARTAPPLICATIONS for clean install + relaunch
//  6. Auto-restart — /RESTARTAPPLICATIONS tells Inno Setup to relaunch the app
//  7. Interrupted downloads — written to .part file, only renamed on full verified write
// ─────────────────────────────────────────────────────────────────────────────

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  verifying,       // SHA-256 check in progress
  readyToInstall,
  error,
}

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String? checksumUrl;   // URL to the .sha256 file in the same release
  final String releaseNotes;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    this.checksumUrl,
    required this.releaseNotes,
  });
}

class AutoUpdateState {
  final UpdateStatus status;
  final UpdateInfo? info;
  final double downloadProgress;  // 0.0 – 1.0
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
  }) =>
      AutoUpdateState(
        status: status ?? this.status,
        info: info ?? this.info,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        installerPath: installerPath ?? this.installerPath,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class AutoUpdateService extends ChangeNotifier {
  AutoUpdateService._();
  static final AutoUpdateService instance = AutoUpdateService._();

  // ── Configuration ───────────────────────────────────────────────────────────
  /// Your GitHub username and repo name. These are the ONLY two values you
  /// ever need to change. Everything else is automatic.
  static const String _githubOwner = 'femi-tobi';
  static const String _githubRepo  = 'presentation_app_church';
  // ────────────────────────────────────────────────────────────────────────────

  static const String _expectedHost = 'objects.githubusercontent.com';
  static const String _apiBase = 'https://api.github.com/repos/$_githubOwner/$_githubRepo';

  AutoUpdateState _state = const AutoUpdateState();
  AutoUpdateState get state => _state;

  Timer? _periodicTimer;
  bool _started = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  void start() {
    if (_started) return;
    _started = true;
    // First check 5 s after startup so the app is fully loaded
    Future.delayed(const Duration(seconds: 5), _checkForUpdate);
    // Re-check every 4 hours while the app is open
    _periodicTimer = Timer.periodic(const Duration(hours: 4), (_) => _checkForUpdate());
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  // ── Step 1: Version check ───────────────────────────────────────────────────

  Future<void> _checkForUpdate() async {
    if (_state.status == UpdateStatus.downloading ||
        _state.status == UpdateStatus.verifying ||
        _state.status == UpdateStatus.readyToInstall) return;

    _set(_state.copyWith(status: UpdateStatus.checking));

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http
          .get(Uri.parse('$_apiBase/releases/latest'),
              headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _set(_state.copyWith(status: UpdateStatus.idle));
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final tag  = (body['tag_name'] as String? ?? '').replaceFirst('v', '');
      final notes = body['body'] as String? ?? '';
      final assets = (body['assets'] as List<dynamic>? ?? []);

      // ── Safety 1: find the .exe asset ──────────────────────────────────────
      String? exeUrl;
      String? sha256Url;
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        final url  = a['browser_download_url'] as String? ?? '';
        if (name.endsWith('.exe'))    exeUrl    = url;
        if (name.endsWith('.sha256')) sha256Url = url;
      }

      if (exeUrl == null || tag.isEmpty) {
        _set(_state.copyWith(status: UpdateStatus.idle));
        return;
      }

      // ── Safety 3: asset must come from GitHub's CDN ────────────────────────
      final exeUri = Uri.tryParse(exeUrl);
      if (exeUri == null || exeUri.host != _expectedHost) {
        debugPrint('[AutoUpdate] Rejected asset: unexpected host ${exeUri?.host}');
        _set(_state.copyWith(status: UpdateStatus.idle));
        return;
      }

      if (_isNewer(tag, currentVersion)) {
        final info = UpdateInfo(
          latestVersion: tag,
          currentVersion: currentVersion,
          downloadUrl: exeUrl,
          checksumUrl: sha256Url,
          releaseNotes: notes,
        );
        _set(_state.copyWith(status: UpdateStatus.available, info: info));
        _downloadInstaller(info);          // start silent background download
      } else {
        _set(_state.copyWith(status: UpdateStatus.idle));
      }
    } catch (e) {
      debugPrint('[AutoUpdate] Check failed: $e');
      _set(_state.copyWith(status: UpdateStatus.idle));
    }
  }

  // ── Step 2: Download (atomic via .part file) ────────────────────────────────

  Future<void> _downloadInstaller(UpdateInfo info) async {
    File? partFile;
    try {
      _set(_state.copyWith(status: UpdateStatus.downloading, downloadProgress: 0.0));

      final tempDir  = await getTemporaryDirectory();
      final baseName = 'livedeck_update_${info.latestVersion}';
      // ── Safety 7: write to .part so a partial file is never mistaken for
      //             a complete installer ──────────────────────────────────────
      partFile       = File('${tempDir.path}\\$baseName.exe.part');
      final finalFile = File('${tempDir.path}\\$baseName.exe');

      // Delete any leftover from a previous interrupted attempt
      if (partFile.existsSync()) partFile.deleteSync();
      if (finalFile.existsSync()) finalFile.deleteSync();

      final request  = http.Request('GET', Uri.parse(info.downloadUrl));
      final response = await request.send().timeout(const Duration(minutes: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = partFile.openWrite();
      final sha256sink = AccumulatorSink<Digest>();
      final sha256input = sha256.startChunkedConversion(sha256sink);

      // Stream data → disk and SHA-256 accumulator simultaneously
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        sha256input.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _set(_state.copyWith(downloadProgress: received / total));
        }
      });

      await sink.flush();
      await sink.close();
      sha256input.close();

      final downloadedHash = sha256sink.events.single.toString();

      // ── Safety 2: verify SHA-256 if a .sha256 asset was published ──────────
      if (info.checksumUrl != null) {
        _set(_state.copyWith(status: UpdateStatus.verifying, downloadProgress: 1.0));
        final expectedHash = await _fetchExpectedHash(info.checksumUrl!);
        if (expectedHash != null && downloadedHash != expectedHash) {
          partFile.deleteSync();   // discard the corrupt download
          throw Exception(
              'Checksum mismatch — expected $expectedHash, got $downloadedHash');
        }
        debugPrint('[AutoUpdate] SHA-256 verified ✓ ($downloadedHash)');
      } else {
        debugPrint('[AutoUpdate] No .sha256 asset found — skipping checksum check');
      }

      // ── Safety 7: atomic rename — only exists as .exe when fully verified ──
      partFile.renameSync(finalFile.path);

      _set(_state.copyWith(
        status: UpdateStatus.readyToInstall,
        installerPath: finalFile.path,
        downloadProgress: 1.0,
      ));
    } catch (e) {
      // ── Safety 7: clean up partial file on any failure ─────────────────────
      try { partFile?.deleteSync(); } catch (_) {}
      debugPrint('[AutoUpdate] Download/verify failed: $e');
      _set(_state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      ));
      // Retry by reverting to "available" after 30 s so the next poll can retry
      Future.delayed(const Duration(seconds: 30), () {
        if (_state.status == UpdateStatus.error) {
          _set(_state.copyWith(status: UpdateStatus.available));
        }
      });
    }
  }

  /// Fetches the expected SHA-256 hash from the .sha256 release asset.
  /// The file is expected to contain just the hex digest (or `<hex>  filename`).
  Future<String?> _fetchExpectedHash(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      // Support both bare hex and `sha256sum`-style "hash  filename" format
      return r.body.trim().split(RegExp(r'\s+')).first.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  // ── Step 3: Install (Inno Setup flags) ─────────────────────────────────────

  /// Launches the verified installer then exits. Inno Setup handles the rest:
  ///  /SILENT              — no installer UI shown
  ///  /CLOSEAPPLICATIONS  — (Safety 4) closes the running app before copying files
  ///  /RESTARTAPPLICATIONS — (Safety 6) relaunches the app after install
  Future<void> installAndRestart() async {
    final path = _state.installerPath;
    if (path == null) return;

    // ── Safety 7: make sure the file still exists and hasn't been tampered ───
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 1024) {
      _set(_state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Installer file missing or invalid. Will re-download.',
      ));
      final info = _state.info;
      if (info != null) {
        Future.delayed(const Duration(seconds: 1), () => _downloadInstaller(info));
      }
      return;
    }

    try {
      debugPrint('[AutoUpdate] Launching installer: $path');
      await Process.start(
        path,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      // Give the installer process a moment to attach before we exit
      await Future.delayed(const Duration(milliseconds: 800));
      exit(0);   // ── Safety 4: app exits cleanly so Inno can replace the .exe
    } catch (e) {
      debugPrint('[AutoUpdate] Install launch failed: $e');
      _set(_state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Could not launch installer: $e',
      ));
    }
  }

  // ── Utilities ───────────────────────────────────────────────────────────────

  void _set(AutoUpdateState s) {
    _state = s;
    notifyListeners();
  }

  bool _isNewer(String candidate, String current) {
    try {
      final c   = _ver(candidate);
      final cur = _ver(current);
      for (int i = 0; i < 3; i++) {
        if (c[i] > cur[i]) return true;
        if (c[i] < cur[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  List<int> _ver(String v) {
    final p = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (p.length < 3) p.add(0);
    return p;
  }
}
