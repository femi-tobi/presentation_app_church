// lib/connectors/slidesgpt_connector.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'connector_contract.dart';
import '../settings_state.dart';

class SlidesGptConnector implements PresentationConnector {
  final String _apiKey;

  SlidesGptConnector(this._apiKey);

  @override
  String get id => 'slidesgpt';

  @override
  String get name => 'SlidesGPT';

  @override
  String get description => 'Submits outline to SlidesGPT.com and downloads a fully styled PowerPoint slide deck directly.';

  @override
  bool get generatesLocalSlides => false;

  @override
  Future<List<SlideData>> generatePresentation(String prompt, PresentationConfig config) {
    throw UnsupportedError('SlidesGPT connector produces a direct file download and does not support local slides editor loading.');
  }

  @override
  Future<List<int>> downloadPresentationBytes(String prompt, PresentationConfig config) async {
    if (_apiKey.isEmpty) {
      throw Exception('SlidesGPT API Key is not configured. Please add it in settings.');
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      // 1. Submit PPTX creation job
      final createUrl = Uri.parse('https://slidesgpt.com/api/v1/create');
      final request = await client.postUrl(createUrl).timeout(const Duration(seconds: 30));
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      // Compose detailed instructions combining outline and style configurations
      final String fullPrompt = "Outline:\n$prompt\n\n"
          "Please generate a presentation with exactly ${config.targetSlideCount} slides. "
          "Style instructions: Font: ${config.fontPreference}, Theme: ${config.themeName}, Visual style: ${config.stylePrompt}";

      request.write(jsonEncode({
        "prompt": fullPrompt,
        "format": "pptx"
      }));

      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        final errBody = await response.transform(utf8.decoder).join();
        throw Exception("SlidesGPT job submission failed (${response.statusCode}): $errBody");
      }

      final body = await response.transform(utf8.decoder).join();
      final taskId = jsonDecode(body)['task_id'] as String;

      // 2. Poll status endpoint until completed
      String? downloadUrl;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 3));

        final pollUrl = Uri.parse('https://slidesgpt.com/api/v1/status/$taskId');
        final pollReq = await client.getUrl(pollUrl).timeout(const Duration(seconds: 15));
        pollReq.headers.set('Authorization', 'Bearer $_apiKey');
        
        final pollRes = await pollReq.close().timeout(const Duration(seconds: 15));
        if (pollRes.statusCode == 200) {
          final pollBody = await pollRes.transform(utf8.decoder).join();
          final statusData = jsonDecode(pollBody);
          final status = statusData['status'] as String;
          
          if (status == 'completed') {
            downloadUrl = statusData['pptx_download_url'] as String;
            break;
          } else if (status == 'failed') {
            throw Exception("SlidesGPT generation job failed on server.");
          }
        }
      }

      if (downloadUrl == null) {
        throw Exception("SlidesGPT generation timed out (exceeded 90 seconds).");
      }

      // 3. Download the binary bytes
      final downloadReq = await client.getUrl(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 30));
      final downloadRes = await downloadReq.close().timeout(const Duration(seconds: 30));

      if (downloadRes.statusCode != 200) {
        throw Exception("Failed to download presentation file from: $downloadUrl");
      }

      final List<int> bytes = [];
      await for (var chunk in downloadRes) {
        bytes.addAll(chunk);
      }
      return bytes;

    } catch (e) {
      debugPrint('SlidesGPT connector exception: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
