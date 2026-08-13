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
