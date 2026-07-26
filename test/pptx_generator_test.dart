import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:presentation_app/pptx_generator.dart';

void main() {
  test('PPTX Generation Verification - SlideMaster styles and PowerPoint Sections', () async {
    final List<({
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
      int bgColorValue,
      int textColorValue,
    })> slides = [
      (
        title: 'Slide 1 Title',
        subtitle: 'Slide 1 Subtitle',
        titleFontSize: 36.0,
        subtitleFontSize: 20.0,
        logoUrl: null,
        logoX: 0.0,
        logoY: 0.0,
        logoSize: 0.0,
        textX: 0.0,
        textY: 0.0,
        bgColorValue: 0xFF000000,
        textColorValue: 0xFFFFFFFF,
      ),
      (
        title: 'Slide 2 Title',
        subtitle: 'Slide 2 Subtitle',
        titleFontSize: 36.0,
        subtitleFontSize: 20.0,
        logoUrl: null,
        logoX: 0.0,
        logoY: 0.0,
        logoSize: 0.0,
        textX: 0.0,
        textY: 0.0,
        bgColorValue: 0xFF000000,
        textColorValue: 0xFFFFFFFF,
      ),
      (
        title: 'Slide 3 Title',
        subtitle: 'Slide 3 Subtitle',
        titleFontSize: 36.0,
        subtitleFontSize: 20.0,
        logoUrl: null,
        logoX: 0.0,
        logoY: 0.0,
        logoSize: 0.0,
        textX: 0.0,
        textY: 0.0,
        bgColorValue: 0xFF000000,
        textColorValue: 0xFFFFFFFF,
      ),
    ];

    final sections = [
      (name: 'Verse 1', slideIndices: [0, 1]),
      (name: 'Chorus', slideIndices: [2]),
    ];

    // Expose a public wrapper inside PptxGenerator so that tests can retrieve PPTX bytes.
    final bytes = await PptxGenerator.buildPptxForTesting(slides, sections: sections);
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Verify existence of slide master and presentation XML files
    final presentationFile = archive.findFile('ppt/presentation.xml');
    final slideMasterFile = archive.findFile('ppt/slideMasters/slideMaster1.xml');

    expect(presentationFile, isNotNull);
    expect(slideMasterFile, isNotNull);

    final presentationXml = utf8.decode(presentationFile!.content);
    final slideMasterXml = utf8.decode(slideMasterFile!.content);

    // 2. Verify p14 namespace and native sections list in presentation.xml
    expect(presentationXml, contains('xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main"'));
    expect(presentationXml, contains('<p14:sectionLst'));
    expect(presentationXml, contains('<p14:section name="Verse 1"'));
    expect(presentationXml, contains('<p14:section name="Chorus"'));
    expect(presentationXml, contains('<p14:sldId id="256"/>'));
    expect(presentationXml, contains('<p14:sldId id="257"/>'));
    expect(presentationXml, contains('<p14:sldId id="258"/>'));

    // 3. Verify slideMaster has mandatory txStyles element to avoid repair dialogs
    expect(slideMasterXml, contains('<p:txStyles>'));
    expect(slideMasterXml, contains('<p:titleStyle/>'));
    expect(slideMasterXml, contains('<p:bodyStyle/>'));
    expect(slideMasterXml, contains('<p:otherStyle/>'));
  });
}
