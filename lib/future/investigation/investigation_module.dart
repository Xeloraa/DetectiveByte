import 'investigation_event.dart';

/// Contract for future platform-specific investigation modules.
///
/// Implementations (TikTok, Instagram Reels, YouTube Shorts, OCR, etc.)
/// plug in without modifying the companion layer.
abstract interface class InvestigationModule {
  String get id;
  String get displayName;

  bool canHandle(String url);

  Future<void> startInvestigation(String url);

  Stream<InvestigationEvent> get events;
}

/// Registry for future modules — companion listens here, not inside widgets.
abstract interface class InvestigationModuleRegistry {
  void register(InvestigationModule module);

  List<InvestigationModule> get modules;

  InvestigationModule? findForUrl(String url);
}

/// Stub registry for MVP. Modules register here when implemented.
class InvestigationModuleRegistryImpl implements InvestigationModuleRegistry {
  final List<InvestigationModule> _modules = [];

  @override
  void register(InvestigationModule module) => _modules.add(module);

  @override
  List<InvestigationModule> get modules => List.unmodifiable(_modules);

  @override
  InvestigationModule? findForUrl(String url) {
    for (final module in _modules) {
      if (module.canHandle(url)) return module;
    }
    return null;
  }
}
