import 'dart:async';
import 'dart:math';
import 'dart:ui' show Offset, Rect, Size;

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
  CompanionController({
    required this._storage,
    List<IdleAction>? idleActionPool,
  }) {
    _idleActionPool = idleActionPool;
    _bootstrap();
  }

  final LocalStorageService _storage;

  /// Test seam: forces the idle scheduler to draw from a specific action
  /// pool (e.g. wander-only) instead of the weighted production mix.
  List<IdleAction>? _idleActionPool;

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

    _idleController = IdleAnimationController(
      onTick: _onIdleTick,
      actionPool: _idleActionPool,
    );
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

  // -- Wander bookkeeping ---------------------------------------------------
  // Byte's walk is driven by the idle scheduler (which advances progress
  // 0..1 at ~60fps during IdleAction.wander); this controller maps that
  // progress onto a position path. All in normalized CompanionPosition
  // space so window resizes mid-walk stay sane.

  /// Window size reported by CompanionWidget — needed to pick walk targets
  /// in pixel space (panel exclusion zone, margins) before normalizing.
  Size? _viewportSize;

  CompanionPosition? _wanderStart;
  CompanionPosition? _wanderTarget;
  double _walkPhase = 0;

  void updateViewportSize(Size size) {
    if (_viewportSize == size) return;
    _viewportSize = size;
  }

  void _onIdleTick() {
    final action = _idleController.currentAction;

    if (action == IdleAction.wander) {
      if (_state.phase == InvestigationPhase.idle) _onWanderTick();
      return;
    }

    // The walk ended (finished, paused, or cancelled by a tap/drag) —
    // commit wherever Byte got to before anything else touches state.
    if (_wanderTarget != null) _endWander();

    if (_state.phase != InvestigationPhase.idle) return;
    _state = _state.copyWith(
      currentIdleAction: _idleController.currentAction,
      idleProgress: _idleController.progress,
      blinkAmount: _idleController.blinkAmount,
    );
    notifyListeners();
  }

  void _onWanderTick() {
    final progress = _idleController.progress;
    if (_wanderTarget == null) {
      _beginWander();
    }
    final start = _wanderStart;
    final target = _wanderTarget;
    if (start == null || target == null) return;

    final t = _easeInOut(progress);
    final moving = (target.x - start.x).abs() > 0.0001 ||
        (target.y - start.y).abs() > 0.0001;
    // Only run the hop cycle when Byte is actually going somewhere — a
    // stationary "decided to stay put" wander must not bounce in place.
    if (moving) _walkPhase += 0.34; // ~3.3 hops/sec at the 16ms tick rate
    _state = _state.copyWith(
      position: CompanionPosition(
        x: start.x + (target.x - start.x) * t,
        y: start.y + (target.y - start.y) * t,
      ),
      currentIdleAction: IdleAction.wander,
      idleProgress: progress,
      blinkAmount: _idleController.blinkAmount,
      walkPhase: _walkPhase,
    );
    notifyListeners();

    if (progress >= 1) _endWander();
  }

  void _beginWander() {
    _wanderStart = _state.position;
    _walkPhase = 0;

    final viewport = _viewportSize;
    if (viewport == null) {
      // No viewport reported yet — stand still and "decide" instead.
      _wanderTarget = _state.position;
      return;
    }

    final here = _state.position.toOffset(viewport);
    final targetPx = _pickWanderTarget(viewport, here);
    _wanderTarget = targetPx == null
        ? _state.position // Nowhere good to go — pause in place.
        : CompanionPosition.fromOffset(targetPx, viewport);
  }

  /// Random destination that keeps Byte fully on-screen, out from under
  /// the top-right Status/Mission/Journal stack, and low enough that a
  /// speech bubble above his head still fits in the window. Returns null
  /// if no suitable spot turned up after a few tries.
  Offset? _pickWanderTarget(Size viewport, Offset here) {
    const margin = 8.0;
    final minX = margin;
    final maxX = viewport.width - AppConstants.companionWidth - margin;
    final minY = AppConstants.companionHeight * 0.45; // bubble headroom
    final maxY = viewport.height - AppConstants.companionHeight - margin;
    if (maxX <= minX || maxY <= minY) return null;

    final panelZone = Rect.fromLTWH(viewport.width - 300, 0, 300, 400);

    for (var attempt = 0; attempt < 16; attempt++) {
      final candidate = Offset(
        minX + _random.nextDouble() * (maxX - minX),
        minY + _random.nextDouble() * (maxY - minY),
      );
      final byteRect = Rect.fromLTWH(
        candidate.dx,
        candidate.dy,
        AppConstants.companionWidth,
        AppConstants.companionHeight,
      );
      if (panelZone.overlaps(byteRect)) continue;
      // Short shuffles read as jitter — only walk if it's worth it.
      if ((candidate - here).distance < 140) continue;
      return candidate;
    }
    return null;
  }

  /// Idempotent — the scheduler's completion tick and an explicit cancel
  /// (tap, drag, disable) can both arrive for the same walk.
  void _endWander() {
    if (_wanderTarget == null) return;
    final where = _state.position;
    _wanderStart = null;
    _wanderTarget = null;
    if (_state.walkPhase != 0) {
      _state = _state.copyWith(walkPhase: 0);
      notifyListeners();
    }
    // Byte remembers where he stopped, even mid-walk interruptions.
    unawaited(_storage.savePosition(where));
  }

  static double _easeInOut(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t * t * (3 - 2 * t);
  }

  // -- Drag coordination ----------------------------------------------------

  /// The user grabbed Byte — freeze autonomous movement so he doesn't
  /// wander out from under the pointer mid-drag.
  void onDragStart() {
    if (!_state.isEnabled) return;
    _idleController.pause();
  }

  void onDragEnd() {
    if (_state.isEnabled &&
        _state.idleAnimationsEnabled &&
        _state.phase == InvestigationPhase.idle) {
      _idleController.resume();
    }
  }

  Future<void> updatePosition(CompanionPosition position) async {
    _state = _state.copyWith(position: position);
    notifyListeners();
    await _storage.savePosition(position);
  }

  Future<void> resetPosition() async {
    // Freeze any walk in flight so it can't tug Byte away from the reset
    // spot the moment he's placed there (same coordination as a drag).
    onDragStart();
    final defaultPos = CompanionPosition.defaultPosition();
    await updatePosition(defaultPos);
    onDragEnd();
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
  /// investigation flow feeds ("Today's Mission" / "Cases Solved") — and
  /// gives Byte a short celebrate beat so he's visibly part of the win,
  /// not just a counter update happening off-screen.
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

    // Only celebrate when nothing else owns the stage — stomping an
    // in-flight video analysis would swap its phase out from under it.
    if (_state.phase == InvestigationPhase.idle) {
      _celebrateCaseSolved();
    }
  }

  void _celebrateCaseSolved() {
    _speechTimer?.cancel();
    _idleController.pause();

    _state = _state.copyWith(
      phase: InvestigationPhase.celebrating,
      speechText: AppConstants.caseSolvedSpeech,
      isTapped: true,
      currentIdleAction: IdleAction.none,
    );
    notifyListeners();

    _speechTimer = Timer(AppConstants.speechDuration, () {
      _state = _state.copyWith(
        phase: InvestigationPhase.idle,
        clearSpeech: true,
        isTapped: false,
      );
      notifyListeners();
      if (_state.idleAnimationsEnabled && _state.isEnabled) {
        _idleController.resume();
      }
    });
  }

  /// The case dialog is modal and covers the stage — freeze wandering so
  /// Byte doesn't stroll around behind it (and so his hit region doesn't
  /// drift while the child is clicking through clues).
  void onCaseFlowOpened() {
    if (!_state.isEnabled) return;
    _idleController.pause();
  }

  void onCaseFlowClosed() {
    if (!_state.isEnabled) return;
    if (_state.idleAnimationsEnabled &&
        _state.phase == InvestigationPhase.idle) {
      _idleController.resume();
    }
  }

  Future<void> _completeMission() async {
    final alreadyDone = _state.missionComplete;
    final newProgress = alreadyDone
        ? _state.missionProgress
        : (_state.missionProgress + 1).clamp(0, _state.missionTarget);
    final newCases =
        alreadyDone ? _state.casesSolved : _state.casesSolved + 1;

    // The closing line matches the case report: "found it" when a real
    // link was checked, "nothing to check" when no link turned up.
    final foundVideo = _state.videoPlatform != null;

    _state = _state.copyWith(
      phase: InvestigationPhase.completed,
      speechText: foundVideo
          ? AppConstants.verdictFoundSpeech
          : AppConstants.verdictNoLinkSpeech,
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
