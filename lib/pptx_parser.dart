import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'settings_state.dart';

/// Full-fidelity PPTX parser.
/// Correctly resolves theme colours, inherits font sizes from slide
/// layout/master, and post-processes colour contrast so slides look
/// identical to PowerPoint.
class PptxParser {
  // EMU = English Metric Unit. 914400 EMU = 1 inch. 12700 EMU = 1pt.
  static const double _defaultSlideWidthEmu  = 9144000;
  static const double _defaultSlideHeightEmu = 6858000;

  static List<ParsedSlide> parsePptx(Uint8List bytes, String title) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final List<ParsedSlide> slides = [];

    // ── 1. Slide dimensions ────────────────────────────────────────────────
    double slideW = _defaultSlideWidthEmu;
    double slideH = _defaultSlideHeightEmu;
    try {
      final presFile = archive.findFile('ppt/presentation.xml');
      if (presFile != null) {
        final xml = utf8.decode(presFile.content);
        // Handle both attribute orderings (cx before cy or cy before cx)
        var m = RegExp(r'<p:sldSz\b[^>]*\bcx="(\d+)"[^>]*\bcy="(\d+)"').firstMatch(xml);
        m ??= RegExp(r'<p:sldSz\b[^>]*\bcy="(\d+)"[^>]*\bcx="(\d+)"').firstMatch(xml);
        if (m != null) {
          // Group 1 = cx, group 2 = cy regardless of attribute order
          slideW = double.parse(m.group(1)!);
          slideH = double.parse(m.group(2)!);
        }
      }
    } catch (_) {}

    // ── 2. Theme colour map ────────────────────────────────────────────────
    final Map<String, int> themeColors = _parseThemeColors(archive);

    // ── 3. Slide master / layout default font sizes ───────────────────────
    // PPTX template slides store font sizes in the master, not the slide.
    // Build a map: placeholder type → default font size in pt.
    final Map<String, double> masterFontSizes = _parseMasterFontSizes(archive);

    // ── 4. Slide relationship list ─────────────────────────────────────────
    // Needed to find which layout each slide uses.
    final Map<int, String> slideLayoutRels = _parseSlideLayoutRels(archive);

    // ── 5. Sort slide files ────────────────────────────────────────────────
    final slideFiles = archive.files.where((f) {
      final n = f.name.toLowerCase();
      return n.startsWith('ppt/slides/slide') && n.endsWith('.xml');
    }).toList()
      ..sort((a, b) => _num(a.name).compareTo(_num(b.name)));

