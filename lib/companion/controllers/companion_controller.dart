import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard;

import '../../core/constants/app_constants.dart';
import '../../future/investigation/investigation_event.dart';
import '../../services/desktop_overlay.dart';
import '../../services/storage/local_storage_service.dart';
import '../../services/video_lookup_service.dart';
import '../animations/idle_animation_controller.dart';
import '../models/companion_position.dart';
import '../models/companion_state.dart';
import '../models/idle_action.dart';
import '../models/investigation_phase.dart';

/// Central state for Detective Byte — companion + mission layer.
class CompanionController extends ChangeNotifier {
  CompanionController({required this._storage}) {
    _bootstrap();
  }

  final LocalStorageService _storage;

  void _bootstrap() {
    _state = CompanionState.initial().copyWith(
      position: _storage.loadPosition(),
      isEnabled: _storage.loadEnabled(),
      idleAnimationsEnabled: _storage.loadIdleAnimations(),
      startWithSystem: _storage.loadStartWithSystem(),
      transparency: _storage.loadTransparency(),
      casesSolved: _storage.loadCasesSolved(),
      missionProgress: _storage.loadMissionProgress(),
      speechText: AppConstants.welcomeSpeech,
      phase: InvestigationPhase.greeting,
    );

    _idleController = IdleAnimationController(onTick: _onIdleTick);
    if (_state.idleAnimationsEnabled && _state.isEnabled) {
      _idleController.start();
    }

    _speechTimer = Timer(AppConstants.speechDuration, () {
      if (_state.phase == InvestigationPhase.greeting) {
        _state = _state.copyWith(
          phase: InvestigationPhase.idle,
          clearSpeech: true,
          isTapped: false,
        );
        notifyListeners();
      }
    });
  }
  final Random _random = Random();

  late CompanionState _state;
  late IdleAnimationController _idleController;
  Timer? _speechTimer;
  Timer? _analyzeTimer;

  CompanionState get state => _state;

  void _onIdleTick() {
    if (_state.phase != InvestigationPhase.idle) return;
    _state = _state.copyWith(
      currentIdleAction: _idleController.currentAction,
      idleProgress: _idleController.progress,
      blinkAmount: _idleController.blinkAmount,
    );
    notifyListeners();
  }

  Future<void> updatePosition(CompanionPosition position) async {
    _state = _state.copyWith(position: position);
    notifyListeners();
    await _storage.savePosition(position);
  }

  Future<void> resetPosition() async {
    final defaultPos = CompanionPosition.defaultPosition();
    await updatePosition(defaultPos);
  }

  Future<void> setEnabled(bool enabled) async {
    _state = _state.copyWith(isEnabled: enabled);
    if (!enabled) {
      _idleController.pause();
      _cancelInvestigation();
      _state = _state.copyWith(
        phase: InvestigationPhase.idle,
        clearSpeech: true,
        isTapped: false,
      );
    } else if (_state.idleAnimationsEnabled) {
      _idleController.resume();
      _idleController.setEnabled(true);
    }
    notifyListeners();
    await _storage.saveEnabled(enabled);

    // The on/off switch is "quit the desktop companion," not "hide Byte but
    // keep the window running" — there's no product surface for a
    // disabled-but-open state, so treat turning it off as a close request.
    if (!enabled) {
      await DesktopOverlay.closeApp();
    }
  }

  Future<void> setIdleAnimationsEnabled(bool enabled) async {
    _state = _state.copyWith(idleAnimationsEnabled: enabled);
    _idleController.setEnabled(enabled && _state.isEnabled);
    notifyListeners();
    await _storage.saveIdleAnimations(enabled);
  }

  Future<void> setStartWithSystem(bool enabled) async {
    _state = _state.copyWith(startWithSystem: enabled);
    notifyListeners();
    await _storage.saveStartWithSystem(enabled);
  }

  Future<void> setTransparency(double value) async {
    final clamped = value.clamp(0.2, 1.0);
    _state = _state.copyWith(transparency: clamped);
    notifyListeners();
    await _storage.saveTransparency(clamped);
  }

  void onTap() {
    if (!_state.isEnabled) return;
    if (_state.phase == InvestigationPhase.analyzing ||
        _state.phase == InvestigationPhase.completed) {
      return;
    }

    if (_state.missionComplete) {
      _showCasualDialogue();
      return;
    }

    _startInvestigation();
  }

  /// Called by the browser-extension bridge the instant the user presses
  /// play on a YouTube/TikTok video — runs the same investigate flow as a
  /// tap, but with the video's real URL already in hand instead of relying
  /// on the clipboard. Always runs the full animation (not the "already
  /// solved today" quick-reply) since a genuine video trigger deserves a
  /// real look; mission/case counting still only happens once per day.
  void investigateUrl(String url) {
    if (!_state.isEnabled) return;
    if (_state.phase == InvestigationPhase.analyzing) return;
    _startInvestigation(explicitUrl: url);
  }

  /// Today's mission is already solved — reply with a quick line instead of
  /// replaying the full investigate → Mission Completed cycle on every tap.
  void _showCasualDialogue() {
    _speechTimer?.cancel();
    _idleController.pause();

    final dialogue = AppConstants.tapDialogue[
        _random.nextInt(AppConstants.tapDialogue.length)];

    _state = _state.copyWith(isTapped: true, speechText: dialogue);
    notifyListeners();

    _speechTimer = Timer(AppConstants.speechDuration, () {
      _state = _state.copyWith(isTapped: false, clearSpeech: true);
      notifyListeners();
      if (_state.idleAnimationsEnabled && _state.isEnabled) {
        _idleController.resume();
      }
    });
  }

