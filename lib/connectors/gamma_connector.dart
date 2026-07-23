// lib/connectors/gamma_connector.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'connector_contract.dart';
import '../settings_state.dart';

class GammaConnector implements PresentationConnector {
  final String _apiKey;

  GammaConnector(this._apiKey);

  @override
  String get id => 'gamma';

  @override
  String get name => 'Gamma App';

  @override
  String get description => 'Triggers a presentation build on Gamma.app, exports to PowerPoint, and downloads the file.';

  @override
  bool get generatesLocalSlides => false;

  @override
  Future<List<SlideData>> generatePresentation(String prompt, PresentationConfig config) {
    throw UnsupportedError('Gamma connector produces a direct file download and does not support local slides editor loading.');
  }

  @override
  Future<List<int>> downloadPresentationBytes(String prompt, PresentationConfig config) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gamma API Key is not configured. Please add it in settings.');
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      // 1. Generate Presentation
      final createUrl = Uri.parse('https://api.gamma.app/v1/presentations/generate');
      final createReq = await client.postUrl(createUrl).timeout(const Duration(seconds: 30));
      createReq.headers.set('Authorization', 'Bearer $_apiKey');
      createReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final String fullPrompt = "Outline:\n$prompt\n\n"
          "Please generate a presentation with exactly ${config.targetSlideCount} slides. "
          "Style preferences: Font: ${config.fontPreference}, Theme: ${config.themeName}, Visual style: ${config.stylePrompt}";

      createReq.write(jsonEncode({
        "prompt": fullPrompt
      }));

      final createRes = await createReq.close().timeout(const Duration(seconds: 30));
      if (createRes.statusCode != 202 && createRes.statusCode != 200) {
        final errBody = await createRes.transform(utf8.decoder).join();
        throw Exception("Gamma presentation creation failed (${createRes.statusCode}): $errBody");
      }

      final createBody = await createRes.transform(utf8.decoder).join();
      final presentationId = jsonDecode(createBody)['presentation_id'] as String;

      // 2. Trigger Export Job to PPTX
      final exportUrl = Uri.parse('https://api.gamma.app/v1/presentations/$presentationId/export');
      final exportReq = await client.postUrl(exportUrl).timeout(const Duration(seconds: 30));
      exportReq.headers.set('Authorization', 'Bearer $_apiKey');
      exportReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      exportReq.write(jsonEncode({"format": "pptx"}));

      final exportRes = await exportReq.close().timeout(const Duration(seconds: 30));
      if (exportRes.statusCode != 202 && exportRes.statusCode != 200) {
        final errBody = await exportRes.transform(utf8.decoder).join();
        throw Exception("Gamma export job initiation failed (${exportRes.statusCode}): $errBody");
      }

      final exportBody = await exportRes.transform(utf8.decoder).join();
      final exportJobId = jsonDecode(exportBody)['job_id'] as String;

      // 3. Poll export status
      String? downloadUrl;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 3));

        final pollUrl = Uri.parse('https://api.gamma.app/v1/jobs/$exportJobId');
        final pollReq = await client.getUrl(pollUrl).timeout(const Duration(seconds: 15));
        pollReq.headers.set('Authorization', 'Bearer $_apiKey');

        final pollRes = await pollReq.close().timeout(const Duration(seconds: 15));
        if (pollRes.statusCode == 200) {
          final pollBody = await pollRes.transform(utf8.decoder).join();
          final statusData = jsonDecode(pollBody);
          final status = statusData['status'] as String;

          if (status == 'completed') {
            downloadUrl = statusData['download_url'] as String;
            break;
          } else if (status == 'failed') {
            throw Exception("Gamma PPTX export failed on server.");
          }
        }
      }

      if (downloadUrl == null) {
        throw Exception("Gamma export job timed out (exceeded 90 seconds).");
      }

      // 4. Download binary data
      final downloadReq = await client.getUrl(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 30));
      final downloadRes = await downloadReq.close().timeout(const Duration(seconds: 30));

      if (downloadRes.statusCode != 200) {
        throw Exception("Failed to download presentation file from Gamma: $downloadUrl");
      }

      final List<int> bytes = [];
      await for (var chunk in downloadRes) {
        bytes.addAll(chunk);
      }
      return bytes;

    } catch (e) {
      debugPrint('Gamma connector exception: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
