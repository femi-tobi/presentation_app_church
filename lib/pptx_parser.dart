import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'settings_state.dart';

class PptxParser {
  /// Unpacks a .pptx file, parses slide XML structures, and returns a list of SlideData.
  static List<SlideData> parsePptx(Uint8List bytes, String title) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final List<SlideData> slides = [];

    // Find all files in the archive matching slide files
    // E.g., 'ppt/slides/slide1.xml', etc.
    final slideFiles = archive.files.where((file) {
      final name = file.name.toLowerCase();
      return name.startsWith('ppt/slides/slide') && name.endsWith('.xml');
    }).toList();

    // Sort slide files numerically by index to preserve presentation order
    slideFiles.sort((a, b) {
      final aNum = _extractNumber(a.name);
      final bNum = _extractNumber(b.name);
      return aNum.compareTo(bNum);
    });

    for (int i = 0; i < slideFiles.length; i++) {
      final file = slideFiles[i];
      final content = utf8.decode(file.content);
      
      final parsed = _parseSlideXml(content, 'Slide ${i + 1}');
      slides.add(SlideData(
        id: '${i + 1}'.padLeft(2, '0'),
        title: parsed.title,
        subtitle: parsed.subtitle,
        imageUrl: '',
        opacity: 0.80,
        blur: 8.0,
        titleFontSize: 36.0,
        subtitleFontSize: 20.0,
      ));
    }

    if (slides.isEmpty) {
      // Fallback slide
      slides.add(SlideData(
        id: '01',
        title: title,
        subtitle: 'No slide content parsed.',
        imageUrl: '',
        opacity: 0.80,
        blur: 8.0,
        titleFontSize: 36.0,
        subtitleFontSize: 20.0,
      ));
    }

    return slides;
  }

  static int _extractNumber(String path) {
    final name = path.split('/').last;
    final match = RegExp(r'\d+').firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  static ({String title, String subtitle}) _parseSlideXml(String xml, String fallbackTitle) {
    // Locate shape blocks: <p:sp>...</p:sp>
    final shapeRegex = RegExp(r'<p:sp>(.*?)</p:sp>', dotAll: true);
    final shapesMatches = shapeRegex.allMatches(xml);

    final List<String> textBlocks = [];

    for (final match in shapesMatches) {
      final shapeXml = match.group(1) ?? '';
      // Extract all text runs: <a:t>...</a:t>
      final textRunRegex = RegExp(r'<a:t>([^<]*)</a:t>');
      final textMatches = textRunRegex.allMatches(shapeXml);
      
      final shapeText = textMatches.map((m) => m.group(1) ?? '').join().trim();
      if (shapeText.isNotEmpty) {
        textBlocks.add(shapeText);
      }
    }

    if (textBlocks.isEmpty) {
      return (title: fallbackTitle, subtitle: '');
    } else if (textBlocks.length == 1) {
      return (title: textBlocks.first, subtitle: '');
    } else {
      // Typically, the first shape is the title, the second is subtitle/lyrics
      return (
        title: textBlocks[0],
        subtitle: textBlocks.sublist(1).join('\n\n'),
      );
    }
  }
}
