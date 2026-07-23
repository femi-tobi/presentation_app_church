import 'package:flutter_test/flutter_test.dart';
import 'package:presentation_app/settings_state.dart';
import 'package:presentation_app/connectors/connector_manager.dart';

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

  test('AppSettings persists slidesGptApiKey, gammaApiKey, and presentationsAiApiKey, and ConnectorManager registers them', () {
    final settings = AppSettings.instance;

    // Set test keys
    settings.slidesGptApiKey = 'test_slidesgpt_key';
    settings.gammaApiKey = 'test_gamma_key';
    settings.presentationsAiApiKey = 'test_presentations_ai_key';

    expect(settings.slidesGptApiKey, equals('test_slidesgpt_key'));
    expect(settings.gammaApiKey, equals('test_gamma_key'));
    expect(settings.presentationsAiApiKey, equals('test_presentations_ai_key'));

    // Test ConnectorManager registers them
    final manager = ConnectorManager.instance;
    manager.initialize();

    final slidesGptConnector = manager.getConnector('slidesgpt');
    final gammaConnector = manager.getConnector('gamma');
    final presentationsAiConnector = manager.getConnector('presentations_ai');
    final geminiConnector = manager.getConnector('gemini');

    expect(slidesGptConnector, isNotNull);
    expect(gammaConnector, isNotNull);
    expect(presentationsAiConnector, isNotNull);
    expect(geminiConnector, isNotNull);

    expect(slidesGptConnector!.name, equals('SlidesGPT'));
    expect(gammaConnector!.name, equals('Gamma App'));
    expect(presentationsAiConnector!.name, equals('Presentations.ai'));

    // Clean up keys
    settings.slidesGptApiKey = '';
    settings.gammaApiKey = '';
    settings.presentationsAiApiKey = '';
    
    manager.initialize();
    expect(manager.getConnector('slidesgpt'), isNull);
    expect(manager.getConnector('gamma'), isNull);
    expect(manager.getConnector('presentations_ai'), isNull);
  });
}