  void _startInvestigation({String? explicitUrl}) {
    _speechTimer?.cancel();
    _analyzeTimer?.cancel();
    _idleController.pause();

    final dialogue = explicitUrl != null
        ? AppConstants.welcomeSpeech
        : AppConstants.tapDialogue[
            _random.nextInt(AppConstants.tapDialogue.length)];

    _state = _state.copyWith(
      isTapped: true,
      speechText: dialogue,
      currentIdleAction: IdleAction.none,
      phase: InvestigationPhase.greeting,
      analyzeProgress: 0,
      clearVideo: true,
    );
    notifyListeners();

    // Kick off the oEmbed lookup in parallel with the greeting beat so real
    // video info is ready by the time analyzing starts. An explicit URL
    // (from the browser extension) skips the clipboard read entirely.
    final videoLookup = explicitUrl != null
        ? VideoLookupService.lookup(explicitUrl)
        : _lookupClipboardVideo();

    _speechTimer = Timer(const Duration(milliseconds: 900), () async {
      final video = await videoLookup;
      _state = _state.copyWith(
        phase: InvestigationPhase.analyzing,
        speechText: video != null
            ? AppConstants.analyzingSpeech
            : AppConstants.analyzingSpeechNoLink,
        isTapped: true,
        videoPlatform: video?.platform,
        videoTitle: video?.title,
        videoAuthor: video?.author,
        videoThumbnailUrl: video?.thumbnailUrl,
      );
      notifyListeners();
      _runAnalyzeProgress();
    });
  }

  /// Reads the clipboard for a TikTok/YouTube/Reels link and fetches its
  /// real title/thumbnail via the platform's public oEmbed endpoint.
  /// Returns null (silently) if there's no link or the lookup fails.
  Future<VideoInfo?> _lookupClipboardVideo() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text;
      if (text == null || text.isEmpty) return null;
      return await VideoLookupService.lookup(text);
    } catch (_) {
      return null;
    }
  }

  void _runAnalyzeProgress() {
    const tickMs = 50;
    final totalTicks = AppConstants.analyzeDuration.inMilliseconds ~/ tickMs;
    var tick = 0;

    _analyzeTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      tick++;
      final progress = (tick / totalTicks).clamp(0.0, 1.0);
      _state = _state.copyWith(analyzeProgress: progress);
      notifyListeners();

      if (tick >= totalTicks) {
        t.cancel();
        _completeMission();
      }
    });
  }

  /// Records a picture-judgment case as solved — same counters the video
  /// investigation flow feeds ("Today's Mission" / "Cases Solved"), but
  /// without touching phase/speech, since the case dialog has its own
  /// self-contained verdict/celebration screen.
  Future<void> recordCaseSolved() async {
    final alreadyDone = _state.missionComplete;
    final newProgress = alreadyDone
        ? _state.missionProgress
        : (_state.missionProgress + 1).clamp(0, _state.missionTarget);
    final newCases = _state.casesSolved + 1;

    _state = _state.copyWith(
      missionProgress: newProgress,
      casesSolved: newCases,
    );
    notifyListeners();

    await _storage.saveMissionProgress(newProgress);
    await _storage.saveCasesSolved(newCases);
  }

  Future<void> _completeMission() async {
    final alreadyDone = _state.missionComplete;
    final newProgress = alreadyDone
        ? _state.missionProgress
        : (_state.missionProgress + 1).clamp(0, _state.missionTarget);
    final newCases =
        alreadyDone ? _state.casesSolved : _state.casesSolved + 1;

    _state = _state.copyWith(
      phase: InvestigationPhase.completed,
      speechText: AppConstants.missionCompleteSpeech,
      isTapped: true,
      missionProgress: newProgress,
      casesSolved: newCases,
      analyzeProgress: 1,
      currentIdleAction: IdleAction.none,
    );
    notifyListeners();

    await _storage.saveMissionProgress(newProgress);
    await _storage.saveCasesSolved(newCases);

    _speechTimer?.cancel();
    _speechTimer = Timer(AppConstants.missionCompleteHold, () {
      _state = _state.copyWith(
        phase: InvestigationPhase.idle,
        clearSpeech: true,
        isTapped: false,
        analyzeProgress: 0,
      );
      notifyListeners();
      if (_state.idleAnimationsEnabled && _state.isEnabled) {
        _idleController.resume();
      }
    });
  }

  void _cancelInvestigation() {
    _speechTimer?.cancel();
    _analyzeTimer?.cancel();
  }

  /// Future hook: investigation modules call this, not the UI directly.
  void onInvestigationEvent(InvestigationEvent event) {
    if (!_state.isEnabled) return;

    _speechTimer?.cancel();
    _idleController.pause();
    _state = _state.copyWith(
      isTapped: true,
      speechText: event.prompt,
      currentIdleAction: IdleAction.none,
      phase: event.type == InvestigationEventType.missionCompleted
          ? InvestigationPhase.completed
          : InvestigationPhase.greeting,
    );
    notifyListeners();

    _speechTimer = Timer(AppConstants.speechDuration, () {
      _state = _state.copyWith(
        isTapped: false,
        clearSpeech: true,
        phase: InvestigationPhase.idle,
      );
      notifyListeners();
      if (_state.idleAnimationsEnabled) {
        _idleController.resume();
      }
    });
  }

  @override
  void dispose() {
    _cancelInvestigation();
    _idleController.dispose();
    super.dispose();
  }
}
