/// Quiet detective actions Byte performs while idle.
enum IdleAction {
  none,
  lookAround,
  readNotebook,
  thinking,
  polishMagnifyingGlass,
  adjustHat,
  stretch,
  blink,

  /// Byte picks a spot on screen and trots over to it. Position is
  /// interpolated by the companion controller while the idle scheduler
  /// drives progress — see CompanionController._onWanderTick.
  wander,
}

extension IdleActionX on IdleAction {
  bool get isActive => this != IdleAction.none;

  static IdleAction randomShowcase() {
    const showcase = [
      IdleAction.lookAround,
      IdleAction.readNotebook,
      IdleAction.thinking,
    ];
    return showcase[DateTime.now().microsecond % showcase.length];
  }
}
