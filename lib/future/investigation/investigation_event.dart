/// Events that future investigation modules may emit.
///
/// Byte reacts only to user taps, investigation events, and completed missions.
/// Never to player absence or emotional triggers.
enum InvestigationEventType {
  started,
  clueFound,
  sourceCompared,
  missionCompleted,
  needsReview,
}

class InvestigationEvent {
  const InvestigationEvent({
    required this.type,
    required this.prompt,
    this.platform,
  });

  final InvestigationEventType type;

  /// Investigation question — never a verdict.
  final String prompt;
  final String? platform;
}
