// lib/connectors/connector_manager.dart
import 'connector_contract.dart';
import 'gemini_connector.dart';
import 'slidesgpt_connector.dart';
import 'gamma_connector.dart';
import 'presentations_ai_connector.dart';
import '../settings_state.dart';

class ConnectorManager {
  ConnectorManager._();
  static final ConnectorManager instance = ConnectorManager._();

  final Map<String, PresentationConnector> _connectors = {};

  /// Initialize and register all active connections.
  void initialize() {
    _connectors.clear();
    
    final settings = AppSettings.instance;
    // Always register Gemini (it can also fallback or guide configure)
    register(GeminiConnector(settings.geminiApiKey));
    
    // Register SlidesGPT if API Key is configured
    if (settings.slidesGptApiKey.isNotEmpty) {
      register(SlidesGptConnector(settings.slidesGptApiKey));
    }
    
    // Register Gamma if API Key is configured
    if (settings.gammaApiKey.isNotEmpty) {
      register(GammaConnector(settings.gammaApiKey));
    }

    // Register Presentations.ai if API Key is configured
    if (settings.presentationsAiApiKey.isNotEmpty) {
      register(PresentationsAiConnector(settings.presentationsAiApiKey));
    }
  }

  void register(PresentationConnector connector) {
    _connectors[connector.id] = connector;
  }

  List<PresentationConnector> get availableConnectors => _connectors.values.toList();

  PresentationConnector? getConnector(String id) => _connectors[id];
}
