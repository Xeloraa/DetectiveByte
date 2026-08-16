import 'package:flutter/foundation.dart';

import '../models/picture_case.dart';

enum CaseStage {
  /// Byte shows the photo + caption.
  briefing,

  /// "Look closer" reveal right after the briefing.
  zoomedOut,

  /// Certainty dial: "how sure are you this is true?"
  certainty,

  /// A single question + its reveal.
  clue,

  /// Child gives their final Real / Fake call.
  verdict,

  /// Byte shows the answer, the confidence line, and the lesson.
  closed,
}

/// Drives one [PictureCase] through the guided investigate → certainty →
/// clue → verdict flow. A fresh controller is created per case.
class PictureCaseController extends ChangeNotifier {
  PictureCaseController(this.pictureCase);

  final PictureCase pictureCase;

  CaseStage _stage = CaseStage.briefing;
  CaseStage get stage => _stage;

  /// -1 before the first clue is revealed; index into [PictureCase.clues]
  /// of the most recently revealed clue otherwise.
  int _clueIndex = -1;
  int get clueIndex => _clueIndex;
  CaseClue? get currentClue =>
      _clueIndex >= 0 ? pictureCase.clues[_clueIndex] : null;

  /// Certainty values (0-100) the child has locked in, in order: one
  /// "first read" before any clue, then one after each clue.
  final List<double> certaintyHistory = [];

  /// Seed value for the next certainty read (50 for a first read, or the
  /// last locked-in value for a re-read) — read once when [_CertaintyDial]
  /// mounts. The live drag value while the slider is moving lives entirely
  /// in that widget's own local state, not here: routing every drag pixel
  /// through this controller's notifyListeners() used to force a rebuild
  /// of the *whole* dialog — including Byte's mini portrait and its own
  /// perpetual breathing animation — on every single frame of the drag,
  /// which is exactly the kind of avoidable per-frame churn that showed up
  /// as visible lag when screen-recording this stage.
  double _pendingCertainty = 50;
  double get pendingCertainty => _pendingCertainty;

  CaseVerdict? verdict;

  bool get isLastClue => _clueIndex >= pictureCase.clues.length - 1;

  void beginInvestigating() {
    _stage = CaseStage.zoomedOut;
    notifyListeners();
  }

  void continueFromZoomOut() {
    _stage = CaseStage.certainty;
    _pendingCertainty = 50;
    notifyListeners();
  }

  /// [value] is the slider's final position when "Lock it in" was pressed,
  /// reported directly by the widget rather than read back from this
  /// controller (see [_pendingCertainty]'s doc comment).
  void lockInCertainty(double value) {
    _pendingCertainty = value;
    certaintyHistory.add(value);
    if (_clueIndex + 1 < pictureCase.clues.length) {
      _clueIndex++;
      _stage = CaseStage.clue;
    } else {
      _stage = CaseStage.verdict;
    }
    notifyListeners();
  }

  void continueFromClue() {
    _stage = CaseStage.certainty;
    _pendingCertainty = certaintyHistory.last;
    notifyListeners();
  }

  void submitVerdict(CaseVerdict guess) {
    verdict = guess;
    _stage = CaseStage.closed;
    notifyListeners();
  }

  bool get verdictWasCorrect => verdict == pictureCase.truth;
}
