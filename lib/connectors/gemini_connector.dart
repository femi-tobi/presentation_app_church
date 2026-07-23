// lib/connectors/gemini_connector.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'connector_contract.dart';
import '../settings_state.dart';

class GeminiConnector implements PresentationConnector {
  final String _apiKey;

  GeminiConnector(this._apiKey);

  @override
  String get id => 'gemini';

  @override
  String get name => 'Gemini AI (Local Slides)';

  @override
  String get description => 'Structures outlines using Gemini, allowing you to edit slides locally in the app before exporting.';

  @override
  bool get generatesLocalSlides => true;

  @override
  Future<List<SlideData>> generatePresentation(String prompt, PresentationConfig config) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API Key is not configured. Please add it in settings.');
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      final modelName = await _resolveModelName(client);
      debugPrint('Selected Gemini model: $modelName');

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/$modelName:generateContent?key=$_apiKey');
      final request = await client.postUrl(url).timeout(const Duration(seconds: 30));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final String systemInstruction = 
          "You are an expert presentation creator. Given the user's sermon or liturgy outline text, structure it into a beautiful slide presentation. "
          "Create exactly ${config.targetSlideCount} slides representing worship logs, sermon topics, or liturgies. "
          "For each slide, return a JSON object with: \n"
          "1. 'title' (short title) \n"
          "2. 'subtitle' (lyrics, verses, or summary description) \n"
          "3. 'slideType' (classify as 'welcome', 'worship', 'sermon', 'prayer', or 'general') \n"
          "4. 'alignment' ('left', 'center', or 'right' based on layout readability) \n"
          "5. 'isBold' (boolean) \n"
          "6. 'isItalic' (boolean) \n"
          "7. 'blur' (double between 0.0 and 15.0 to style background visibility) \n"
          "Format your output as a raw JSON array of objects. Do not wrap your response in markdown code blocks (like ```json). Return ONLY raw JSON text.";

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "$systemInstruction\n\nOutline Text:\n$prompt\n\nStyle preferences: ${config.stylePrompt}"}
            ]
          }
        ]
      });

      request.write(body);
      final response = await request.close().timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 30));
        final jsonResponse = jsonDecode(responseBody);
        
        final candidates = jsonResponse['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Gemini returned no response candidates. The prompt may have been blocked or empty.');
        }
        
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        if (content == null) {
          throw Exception('Gemini returned an empty candidate content.');
        }
        
        final parts = content['parts'] as List<dynamic>?;
        if (parts == null || parts.isEmpty) {
          throw Exception('Gemini returned content with no text parts.');
        }
        
        final rawText = parts[0]['text'] as String?;
        if (rawText == null || rawText.trim().isEmpty) {
          throw Exception('Gemini returned an empty response text.');
        }
        
        String cleanJson = rawText.trim();
        // Extract content between first '[' and last ']' to find the JSON array of slides
        final start = cleanJson.indexOf('[');
        final end = cleanJson.lastIndexOf(']');
        if (start != -1 && end != -1 && end > start) {
          cleanJson = cleanJson.substring(start, end + 1);
        } else {
          // If no array brackets found, let's try curly brackets for a single object
          final objStart = cleanJson.indexOf('{');
          final objEnd = cleanJson.lastIndexOf('}');
          if (objStart != -1 && objEnd != -1 && objEnd > objStart) {
            cleanJson = cleanJson.substring(objStart, objEnd + 1);
            // Wrap in a list so mapping logic succeeds
            cleanJson = '[$cleanJson]';
          } else {
            throw Exception('Could not extract JSON presentation data from Gemini response: $rawText');
          }
        }
        
        final List<dynamic> parsedSlides = jsonDecode(cleanJson);
        
        // High fidelity background image URLs matching our Sunday Morning templates
        const String welcomeUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuAkigYecE0CmKCuZFuBavKgN8DzoLC7W6Sk1f-88TsL65rI2VnvQzMWzMBXlbn8NSWWMj3iuMzd11L6JwDZ2c8g0xtJ2u0GEE_8MBPBgHYWSh0YLC1YOuFntl9RJBWsp_VN3nRZxNGLDsJHoY5mYOytCHGZhxtVaiBfRrxImcruugnP5uLvBWeSb5hVCEijqYRd-ALjE3KK6juaQxJCITKZ5jv7tLDBMLKDJmX1snESiJYg_J9JA4PfxwbF4qYm65btRgUVbPErgMhD';
        const String worshipUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuBfTxPcvdVGtfS9lB7z9X1sbdQv7Ilwyi2_gIR8q6qyd9VBoA89wAD1lUuPKcv-bTKvDQfFzhBP6D7Wmk9GXpxYRw7FAL7uNi_tcvc3eygW39xLOHnW1sTQPIVorDBZlUEyEzmhNPNBCDJjA2Ij6dXwIx3KehHleNrkVpRci9akO3-G-MmNbU2NkBiLJ8yIjB5aE0YBidFgvYrgL8hM7H6EzeujgWZY61dJJ3HW-o51FReWjE5GK3bd7aYCLoO6ydFHTSxp8PoX38Pr';
        const String sermonUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuBOy_uRm4spX4LG8doBchZNGyiO4lrxmQssiqyI1iBFyFONgeUCM5HyR_WsacGWJatGTaSzstvh3A7zkFM5td3MFYD-xSJa-ueTFJcUUCoIQqVNxm4-ij-iXs9bAGSuinsPa60GOYvzioSwl6ir3hv4gYp9koJQW3t9iNwMMd_0DUn2GN8_JD5pN31SbQYpl2Os2GzmPm7YG8Dsyc4RSXi64168o8knrfH0rilaDoh7w60YpEiQEIcyE0LjRoPA0C6KrEhbju4CVP4f';
        const String prayerUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuC7vrdf0-1MvJXE356j2QWAdqpVFRk3iunfVAlO_TA1nQeR2qaAk5aQbTiQ7x4o41c8QKHp0WjP_U0ZZ_TynH_Qj7LxQUjwbVylQIqSgYPdkhsy-2gOEjVYnnsbP5aEwkSlo7v4TvZwP-TgpmFPGT-Dm4H254TZk2sMH_A9jiSsreTqRqwsMd_ORqBdEm5kA6iG1yBUgpPJ28OD9zSa1v0wfl0mj4Cg3lcsoA2w5BUSKkS-ZXLZ_fB_BwPKYOW0DUcuWNXievN0BCOG';
        const String defaultUrl = 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1280&q=80';

        int index = 1;
        int parsedBgColor = 0xFF000000;
        try {
          final hex = config.primaryColorHex.replaceAll('#', '');
          if (hex.length == 6) {
            parsedBgColor = int.parse('0xFF$hex');
          } else if (hex.length == 8) {
            parsedBgColor = int.parse('0x$hex');
          }
        } catch (_) {}

        return parsedSlides.map((item) {
          final id = DateTime.now().microsecondsSinceEpoch.toString() + '_' + (index++).toString();
          
          final type = (item['slideType'] as String? ?? 'general').toLowerCase();
          String imgUrl = defaultUrl;
          double opacityVal = 0.80;
          double blurVal = (item['blur'] as num?)?.toDouble() ?? 8.0;
          
          if (type == 'welcome') {
            imgUrl = welcomeUrl;
            opacityVal = 0.85;
            blurVal = (item['blur'] as num?)?.toDouble() ?? 12.0;
          } else if (type == 'worship') {
            imgUrl = worshipUrl;
            opacityVal = 0.70;
            blurVal = (item['blur'] as num?)?.toDouble() ?? 4.0;
          } else if (type == 'sermon') {
            imgUrl = sermonUrl;
            opacityVal = 0.90;
            blurVal = (item['blur'] as num?)?.toDouble() ?? 15.0;
          } else if (type == 'prayer') {
            imgUrl = prayerUrl;
            opacityVal = 0.80;
            blurVal = (item['blur'] as num?)?.toDouble() ?? 8.0;
          }

          final alignmentStr = (item['alignment'] as String? ?? 'center').toLowerCase();
          TextAlign alignVal = TextAlign.center;
          if (alignmentStr == 'left') {
            alignVal = TextAlign.left;
          } else if (alignmentStr == 'right') {
            alignVal = TextAlign.right;
          }

          final bool boldVal = item['isBold'] as bool? ?? false;
          final bool italicVal = item['isItalic'] as bool? ?? true;

          return SlideData(
            id: id,
            title: item['title'] ?? '',
            subtitle: item['subtitle'] ?? '',
            imageUrl: imgUrl,
            opacity: opacityVal,
            blur: blurVal,
            isBold: boldVal,
            isItalic: italicVal,
            alignment: alignVal,
            bgColorValue: parsedBgColor,
          );
        }).toList();
      } else {
        final responseBody = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
        debugPrint('Gemini API error: ${response.statusCode}, body: $responseBody');
        throw Exception('Gemini API error (${response.statusCode}): $responseBody');
      }
    } catch (e) {
      debugPrint('Gemini request exception: $e');
      final available = await _getAvailableModels();
      throw Exception('Gemini request failed: $e\nAvailable models: $available');
    } finally {
      client.close();
    }
  }

  Future<String> _resolveModelName(HttpClient client) async {
    try {
      final listUrl = Uri.parse('https://generativelanguage.googleapis.com/v1/models?key=$_apiKey');
      final req = await client.getUrl(listUrl).timeout(const Duration(seconds: 10));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(body);
        final List<dynamic> models = data['models'] ?? [];
        
        // Extract model names that support generateContent
        final List<String> available = [];
        for (final m in models) {
          final name = (m['name'] as String).replaceFirst('models/', '');
          final methods = m['supportedGenerationMethods'] as List<dynamic>? ?? [];
          if (methods.contains('generateContent')) {
            available.add(name);
          }
        }
        
        // Prioritize models: gemini-2.5-flash -> gemini-2.0-flash -> gemini-1.5-flash
        for (final priority in ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash']) {
          if (available.contains(priority)) {
            return priority;
          }
        }
        
        // Fallback to any other flash model in the list
        final flashModel = available.firstWhere((name) => name.contains('flash'), orElse: () => '');
        if (flashModel.isNotEmpty) {
          return flashModel;
        }
        
        // Fallback to any model in the list that supports generateContent
        if (available.isNotEmpty) {
          return available.first;
        }
      }
    } catch (e) {
      debugPrint('Error resolving model: $e');
    }
    
    // Default fallback
    return 'gemini-2.5-flash';
  }

  Future<String> _getAvailableModels() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models?key=$_apiKey');
      final request = await client.getUrl(url).timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(body);
        final List<dynamic> models = data['models'] ?? [];
        final names = models.map((m) => (m['name'] as String).replaceFirst('models/', '')).toList();
        return names.join(', ');
      } else {
        return 'Could not retrieve models list (HTTP ${response.statusCode})';
      }
    } catch (err) {
      return 'Could not retrieve models list ($err)';
    } finally {
      client.close();
    }
  }

  @override
  Future<List<int>> downloadPresentationBytes(String prompt, PresentationConfig config) {
    throw UnsupportedError('Gemini (Local Slides) connector generates local slides and does not directly support file downloads.');
  }
}
