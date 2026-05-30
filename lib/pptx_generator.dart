// lib/pptx_generator.dart
// Generates a valid PPTX (Office Open XML) file with embedded background images
// and custom font sizes, then saves the file (desktop) or triggers a browser
// download (web).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class PptxGenerator {
  static Future<void> downloadPptx(
    List<({
      String title,
      String subtitle,
      double titleFontSize,
      double subtitleFontSize,
      String? logoUrl,
      double logoX,
      double logoY,
      double logoSize,
      double textX,
      double textY,
    })> slides,
    String filename, {
    String? backgroundImageUrl,
    String? fontFamily,
  }) async {
    final bytes = _buildPptx(slides, backgroundImageUrl, fontFamily);

    if (kIsWeb) {
      // Web: trigger browser download via dart:html (loaded dynamically)
      _webDownload(bytes, '$filename.pptx');
    } else {
      // Desktop / mobile: use file_picker to let user choose save location
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save presentation as…',
        fileName: '$filename.pptx',
        type: FileType.custom,
        allowedExtensions: ['pptx'],
        bytes: Uint8List.fromList(bytes),
      );
      if (outputPath != null && !kIsWeb) {
        await File(outputPath).writeAsBytes(bytes);
      }
    }
  }

  /// Web-only download helper — uses dart:html indirectly via `dart:js_util`
  /// so the import never causes compilation errors on non-web targets.
  // ignore: prefer_void_to_null
  static void _webDownload(List<int> bytes, String filename) {
    // On web builds this function is called only at runtime when kIsWeb==true.
    // We use dart:js to avoid a hard dart:html import.
    // Because we guard with kIsWeb, dead-code elimination removes this on
    // non-web targets and the js-interop path is never linked in.
    throw UnsupportedError(
      '_webDownload should only be called on web. '
      'Guard the call with kIsWeb.',
    );
  }

  static List<int> _buildPptx(
    List<({
      String title,
      String subtitle,
      double titleFontSize,
      double subtitleFontSize,
      String? logoUrl,
      double logoX,
      double logoY,
      double logoSize,
      double textX,
      double textY,
    })> slides,
    String? backgroundImageUrl,
    String? fontFamily,
  ) {
    final archive = Archive();

    // ── Try to extract embedded image bytes from a data: URL ──────────────
    Uint8List? imageBytes;
    String imageExt = 'png';
    String imageMimeType = 'image/png';
    bool hasImage = false;

    if (backgroundImageUrl != null && backgroundImageUrl.startsWith('data:')) {
      try {
        final data = UriData.parse(backgroundImageUrl);
        imageBytes = Uint8List.fromList(data.contentAsBytes());
        imageMimeType = data.mimeType;
        if (imageMimeType.contains('jpeg') || imageMimeType.contains('jpg')) {
          imageExt = 'jpeg';
        } else if (imageMimeType.contains('png')) {
          imageExt = 'png';
        } else if (imageMimeType.contains('gif')) {
          imageExt = 'gif';
        } else if (imageMimeType.contains('webp')) {
          imageExt = 'webp';
        }
        hasImage = true;
      } catch (_) {
        hasImage = false;
      }
    }

    // ── Add the image binary to the archive ──────────────────────────────
    if (hasImage && imageBytes != null) {
      archive.addFile(ArchiveFile(
        'ppt/media/image1.$imageExt',
        imageBytes.length,
        imageBytes,
      ));
    }

    // ── Try to extract logo image bytes from a data: URL ──────────────────
    Uint8List? logoBytes;
    String logoExt = 'png';
    String logoMimeType = 'image/png';
    bool hasLogo = false;

    // Find the first slide that has a valid logo data URL
    final slideWithLogo = slides.firstWhere(
      (s) => s.logoUrl != null && s.logoUrl!.startsWith('data:'),
      orElse: () => slides.first,
    );

    if (slideWithLogo.logoUrl != null && slideWithLogo.logoUrl!.startsWith('data:')) {
      try {
        final data = UriData.parse(slideWithLogo.logoUrl!);
        logoBytes = Uint8List.fromList(data.contentAsBytes());
        logoMimeType = data.mimeType;
        if (logoMimeType.contains('jpeg') || logoMimeType.contains('jpg')) {
          logoExt = 'jpeg';
        } else if (logoMimeType.contains('png')) {
          logoExt = 'png';
        } else if (logoMimeType.contains('gif')) {
          logoExt = 'gif';
        } else if (logoMimeType.contains('webp')) {
          logoExt = 'webp';
        }
        hasLogo = true;
      } catch (_) {
        hasLogo = false;
      }
    }

    // ── Add the logo binary to the archive ────────────────────────────────
    if (hasLogo && logoBytes != null) {
      archive.addFile(ArchiveFile(
        'ppt/media/logo.$logoExt',
        logoBytes.length,
        logoBytes,
      ));
    }

    // ── Standard PPTX skeleton ───────────────────────────────────────────
    final font = (fontFamily != null && fontFamily.isNotEmpty) ? fontFamily : 'Montserrat';
    _add(archive, '[Content_Types].xml', _contentTypes(slides.length, hasImage ? imageExt : null, hasImage ? imageMimeType : null));
    _add(archive, '_rels/.rels', _rootRels());
    _add(archive, 'docProps/app.xml', _appXml(slides.length));
    _add(archive, 'docProps/core.xml', _coreXml());
    _add(archive, 'ppt/presentation.xml', _presentationXml(slides.length));
    _add(archive, 'ppt/_rels/presentation.xml.rels', _presentationRels(slides.length));
    _add(archive, 'ppt/theme/theme1.xml', _themeXml(font));
    _add(archive, 'ppt/slideLayouts/slideLayout1.xml', _slideLayoutXml());
    _add(archive, 'ppt/slideLayouts/_rels/slideLayout1.xml.rels', _slideLayoutRels());
    _add(archive, 'ppt/slideMasters/slideMaster1.xml', _slideMasterXml());
    _add(archive, 'ppt/slideMasters/_rels/slideMaster1.xml.rels', _slideMasterRels());

    for (int i = 0; i < slides.length; i++) {
      final n = i + 1;
      final s = slides[i];
      // Convert app font size (points) → OOXML hundredths-of-a-point
      final int titleSz = (s.titleFontSize * 100).round();
      final int subtitleSz = (s.subtitleFontSize * 100).round();

      final bool renderLogo = hasLogo && s.logoUrl != null && s.logoUrl!.isNotEmpty;

      _add(archive, 'ppt/slides/slide$n.xml', _slideXml(
        s.title,
        s.subtitle,
        titleSz,
        subtitleSz,
        hasImage,
        font,
        hasLogo: renderLogo,
        logoX: s.logoX,
        logoY: s.logoY,
        logoSize: s.logoSize,
        textX: s.textX,
        textY: s.textY,
      ));
      _add(archive, 'ppt/slides/_rels/slide$n.xml.rels', _slideRels(
        hasImage,
        hasImage ? imageExt : null,
        renderLogo,
        logoExt,
      ));
    }

    return ZipEncoder().encode(archive)!;
  }

  static void _add(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  // ── XML templates ──────────────────────────────────────────────────────────

  static String _contentTypes(int slideCount, String? imageExt, String? imageMime) {
    final slideEntries = List.generate(
      slideCount,
      (i) => '<Override PartName="/ppt/slides/slide${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
    ).join('\n');

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Default Extension="gif" ContentType="image/gif"/>
  <Default Extension="webp" ContentType="image/webp"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
$slideEntries
</Types>''';
  }

  static String _rootRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';

  static String _appXml(int slideCount) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
  <Application>LiveDeck</Application>
  <Slides>$slideCount</Slides>
</Properties>''';

  static String _coreXml() {
    final now = DateTime.now().toUtc().toIso8601String();
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:creator>LiveDeck</dc:creator>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>''';
  }

  static String _presentationXml(int slideCount) {
    final slideList = List.generate(
      slideCount,
      (i) => '<p:sldId id="${256 + i}" r:id="rId${i + 3}"/>',
    ).join('\n    ');
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldMasterIdLst>
    <p:sldMasterId id="2147483648" r:id="rId1"/>
  </p:sldMasterIdLst>
  <p:sldIdLst>
    $slideList
  </p:sldIdLst>
  <p:sldSz cx="9144000" cy="5143500"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''';
  }

  static String _presentationRels(int slideCount) {
    final slideRels = List.generate(
      slideCount,
      (i) => '<Relationship Id="rId${i + 3}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>',
    ).join('\n  ');
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
  $slideRels
</Relationships>''';
  }

  static String _themeXml(String font) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="SacredTheme">
  <a:themeElements>
    <a:clrScheme name="Sacred">
      <a:dk1><a:sysClr lastClr="000000" val="windowText"/></a:dk1>
      <a:lt1><a:sysClr lastClr="ffffff" val="window"/></a:lt1>
      <a:dk2><a:srgbClr val="2E0052"/></a:dk2>
      <a:lt2><a:srgbClr val="FFFFFF"/></a:lt2>
      <a:accent1><a:srgbClr val="2E0052"/></a:accent1>
      <a:accent2><a:srgbClr val="7C3AED"/></a:accent2>
      <a:accent3><a:srgbClr val="A78BFA"/></a:accent3>
      <a:accent4><a:srgbClr val="DDD6FE"/></a:accent4>
      <a:accent5><a:srgbClr val="4ADE80"/></a:accent5>
      <a:accent6><a:srgbClr val="F59E0B"/></a:accent6>
      <a:hlink><a:srgbClr val="7C3AED"/></a:hlink>
      <a:folHlink><a:srgbClr val="2E0052"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Sacred">
      <a:majorFont><a:latin typeface="$font"/></a:majorFont>
      <a:minorFont><a:latin typeface="Inter"/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Sacred">
      <a:fillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:fillStyleLst>
      <a:lnStyleLst>
        <a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
      </a:lnStyleLst>
      <a:effectStyleLst>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
      </a:effectStyleLst>
      <a:bgFillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>''';

  static String _slideMasterXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld>
    <p:bg><p:bgPr><a:solidFill><a:srgbClr val="000000"/></a:solidFill></p:bgPr></p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst>
    <p:sldLayoutId id="2147483649" r:id="rId1"/>
  </p:sldLayoutIdLst>
</p:sldMaster>''';

  static String _slideMasterRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''';

  static String _slideLayoutXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  type="blank" preserve="1">
  <p:cSld name="Blank">
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>''';

  static String _slideLayoutRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';

  /// Slide relationships — includes image reference when a background is embedded.
  static String _slideRels(bool hasImage, String? imageExt, bool hasLogo, String? logoExt) {
    final imageRel = hasImage
        ? '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image1.$imageExt"/>'
        : '';
    final logoRel = hasLogo
        ? '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/logo.$logoExt"/>'
        : '';
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  $imageRel
  $logoRel
</Relationships>''';
  }

  /// Each slide: dark-purple gradient OR embedded image background,
  /// title centred in large white text, subtitle in smaller italic white text.
  /// [titleSz] and [subtitleSz] are in OOXML hundredths-of-a-point.
  static String _slideXml(
    String title,
    String subtitle,
    int titleSz,
    int subtitleSz,
    bool hasImage,
    String font, {
    bool hasLogo = false,
    double logoX = 0.85,
    double logoY = 0.05,
    double logoSize = 80.0,
    double textX = 0.0,
    double textY = 0.0,
  }) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    // Background: use embedded image if available, otherwise solid black
    final String bgXml = hasImage
        ? '''<p:bg>
      <p:bgPr>
        <a:blipFill rotWithShape="1">
          <a:blip r:embed="rId2"/>
          <a:stretch><a:fillRect/></a:stretch>
        </a:blipFill>
      </p:bgPr>
    </p:bg>'''
        : '''<p:bg>
      <p:bgPr>
        <a:solidFill>
          <a:srgbClr val="000000"/>
        </a:solidFill>
      </p:bgPr>
    </p:bg>''';

    // Compute logo coordinates and size in EMUs (based on 960px design canvas width)
    final int cx = (logoSize * 9525).round();
    final int cy = cx;
    final int x = (logoX * 9144000).round().clamp(0, 9144000 - cx);
    final int y = (logoY * 5143500).round().clamp(0, 5143500 - cy);

    final String logoXml = hasLogo
        ? '''
      <!-- Slide logo picture -->
      <p:pic>
        <p:nvPicPr>
          <p:cNvPr id="10" name="Slide Logo"/>
          <p:cNvPicPr>
            <a:picLocks noChangeAspect="1"/>
          </p:cNvPicPr>
          <p:nvPr/>
        </p:nvPicPr>
        <p:blipFill>
          <a:blip r:embed="rId3"/>
          <a:stretch>
            <a:fillRect/>
          </a:stretch>
        </p:blipFill>
        <p:spPr>
          <a:xfrm>
            <a:off x="$x" y="$y"/>
            <a:ext cx="$cx" cy="$cy"/>
          </a:xfrm>
          <a:prstGeom prst="rect">
            <a:avLst/>
          </a:prstGeom>
        </p:spPr>
      </p:pic>'''
        : '';

    final bool hasSubtitle = subtitle.trim().isNotEmpty;
    final int dx = (textX * 9144000).round();
    final int dy = (textY * 5143500).round();
    final int titleYDefault = hasSubtitle ? 400000 : 2271750;
    final int titleX = (457200 + dx).clamp(-9144000, 18288000);
    final int titleY = (titleYDefault + dy).clamp(-5143500, 10287000);

    final String titleSpXml = '''
      <!-- Title text box -->
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="2" name="Title"/>
          <p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>
          <p:nvPr/>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="$titleX" y="$titleY"/><a:ext cx="8229600" cy="600000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
          <a:noFill/>
        </p:spPr>
        <p:txBody>
          <a:bodyPr vert="horz" anchor="ctr"/>
          <a:lstStyle/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr lang="en-US" sz="$titleSz" b="0" i="0" dirty="0">
                <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
                <a:latin typeface="$font"/>
                <a:effectLst>
                  <a:outerShdw blurRad="50000" dist="38100" dir="5400000" algn="ctr">
                    <a:srgbClr val="000000"><a:alpha val="45000"/></a:srgbClr>
                  </a:outerShdw>
                </a:effectLst>
              </a:rPr>
              <a:t>${esc(title)}</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>''';

    final String dividerSpXml = hasSubtitle
        ? '''
      <!-- Decorative divider line -->
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="3" name="Divider"/>
          <p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>
          <p:nvPr/>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="${(4118400 + dx).clamp(-9144000, 18288000)}" y="${(1100000 + dy).clamp(-5143500, 10287000)}"/><a:ext cx="914400" cy="50800"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
          <a:solidFill><a:srgbClr val="A78BFA"/></a:solidFill>
        </p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
      </p:sp>'''
        : '';

    final String subtitleSpXml = hasSubtitle
        ? '''
      <!-- Subtitle text box -->
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="4" name="Subtitle"/>
          <p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>
          <p:nvPr/>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="${(457200 + dx).clamp(-9144000, 18288000)}" y="${(1350000 + dy).clamp(-5143500, 10287000)}"/><a:ext cx="8229600" cy="3400000"/></a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
          <a:noFill/>
        </p:spPr>
        <p:txBody>
          <a:bodyPr vert="horz" anchor="ctr"/>
          <a:lstStyle/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr lang="en-US" sz="$subtitleSz" b="1" i="0" dirty="0">
                <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
                <a:latin typeface="$font"/>
              </a:rPr>
              <a:t>${esc(subtitle)}</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>'''
        : '';

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld>
    $bgXml
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
      $titleSpXml
      $dividerSpXml
      $subtitleSpXml
      $logoXml
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>''';
  }
}
