import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:presentation_app/pptx_parser.dart';

void main() {
  test('PPTX Parser Verification - Slides and shapes extraction', () async {
    // Generate a minimal mock PPTX zip in memory
    final archive = Archive();

    final slide1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p>
            <a:r>
              <a:t>Verse 1</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:txBody>
          <a:p>
            <a:r>
              <a:t>Amazing grace how sweet the sound</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

    final bytes1 = utf8.encode(slide1Xml);
    archive.addFile(ArchiveFile('ppt/slides/slide1.xml', bytes1.length, bytes1));

    final zipBytes = ZipEncoder().encode(archive)!;
    final slides = PptxParser.parsePptx(Uint8List.fromList(zipBytes), 'Test Presenter');

    expect(slides.length, 1);
    expect(slides.first.title, 'Verse 1');
    expect(slides.first.subtitle, 'Amazing grace how sweet the sound');
  });
}
