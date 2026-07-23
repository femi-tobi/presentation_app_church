// lib/connectors/presentations_ai_connector.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'connector_contract.dart';
import '../settings_state.dart';

class PresentationsAiConnector implements PresentationConnector {
  final String _apiKey;

  PresentationsAiConnector(this._apiKey);

  @override
  String get id => 'presentations_ai';

  @override
  String get name => 'Presentations.ai';

  @override
  String get description => 'Submits content outline to Presentations.ai and polls for the compiled PowerPoint deck.';

  @override
  bool get generatesLocalSlides => false;

  @override
  Future<List<SlideData>> generatePresentation(String prompt, PresentationConfig config) {
    throw UnsupportedError('Presentations.ai connector produces a direct file download and does not support local slides editor loading.');
  }

  @override
  Future<List<int>> downloadPresentationBytes(String prompt, PresentationConfig config) async {
    if (_apiKey.isEmpty) {
      throw Exception('Presentations.ai API Key is not configured. Please add it in settings.');
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      // 1. Submit PPTX creation job
      final createUrl = Uri.parse('https://api.presentations.ai/api/v1/document/content');
      final request = await client.postUrl(createUrl).timeout(const Duration(seconds: 30));
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      // Build JSON body using camelCase format as required by their REST endpoint
      final Map<String, dynamic> bodyData = {
        "content": prompt,
        "exportType": "pptx",
        "slideCount": config.targetSlideCount,
        "themeName": config.themeName,
        "fontPreference": config.fontPreference,
        "immediatePollUrl": true,
      };

      // If stylePrompt is set, pass it as custom instructions
      if (config.stylePrompt.isNotEmpty) {
        bodyData["instruction"] = "instruction";
        bodyData["instructions"] = config.stylePrompt;
      }

      request.write(jsonEncode(bodyData));

      final response = await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 202) {
        final errBody = await response.transform(utf8.decoder).join();
        throw Exception("Presentations.ai job submission failed (${response.statusCode}): $errBody");
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final responseData = jsonDecode(responseBody) as Map<String, dynamic>;

      // If url is directly returned, download it immediately (synchronous success)
      if (responseData['url'] != null && (responseData['url'] as String).isNotEmpty) {
        return await _downloadFile(client, responseData['url'] as String);
      }

      // Otherwise extract job ID for polling
      String? jobId;
      if (responseData['job_id'] != null) {
        jobId = responseData['job_id'] as String;
      } else if (responseData['jobId'] != null) {
        jobId = responseData['jobId'] as String;
      } else if (responseData['poll_url'] != null || responseData['pollUrl'] != null) {
        final pollUrl = (responseData['poll_url'] ?? responseData['pollUrl']) as String;
        // poll_url usually ends with job ID
        final segments = Uri.parse(pollUrl).pathSegments;
        if (segments.isNotEmpty) {
          jobId = segments.last;
        }
      }

      if (jobId == null || jobId.isEmpty) {
        throw Exception("Invalid response from Presentations.ai API: job ID could not be determined.");
      }

      // 2. Poll status endpoint until completed or failed
      String? downloadUrl;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 3));

        final pollUrl = Uri.parse('https://api.presentations.ai/api/v1/polljob/$jobId');
        final pollReq = await client.getUrl(pollUrl).timeout(const Duration(seconds: 15));
        pollReq.headers.set('Authorization', 'Bearer $_apiKey');

        final pollRes = await pollReq.close().timeout(const Duration(seconds: 15));
        if (pollRes.statusCode == 200) {
          final pollBody = await pollRes.transform(utf8.decoder).join();
          final statusData = jsonDecode(pollBody) as Map<String, dynamic>;
          final status = statusData['status'];

          // Server contract: status 0 is complete, status 1 is processing / error
          if (status == 0) {
            final url = statusData['url'] as String?;
            if (url != null && url.isNotEmpty) {
              downloadUrl = url;
              break;
            } else {
              throw Exception("Presentations.ai completed job but did not return a file download URL.");
            }
          } else if (status == 1) {
            final error = statusData['error'] as String?;
            if (error != null && error.isNotEmpty) {
              throw Exception("Presentations.ai generation failed on server: $error");
            }
            // Still processing (status is 1 and no error)
          }
        }
      }

      if (downloadUrl == null) {
        throw Exception("Presentations.ai presentation generation timed out (exceeded 90 seconds).");
      }

      // 3. Download the binary bytes
      return await _downloadFile(client, downloadUrl);

    } catch (e) {
      debugPrint('Presentations.ai connector exception: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<List<int>> _downloadFile(HttpClient client, String url) async {
    final downloadReq = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 30));
    final downloadRes = await downloadReq.close().timeout(const Duration(seconds: 30));

    if (downloadRes.statusCode != 200) {
      throw Exception("Failed to download presentation file from: $url (Status: ${downloadRes.statusCode})");
    }

    final List<int> bytes = [];
    await for (var chunk in downloadRes) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
}
