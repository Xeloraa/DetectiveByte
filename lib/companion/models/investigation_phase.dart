/// Visual / flow phases for a tap-to-investigate session.
enum InvestigationPhase {
  idle,
  greeting,
  analyzing,
  completed,

  /// Short celebrate beat after closing a picture case — same pose as
  /// [completed] but deliberately distinct so the investigation overlay
  /// (which only renders for analyzing/completed) stays hidden.
  celebrating,
}
