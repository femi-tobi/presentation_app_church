import 'package:flutter_test/flutter_test.dart';
import 'package:presentation_app/song_to_slides_page.dart';

void main() {
  test('parseSongToSlides splits by header and groups slides into sections', () {
    const title = 'Amazing Grace';
    const lyrics = '''
CHORUS:
Amazing grace how sweet the sound
That saved a wretch like me

VS1:
I once was lost, but now am found
Was blind, but now I see
''';

    final result = parseSongToSlides(lyrics, title, 2);
    final slides = result.slides;
    final sections = result.sections;

    // We should have 3 sections: TITLE, CHORUS, VS1
    expect(sections.length, equals(3));
    expect(sections[0].name, equals('TITLE'));
    expect(sections[1].name, equals('CHORUS'));
    expect(sections[2].name, equals('VS1'));

    // Slide 1: Title slide (TITLE section)
    expect(slides[0].title, equals(title));
    expect(slides[0].subtitle, isEmpty);
    expect(slides[0].sectionId, equals(sections[0].id));
    expect(sections[0].slideIds, contains(slides[0].id));

    // Slide 2: Chorus (first 2 lines) - CHORUS section
    expect(slides[1].title, equals('')); // slide keeps own empty title
    expect(slides[1].subtitle, equals('Amazing grace how sweet the sound\nThat saved a wretch like me'));
    expect(slides[1].sectionId, equals(sections[1].id));
    expect(sections[1].slideIds, contains(slides[1].id));

    // Slide 3: VS1 (first 2 lines) - VS1 section
    expect(slides[2].title, equals('')); // slide keeps own empty title
    expect(slides[2].subtitle, equals('I once was lost, but now am found\nWas blind, but now I see'));
    expect(slides[2].sectionId, equals(sections[2].id));
    expect(sections[2].slideIds, contains(slides[2].id));
  });

  test('parseSongToSlides handles inline lyrics next to header', () {
    const title = 'My Song';
    const lyrics = '''
BRIDGE:When the billows are raging
when the storms of confusion
''';

    final result = parseSongToSlides(lyrics, title, 2);
    final slides = result.slides;
    final sections = result.sections;

    expect(sections.length, equals(2));
    expect(sections[1].name, equals('BRIDGE'));
    expect(slides[1].title, equals(''));
    expect(slides[1].subtitle, equals('When the billows are raging\nwhen the storms of confusion'));
  });

  test('parseSongToSlides respects arrangements and duplicates sections/slides', () {
    const title = 'Rock of Ages';
    const lyrics = '''
CHORUS:
I go to the rock

VS1:
Where do I go?

ARRANGEMENTS:
CHRX1
VS1
BRIDGEX2

BRIDGE:
Sweet comfort I received
''';

    final result = parseSongToSlides(lyrics, title, 1);
    final slides = result.slides;
    final sections = result.sections;

    // Arrangements order: TITLE (fallback/default title section), CHORUS (x1), VS1 (x1), BRIDGE (x2)
    // Total sections: 1 + 1 + 1 + 2 = 5 sections
    expect(sections.length, equals(5));
    expect(sections[0].name, equals('TITLE'));
    expect(sections[1].name, equals('CHORUS'));
    expect(sections[2].name, equals('VS1'));
    expect(sections[3].name, equals('BRIDGE'));
    expect(sections[4].name, equals('BRIDGE'));

    // Slide 0: Title Slide
    expect(slides[0].title, equals(title));
    expect(slides[0].sectionId, equals(sections[0].id));

    // CHORUS has 1 line (I go to the rock) -> 1 slide in section 1
    expect(slides[1].title, equals(''));
    expect(slides[1].subtitle, equals('I go to the rock'));
    expect(slides[1].sectionId, equals(sections[1].id));
    expect(sections[1].slideIds, equals([slides[1].id]));

    // VS1 has 1 line (Where do I go?) -> 1 slide in section 2
    expect(slides[2].title, equals(''));
    expect(slides[2].subtitle, equals('Where do I go?'));
    expect(slides[2].sectionId, equals(sections[2].id));
    expect(sections[2].slideIds, equals([slides[2].id]));

    // BRIDGE has 1 line (Sweet comfort I received) -> 2 separate sections (since BRIDGEX2)
    // Section 3: first instance of BRIDGE
    expect(slides[3].title, equals(''));
    expect(slides[3].subtitle, equals('Sweet comfort I received'));
    expect(slides[3].sectionId, equals(sections[3].id));
    expect(sections[3].slideIds, equals([slides[3].id]));

    // Section 4: second instance of BRIDGE
    expect(slides[4].title, equals(''));
    expect(slides[4].subtitle, equals('Sweet comfort I received'));
    expect(slides[4].sectionId, equals(sections[4].id));
    expect(sections[4].slideIds, equals([slides[4].id]));

    expect(slides.length, equals(5));
  });
}
