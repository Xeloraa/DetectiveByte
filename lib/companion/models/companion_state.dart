import '../../core/constants/app_constants.dart';
import 'companion_position.dart';
import 'idle_action.dart';
import 'investigation_phase.dart';

/// Immutable snapshot of the companion's current visual state.
class CompanionState {
  const CompanionState({
    required this.position,
    required this.isEnabled,
    required this.idleAnimationsEnabled,
    required this.startWithSystem,
    required this.transparency,
    required this.isTapped,
    required this.currentIdleAction,
    required this.speechText,
    required this.idleProgress,
    required this.blinkAmount,
    required this.casesSolved,
    required this.missionProgress,
    required this.missionTarget,
    required this.phase,
    required this.analyzeProgress,
    this.videoPlatform,
    this.videoTitle,
    this.videoAuthor,
    this.videoThumbnailUrl,
  });

  final CompanionPosition position;
  final bool isEnabled;
  final bool idleAnimationsEnabled;
  final bool startWithSystem;
  final double transparency;
  final bool isTapped;
  final IdleAction currentIdleAction;
  final String? speechText;
  final double idleProgress;
  final double blinkAmount;
  final int casesSolved;
  final int missionProgress;
  final int missionTarget;
  final InvestigationPhase phase;
  final double analyzeProgress;

  /// Set when the last investigation found a real TikTok/YouTube/Reels link
  /// (e.g. on the clipboard) — null when investigating with no link found.
  final String? videoPlatform;
  final String? videoTitle;
  final String? videoAuthor;
  final String? videoThumbnailUrl;

  bool get missionComplete => missionProgress >= missionTarget;

  factory CompanionState.initial() => CompanionState(
        position: CompanionPosition.defaultPosition(),
        isEnabled: true,
        idleAnimationsEnabled: true,
        startWithSystem: false,
        transparency: AppConstants.defaultTransparency,
        isTapped: false,
        currentIdleAction: IdleAction.none,
        speechText: AppConstants.welcomeSpeech,
        idleProgress: 0,
        blinkAmount: 0,
        casesSolved: 0,
        missionProgress: 0,
        missionTarget: 1,
        phase: InvestigationPhase.greeting,
        analyzeProgress: 0,
      );

  CompanionState copyWith({
    CompanionPosition? position,
    bool? isEnabled,
    bool? idleAnimationsEnabled,
    bool? startWithSystem,
    double? transparency,
    bool? isTapped,
    IdleAction? currentIdleAction,
    String? speechText,
    bool clearSpeech = false,
    double? idleProgress,
    double? blinkAmount,
    int? casesSolved,
    int? missionProgress,
    int? missionTarget,
    InvestigationPhase? phase,
    double? analyzeProgress,
    String? videoPlatform,
    String? videoTitle,
    String? videoAuthor,
    String? videoThumbnailUrl,
    bool clearVideo = false,
  }) {
    return CompanionState(
      position: position ?? this.position,
      isEnabled: isEnabled ?? this.isEnabled,
      idleAnimationsEnabled:
          idleAnimationsEnabled ?? this.idleAnimationsEnabled,
      startWithSystem: startWithSystem ?? this.startWithSystem,
      transparency: transparency ?? this.transparency,
      isTapped: isTapped ?? this.isTapped,
      currentIdleAction: currentIdleAction ?? this.currentIdleAction,
      speechText: clearSpeech ? null : (speechText ?? this.speechText),
      idleProgress: idleProgress ?? this.idleProgress,
      blinkAmount: blinkAmount ?? this.blinkAmount,
      casesSolved: casesSolved ?? this.casesSolved,
      missionProgress: missionProgress ?? this.missionProgress,
      missionTarget: missionTarget ?? this.missionTarget,
      phase: phase ?? this.phase,
      analyzeProgress: analyzeProgress ?? this.analyzeProgress,
      videoPlatform: clearVideo ? null : (videoPlatform ?? this.videoPlatform),
      videoTitle: clearVideo ? null : (videoTitle ?? this.videoTitle),
      videoAuthor: clearVideo ? null : (videoAuthor ?? this.videoAuthor),
      videoThumbnailUrl:
          clearVideo ? null : (videoThumbnailUrl ?? this.videoThumbnailUrl),
    );
  }
}
