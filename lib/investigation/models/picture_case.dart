import 'package:flutter/material.dart';

/// The three honest answers to "is this post telling the truth?".
///
/// [inconclusive] is a first-class answer on purpose — teaching kids that
/// "I don't have enough to say yet" is a legitimate verdict (often the
/// *right* one) is half the media-literacy point of the app.
enum CaseVerdict {
  real,
  fake,
  inconclusive;

  String get label => switch (this) {
        CaseVerdict.real => 'Real',
        CaseVerdict.fake => 'Fake / Misleading',
        CaseVerdict.inconclusive => 'Not sure yet',
      };
}

/// One "is this real?" picture-judgment case: a viral-style photo + caption,
/// a couple of clues that surface as the child investigates, and the ground
/// truth revealed at the end.
///
/// The "photo" is a styled placeholder (emoji + color), not a real bundled
/// image — swap [placeholderEmoji]/[placeholderColor] for a real asset path
/// once a curated image set exists; the investigation mechanic underneath
/// doesn't change.
class PictureCase {
  const PictureCase({
    required this.id,
    required this.caption,
    required this.placeholderEmoji,
    required this.placeholderColor,
    required this.zoomOutReveal,
    required this.truth,
    required this.clues,
    required this.verdictExplanation,
    required this.lessonLine,
  });

  final String id;

  /// The viral-style claim shown with the photo, e.g. "MASSIVE protest
  /// happening downtown right now!"
  final String caption;

  final String placeholderEmoji;
  final Color placeholderColor;

  /// What "look closer" reveals right after the briefing — the first
  /// "wait, WHAT" moment (e.g. the photo is actually cropped tighter than
  /// it first appeared).
  final String zoomOutReveal;

  /// Ground truth: does the caption's claim hold up, or is there not
  /// enough evidence either way?
  final CaseVerdict truth;

  /// Question + reveal pairs the child steps through, each followed by a
  /// re-read of the certainty dial.
  final List<CaseClue> clues;

  /// Shown at case-closed, alongside the real/fake verdict.
  final String verdictExplanation;

  /// One-line takeaway saved to the journal.
  final String lessonLine;
}

/// A single investigative question and what asking it reveals.
class CaseClue {
  const CaseClue({
    required this.question,
    required this.reveal,
    required this.isStrongSignal,
  });

  /// e.g. "Who posted this?"
  final String question;

  /// e.g. "An account with no history, created this week."
  final String reveal;

  /// Whether this particular signal is actually a reliable one to lean on —
  /// used for the "here's what that tells us" explanation, never framed as
  /// the child having gotten the question itself "wrong."
  final bool isStrongSignal;
}
