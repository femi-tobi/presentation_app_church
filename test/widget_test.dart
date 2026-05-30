import 'package:flutter_test/flutter_test.dart';
import 'package:presentation_app/settings_state.dart';

void main() {
  test('AppSettings initializes successfully', () {
    final settings = AppSettings.instance;
    expect(settings, isNotNull);
    expect(settings.activeSlides, isNotEmpty);
  });
}
