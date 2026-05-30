import 'package:flutter_test/flutter_test.dart';
import 'package:presentation_app/settings_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppSettings singleton initializes successfully without Stack Overflow', () {
    // Access the singleton instance
    final settings = AppSettings.instance;
    
    // Verify the instance is not null
    expect(settings, isNotNull);
    
    // Verify that default slides were populated successfully
    expect(settings.activeSlides, isNotEmpty);
    expect(settings.activeSlides.length, equals(4));
    
    // Verify that default slide logoUrl is null when no custom logo is uploaded
    final firstSlide = settings.activeSlides.first;
    expect(firstSlide.logoUrl, isNull);
  });

  test('AppSettings enforces 1 PDF conversion per week rate limit', () {
    final settings = AppSettings.instance;

    // Reset last conversion time
    settings.lastPdfConversionTime = null;
    expect(settings.canConvertPdf, isTrue);
    expect(settings.nextPdfConversionTimeRemaining, isEmpty);

    // Record a conversion
    settings.recordPdfConversion();
    expect(settings.canConvertPdf, isFalse);
    expect(settings.nextPdfConversionTimeRemaining, isNotEmpty);

    // Simulate 8 days later
    settings.lastPdfConversionTime = DateTime.now().subtract(const Duration(days: 8));
    expect(settings.canConvertPdf, isTrue);
    expect(settings.nextPdfConversionTimeRemaining, isEmpty);

    // Clean up
    settings.lastPdfConversionTime = null;
  });
}