    for (int i = 0; i < slideFiles.length; i++) {
      final file    = slideFiles[i];
      final content = utf8.decode(file.content);

      // ── Image relationship map for this slide ──────────────────────────
      final Map<String, String> imageRels = {};
      try {
        final relsPath = 'ppt/slides/_rels/${file.name.split('/').last}.rels';
        final relsFile = archive.findFile(relsPath);
        if (relsFile != null) {
          final relsXml = utf8.decode(relsFile.content);
          final rx = RegExp(r'Id="([^"]+)"[^>]*Type="[^"]*/image"[^>]*Target="([^"]+)"');
          for (final m in rx.allMatches(relsXml)) {
            imageRels[m.group(1)!] = m.group(2)!;
          }
        }
      } catch (_) {}

      String resolveTarget(String t) {
        if (t.startsWith('../')) return 'ppt/${t.replaceFirst('../', '')}';
        if (t.startsWith('media/')) return 'ppt/$t';
        return t;
      }

      String? relToDataUri(String relId) {
        final target = imageRels[relId];
        if (target == null) return null;
        final path = resolveTarget(target);
        final mf   = archive.findFile(path);
        if (mf == null) return null;
        final ext = path.split('.').last.toLowerCase();
        return 'data:image/$ext;base64,${base64Encode(mf.content as List<int>)}';
      }

      // ── 6. Background ──────────────────────────────────────────────────
      // Default: white (most slides have a light background unless explicitly dark)
      int    bgColor    = 0xFFFFFFFF;
      String bgImageUri = '';
      bool   hasBgImage = false;
      Uint8List? bgImageBytes;

      final bgBlock = RegExp(r'<p:bg>(.*?)</p:bg>', dotAll: true).firstMatch(content);
      if (bgBlock != null) {
        final bgXml = bgBlock.group(1)!;
        // Direct RGB
        final srgbM = RegExp(r'<a:srgbClr\s+val="([0-9a-fA-F]{6})"').firstMatch(bgXml);
        if (srgbM != null) {
          bgColor = int.parse('0xFF${srgbM.group(1)!}');
        } else {
          // Resolve any valid theme scheme color
          final schemeM = RegExp(r'<a:schemeClr\s+val="(\w+)"').firstMatch(bgXml);
          if (schemeM != null) {
            final key = schemeM.group(1)!;
            final resolved = themeColors[key];
            if (resolved != null) {
              bgColor = resolved;
            }
          }
        }
        // Background image
        final em = RegExp(r'r:embed="([^"]+)"').firstMatch(bgXml);
        if (em != null) {
          final uri = relToDataUri(em.group(1)!);
          if (uri != null) {
            bgImageUri = uri;
            hasBgImage = true;
            try {
              final comma = uri.indexOf(',');
              if (comma != -1) {
                bgImageBytes = base64Decode(uri.substring(comma + 1));
              }
            } catch (_) {}
          }
        }
      }

      // ── 7. Parse all shapes ────────────────────────────────────────────
      final List<PptxShape> shapes = [];
      // Remove bg block so we don't re-match colours in it
      final bodyXml = content.replaceFirst(
          RegExp(r'<p:bg>.*?</p:bg>', dotAll: true), '');

      // 7a. Picture shapes <p:pic>
      final picRx = RegExp(r'<p:pic>(.*?)</p:pic>', dotAll: true);
      for (final m in picRx.allMatches(bodyXml)) {
        final xml = m.group(1)!;
        final pos = _xfrm(xml, slideW, slideH) ?? (0.0, 0.0, 1.0, 1.0);
        final em  = RegExp(r'r:embed="([^"]+)"').firstMatch(xml);
        if (em == null) continue;
        final uri = relToDataUri(em.group(1)!);
        if (uri == null) continue;
        
        Uint8List? imgBytes;
        try {
          final comma = uri.indexOf(',');
          if (comma != -1) {
            imgBytes = base64Decode(uri.substring(comma + 1));
          }
        } catch (_) {}

        shapes.add(PptxShape(
          left: pos.$1, top: pos.$2, width: pos.$3, height: pos.$4,
          imageDataUri: uri,
          imageBytes: imgBytes,
        ));
      }

      // 7b. Text/shape objects <p:sp>
      final spRx = RegExp(r'<p:sp>(.*?)</p:sp>', dotAll: true);
      for (final m in spRx.allMatches(bodyXml)) {
        final spXml = m.group(1)!;
        final pos   = _xfrm(spXml, slideW, slideH) ?? (0.0, 0.0, 1.0, 1.0);

        // Detect placeholder type for font-size inheritance
        final phM   = RegExp(r'<p:ph\b[^>]*type="([^"]+)"').firstMatch(spXml);
        final phTypeStr = phM?.group(1) ?? '';
        // Also detect body placeholder with no type attr
        final isBodyPh = RegExp(r'<p:ph\b').hasMatch(spXml) && phTypeStr.isEmpty;
        final isTitlePh = phTypeStr == 'title' || phTypeStr == 'ctrTitle';
        final isSubtitlePh = phTypeStr == 'subTitle' || phTypeStr == 'body' || isBodyPh;

        // Shape fill (for colored boxes, backgrounds)
        int fillColor = 0x00000000;
        final spPrM = RegExp(r'<p:spPr>(.*?)</p:spPr>', dotAll: true).firstMatch(spXml);
        if (spPrM != null) {
          final spPrXml = spPrM.group(1)!;

          // Image fill inside sp (blipFill)
          final blipEm = RegExp(r'<a:blip\b[^>]*r:embed="([^"]+)"').firstMatch(spPrXml);
          if (blipEm != null) {
            final uri = relToDataUri(blipEm.group(1)!);
            if (uri != null) {
              shapes.add(PptxShape(
                left: pos.$1, top: pos.$2, width: pos.$3, height: pos.$4,
                imageDataUri: uri,
              ));
              continue;
            }
          }

          // Solid fill colour
          if (!spPrXml.contains('<a:noFill')) {
            // Only use explicit RGB fills for shapes; skip theme fills (often decorative)
            final srgbFM = RegExp(r'<a:srgbClr\s+val="([0-9a-fA-F]{6})"').firstMatch(spPrXml);
            if (srgbFM != null) {
              fillColor = int.parse('0xFF${srgbFM.group(1)!}');
            } else {
              // Try theme colour for shape fill
              final schemeFM = RegExp(r'<a:solidFill>.*?<a:schemeClr\s+val="(\w+)"', dotAll: true).firstMatch(spPrXml);
              if (schemeFM != null) {
                final c = themeColors[schemeFM.group(1)!];
                if (c != null) fillColor = c;
              }
            }
          }
        }

        // Text body
        final txBodyM = RegExp(r'<p:txBody>(.*?)</p:txBody>', dotAll: true).firstMatch(spXml);
        if (txBodyM == null) {
          // No text — render as a coloured box if it has a fill
          if (fillColor != 0x00000000) {
            shapes.add(PptxShape(
              left: pos.$1, top: pos.$2, width: pos.$3, height: pos.$4,
              fillColorValue: fillColor,
            ));
          }
          continue;
        }

        final txXml = txBodyM.group(1)!;

        // Default font size for this shape
        double defFontSize;
        if (isTitlePh) {
          defFontSize = masterFontSizes['title'] ?? 44.0;
        } else if (isSubtitlePh) {
          defFontSize = masterFontSizes['body'] ?? 28.0;
        } else {
          defFontSize = masterFontSizes['other'] ?? 20.0;
        }
        final defRprM = RegExp(r'<a:defRPr[^>]*\bsz="(\d+)"').firstMatch(txXml);
        if (defRprM != null) {
          defFontSize = double.parse(defRprM.group(1)!) / 100.0;
        }

        // Parse paragraphs
        final textBuf = StringBuffer();
        double bestSize  = 0.0;
        bool   bestBold  = false;
        bool   bestItal  = false;
        int    bestColor = -1; // -1 = unresolved
        TextAlign align  = TextAlign.left;
        String bestFont  = 'Arial';
        bool firstPara   = true;

        final paraRx = RegExp(r'<a:p>(.*?)</a:p>', dotAll: true);
        for (final pM in paraRx.allMatches(txXml)) {
          final pXml = pM.group(1)!;

          if (firstPara) {
            final algnM = RegExp(r'algn="(\w+)"').firstMatch(pXml);
            if (algnM != null) {
              align = _align(algnM.group(1));
            } else if (isTitlePh || isSubtitlePh) {
              align = TextAlign.center;
            } else {
              align = TextAlign.left;
            }
          }

          // Paragraph-level default font size
          double paraDefSize = defFontSize;
          final pDefRprM = RegExp(r'<a:defRPr[^>]*\bsz="(\d+)"').firstMatch(pXml);
          if (pDefRprM != null) {
            paraDefSize = double.parse(pDefRprM.group(1)!) / 100.0;
          }

          bool paraHasText = false;
          final runRx = RegExp(r'<a:r>(.*?)</a:r>', dotAll: true);
          for (final rM in runRx.allMatches(pXml)) {
            final rXml = rM.group(1)!;
            final tM   = RegExp(r'<a:t>([^<]*)</a:t>').firstMatch(rXml);
            if (tM == null) continue;
            final t = tM.group(1)!;
            textBuf.write(t);
            paraHasText = true;

            // Run-level font family (typeface)
            final latinM = RegExp(r'<a:latin\s+typeface="([^"]+)"').firstMatch(rXml);
            if (latinM != null) {
              bestFont = latinM.group(1)!;
              final fontLower = bestFont.toLowerCase();
              if (fontLower.contains('black') ||
                  fontLower.contains('bold') ||
                  fontLower.contains('heavy') ||
                  fontLower.contains('impact')) {
                bestBold = true;
              }
            }

            // Run-level font size, bold, italic
            final rPrM = RegExp(r'<a:rPr([^>]*)>').firstMatch(rXml);
            double runSize = paraDefSize;
            if (rPrM != null) {
              final attrs = rPrM.group(1)!;
              final szM   = RegExp(r'\bsz="(\d+)"').firstMatch(attrs);
              if (szM != null) runSize = double.parse(szM.group(1)!) / 100.0;
              if (attrs.contains('b="1"') || attrs.contains('b="true"')) bestBold = true;
              if (attrs.contains('i="1"') || attrs.contains('i="true"')) bestItal = true;
            }
            if (runSize > bestSize) bestSize = runSize;

            // Text colour — resolve on the first unresolved run
            if (bestColor == -1) {
              final c = _resolveColor(rXml, themeColors);
              if (c != null) bestColor = c;
            }
          }
          if (paraHasText) textBuf.write('\n');
          firstPara = false;
        }

        final text = textBuf.toString().trim();
        if (text.isEmpty && fillColor == 0x00000000) continue;
        if (bestSize == 0.0) bestSize = defFontSize;

        // If color was not explicitly set, default to high-contrast white/black based on background
        int textColor = bestColor;
        if (textColor == -1) {
          textColor = _luminance(bgColor) < 0.5 ? 0xFFFFFFFF : 0xFF000000;
        }

        shapes.add(PptxShape(
          left:           pos.$1,
          top:            pos.$2,
          width:          pos.$3,
          height:         pos.$4,
          text:           text,
          fontSize:       bestSize.clamp(4.0, 400.0),
          isBold:         bestBold,
          isItalic:       bestItal,
          colorValue:     textColor,
          align:          align,
          fillColorValue: fillColor,
          fontFamily:     bestFont,
        ));
      }

      // ── 8. Post-process: contrast correction ──────────────────────────
      // If background is light but all text is also light (or vice versa),
      // flip text colours to ensure readability — matching PowerPoint's intent.
      if (!hasBgImage) {
        final bgLum = _luminance(bgColor);
        final correctedShapes = shapes.map((s) {
          if (s.imageDataUri.isNotEmpty) return s;
          final txtLum = _luminance(s.colorValue);
          // Both bg and text are light → flip text to dark
          if (bgLum > 0.5 && txtLum > 0.5) {
            return PptxShape(
              left: s.left, top: s.top, width: s.width, height: s.height,
              text: s.text, fontSize: s.fontSize,
              isBold: s.isBold, isItalic: s.isItalic,
              colorValue: 0xFF000000, // force black text on light bg
              align: s.align,
              imageDataUri: s.imageDataUri,
              fillColorValue: s.fillColorValue,
              fontFamily: s.fontFamily,
            );
          }
          // Both bg and text are dark → flip text to light
          if (bgLum < 0.3 && txtLum < 0.3) {
            return PptxShape(
              left: s.left, top: s.top, width: s.width, height: s.height,
              text: s.text, fontSize: s.fontSize,
              isBold: s.isBold, isItalic: s.isItalic,
              colorValue: 0xFFFFFFFF, // force white text on dark bg
              align: s.align,
              imageDataUri: s.imageDataUri,
              fillColorValue: s.fillColorValue,
              fontFamily: s.fontFamily,
            );
          }
          return s;
        }).toList();

        slides.add(ParsedSlide(
          id:                 'imported_${(i + 1).toString().padLeft(2, '0')}',
          title:              _slideTitle(correctedShapes, i),
          subtitle:           _slideSubtitle(correctedShapes),
          imageUrl:           bgImageUri,
          bgColorValue:       bgColor,
          textColorValue:     0xFF000000,
          pptxShapes:         correctedShapes,
          pptxSlideHeightEmu: slideH,
          bgImageBytes:       bgImageBytes,
        ));
      } else {
        slides.add(ParsedSlide(
          id:                 'imported_${(i + 1).toString().padLeft(2, '0')}',
          title:              _slideTitle(shapes, i),
          subtitle:           _slideSubtitle(shapes),
          imageUrl:           bgImageUri,
          bgColorValue:       bgColor,
          textColorValue:     0xFF000000,
          pptxShapes:         shapes,
          pptxSlideHeightEmu: slideH,
          bgImageBytes:       bgImageBytes,
        ));
      }
    }

