import 'package:flutter_test/flutter_test.dart';
import 'package:presentation_app/song_to_slides_page.dart';

void main() {
  test('parseSongToSlides splits by header and sets section name as slide title', () {
    const title = 'Amazing Grace';
    const lyrics = '''
CHORUS:
Amazing grace how sweet the sound
That saved a wretch like me

VS1:
I once was lost, but now am found
Was blind, but now I see
''';

    final slides = parseSongToSlides(lyrics, title, 2);

    // Slide 1: Title slide
    expect(slides[0].title, equals(title));
    expect(slides[0].subtitle, isEmpty);

    // Slide 2: Chorus (first 2 lines)
    expect(slides[1].title, equals('CHORUS'));
    expect(slides[1].subtitle, equals('Amazing grace how sweet the sound\nThat saved a wretch like me'));

    // Slide 3: VS1 (first 2 lines)
    expect(slides[2].title, equals('VS1'));
    expect(slides[2].subtitle, equals('I once was lost, but now am found\nWas blind, but now I see'));
  });

  test('parseSongToSlides handles inline lyrics next to header', () {
    const title = 'My Song';
    const lyrics = '''
BRIDGE:When the billows are raging
when the storms of confusion
''';

    final slides = parseSongToSlides(lyrics, title, 2);

    expect(slides[1].title, equals('BRIDGE'));
    expect(slides[1].subtitle, equals('When the billows are raging\nwhen the storms of confusion'));
  });

  test('parseSongToSlides respects arrangements and multipliers', () {
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

    // Let's call the parser
    final slides = parseSongToSlides(lyrics, title, 1);

    // Slide 0: Title Slide
    expect(slides[0].title, equals(title));

    // Arrangements order: CHR (x1), VS1 (x1), BRIDGE (x2)
    // CHORUS has 1 line (I go to the rock) -> 1 slide
    expect(slides[1].title, equals('CHORUS'));
    expect(slides[1].subtitle, equals('I go to the rock'));

    // VS1 has 1 line (Where do I go?) -> 1 slide
    expect(slides[2].title, equals('VS1'));
    expect(slides[2].subtitle, equals('Where do I go?'));

    // BRIDGE has 1 line (Sweet comfort I received) -> 2 slides (since BRIDGEX2)
    expect(slides[3].title, equals('BRIDGE'));
    expect(slides[3].subtitle, equals('Sweet comfort I received'));

    expect(slides[4].title, equals('BRIDGE'));
    expect(slides[4].subtitle, equals('Sweet comfort I received'));

    expect(slides.length, equals(5));
  });
}
