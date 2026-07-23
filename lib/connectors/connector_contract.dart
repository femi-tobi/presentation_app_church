// lib/connectors/connector_contract.dart
import '../settings_state.dart';

/// Configuration options passed to any presentation generator.
class PresentationConfig {
  final String themeName;
  final int targetSlideCount;
  final String primaryColorHex;
  final String fontPreference;
  final String stylePrompt;

  PresentationConfig({
    this.themeName = 'Modern',
    this.targetSlideCount = 8,
    this.primaryColorHex = '#2E0052',
    this.fontPreference = 'Inter',
    this.stylePrompt = '',
  });
}

/// The unified interface all presentation software connectors must implement.
abstract class PresentationConnector {
  /// The unique identifier of the connector (e.g., 'gemini', 'gamma').
  String get id;

  /// User-friendly name displayed in settings/UI.
  String get name;

  /// Brief description of the service's features.
  String get description;

  /// Whether this generator outputs SlideData for local editor (like Gemini)
  /// or a direct binary PPTX download link (like Gamma/SlidesGPT).
  bool get generatesLocalSlides;

  /// Takes user input/prompt and returns structured slides for local visual editor.
  /// Used when [generatesLocalSlides] is true.
  Future<List<SlideData>> generatePresentation(
    String prompt, 
    PresentationConfig config,
  );

  /// Takes user input/prompt and returns raw binary bytes of a compiled PowerPoint file.
  /// Used when [generatesLocalSlides] is false.
  Future<List<int>> downloadPresentationBytes(
    String prompt, 
    PresentationConfig config,
  );
}