    if (slides.isEmpty) {
      slides.add(ParsedSlide(
        id:                 'imported_01',
        title:              title,
        subtitle:           'No slide content parsed.',
        imageUrl:           '',
        bgColorValue:       0xFFFFFFFF,
        textColorValue:     0xFF000000,
        pptxShapes:         [],
        pptxSlideHeightEmu: slideH,
      ));
    }

    return slides;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Theme colour parsing
  // ──────────────────────────────────────────────────────────────────────────

  static Map<String, int> _parseThemeColors(Archive archive) {
    // Office "Office" theme defaults (correct for light themes)
    final map = <String, int>{
      'dk1': 0xFF000000, 'lt1': 0xFFFFFFFF,
      'dk2': 0xFF44546A, 'lt2': 0xFFE7E6E6,
      'accent1': 0xFF4472C4, 'accent2': 0xFFED7D31,
      'accent3': 0xFFA9D18E, 'accent4': 0xFFFFC000,
      'accent5': 0xFF5B9BD5, 'accent6': 0xFF70AD47,
      'hlink': 0xFF0563C1, 'folHlink': 0xFF954F72,
      'tx1': 0xFF000000, 'tx2': 0xFF44546A,
      'bg1': 0xFFFFFFFF, 'bg2': 0xFFE7E6E6,
    };

    try {
      final themeFile = archive.findFile('ppt/theme/theme1.xml');
      if (themeFile == null) return map;
      final xml = utf8.decode(themeFile.content);
      final clrSchemeM = RegExp(r'<a:clrScheme[^>]*>(.*?)</a:clrScheme>', dotAll: true).firstMatch(xml);
      if (clrSchemeM == null) return map;
      final schemeXml = clrSchemeM.group(1)!;

      final slotRx = RegExp(r'<a:(\w+)>(.*?)</a:\1>', dotAll: true);
      for (final slotM in slotRx.allMatches(schemeXml)) {
        final name  = slotM.group(1)!;
        final inner = slotM.group(2)!;
        final srgbM = RegExp(r'<a:srgbClr\s+val="([0-9a-fA-F]{6})"').firstMatch(inner);
        if (srgbM != null) { map[name] = int.parse('0xFF${srgbM.group(1)!}'); continue; }
        final sysM  = RegExp(r'lastClr="([0-9a-fA-F]{6})"').firstMatch(inner);
        if (sysM  != null) { map[name] = int.parse('0xFF${sysM.group(1)!}'); }
      }

      // Add semantic aliases
      map['tx1'] = map['dk1'] ?? 0xFF000000;
      map['tx2'] = map['dk2'] ?? 0xFF44546A;
      map['bg1'] = map['lt1'] ?? 0xFFFFFFFF;
      map['bg2'] = map['lt2'] ?? 0xFFE7E6E6;
    } catch (_) {}

    return map;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Slide master / layout font size extraction
  // ──────────────────────────────────────────────────────────────────────────

  static Map<String, double> _parseMasterFontSizes(Archive archive) {
    final result = <String, double>{
      'title': 44.0,
      'body':  24.0,
      'other': 20.0,
    };
    try {
      final masterFile = archive.findFile('ppt/slideMasters/slideMaster1.xml');
      if (masterFile == null) return result;
      final xml = utf8.decode(masterFile.content);

      // Find title placeholder text style
      final titleTxStyles = RegExp(
          r'<p:titleStyle>(.*?)</p:titleStyle>', dotAll: true)
          .firstMatch(xml);
      if (titleTxStyles != null) {
        final sz = RegExp(r'<a:defRPr[^>]*\bsz="(\d+)"')
            .firstMatch(titleTxStyles.group(1)!);
        if (sz != null) result['title'] = double.parse(sz.group(1)!) / 100.0;
      }

      // Find body placeholder text style
      final bodyTxStyles = RegExp(
          r'<p:bodyStyle>(.*?)</p:bodyStyle>', dotAll: true)
          .firstMatch(xml);
      if (bodyTxStyles != null) {
        final sz = RegExp(r'<a:defRPr[^>]*\bsz="(\d+)"')
            .firstMatch(bodyTxStyles.group(1)!);
        if (sz != null) result['body'] = double.parse(sz.group(1)!) / 100.0;
      }

      // Find other placeholder text style
      final otherTxStyles = RegExp(
          r'<p:otherStyle>(.*?)</p:otherStyle>', dotAll: true)
          .firstMatch(xml);
      if (otherTxStyles != null) {
        final sz = RegExp(r'<a:defRPr[^>]*\bsz="(\d+)"')
            .firstMatch(otherTxStyles.group(1)!);
        if (sz != null) result['other'] = double.parse(sz.group(1)!) / 100.0;
      }
    } catch (_) {}

    return result;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Slide layout relationship (not currently used but scaffolded for future)
  // ──────────────────────────────────────────────────────────────────────────

  static Map<int, String> _parseSlideLayoutRels(Archive archive) {
    return {};
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Colour helpers
  // ──────────────────────────────────────────────────────────────────────────

  static int? _resolveColor(String xml, Map<String, int> theme) {
    final srgbM = RegExp(r'<a:srgbClr\s+val="([0-9a-fA-F]{6})"').firstMatch(xml);
    if (srgbM != null) return int.parse('0xFF${srgbM.group(1)!}');
    final schemeM = RegExp(r'<a:schemeClr\s+val="(\w+)"').firstMatch(xml);
    if (schemeM != null) return theme[schemeM.group(1)!];
    return null;
  }

  /// Relative luminance (0 = black, 1 = white)
  static double _luminance(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8)  & 0xFF) / 255.0;
    final b = (argb          & 0xFF) / 255.0;
    double linearize(double c) =>
        c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055);
    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Transform helpers
  // ──────────────────────────────────────────────────────────────────────────

  static (double, double, double, double)? _xfrm(
      String xml, double slideW, double slideH) {
    final xfrmM = RegExp(r'<a:xfrm[^>]*>(.*?)</a:xfrm>', dotAll: true).firstMatch(xml);
    if (xfrmM == null) return null;
    final inner = xfrmM.group(1)!;
    final offM  = RegExp(r'<a:off\s+x="(-?\d+)"\s+y="(-?\d+)"').firstMatch(inner);
    final extM  = RegExp(r'<a:ext\s+cx="(\d+)"\s+cy="(\d+)"').firstMatch(inner);
    if (offM == null || extM == null) return null;
    final x  = double.parse(offM.group(1)!);
    final y  = double.parse(offM.group(2)!);
    final cx = double.parse(extM.group(1)!);
    final cy = double.parse(extM.group(2)!);
    return (x / slideW, y / slideH, cx / slideW, cy / slideH);
  }

  static TextAlign _align(String? a) {
    switch (a) {
      case 'ctr':  return TextAlign.center;
      case 'r':    return TextAlign.right;
      case 'just': return TextAlign.justify;
      default:     return TextAlign.left;
    }
  }

  static int _num(String path) {
    final m = RegExp(r'\d+').firstMatch(path.split('/').last);
    return m != null ? (int.tryParse(m.group(0)!) ?? 0) : 0;
  }

  static String _slideTitle(List<PptxShape> shapes, int index) {
    final ts = shapes.where((s) => s.text.isNotEmpty).toList();
    return ts.isNotEmpty ? ts.first.text.replaceAll('\n', ' ').trim() : 'Slide ${index + 1}';
  }

  static String _slideSubtitle(List<PptxShape> shapes) {
    final ts = shapes.where((s) => s.text.isNotEmpty).toList();
    return ts.length > 1 ? ts.sublist(1).map((s) => s.text).join('\n') : '';
  }
}

/// Lightweight plain data slide class to transfer across isolates without ChangeNotifier exceptions.
class ParsedSlide {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int bgColorValue;
  final int textColorValue;
  final List<PptxShape> pptxShapes;
  final double pptxSlideHeightEmu;
  final Uint8List? bgImageBytes;

  ParsedSlide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.bgColorValue,
    required this.textColorValue,
    required this.pptxShapes,
    required this.pptxSlideHeightEmu,
    this.bgImageBytes,
  });
}
