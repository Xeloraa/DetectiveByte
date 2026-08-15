import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../models/idle_action.dart';

/// Schedules quiet, non-attention-seeking idle detective animations.
class IdleAnimationController {
  IdleAnimationController({
    required this.onTick,
    List<IdleAction>? actionPool,
  }) : _actionPool = actionPool ?? _defaultPool;

  /// Actions the scheduler draws from (weighted — wander appears twice so
  /// moving around, the strongest "living pet" signal, comes up often).
  /// Injectable so tests can force a specific action.
  static const List<IdleAction> _defaultPool = [
    IdleAction.lookAround,
    IdleAction.readNotebook,
    IdleAction.thinking,
    IdleAction.polishMagnifyingGlass,
    IdleAction.adjustHat,
    IdleAction.wander,
    IdleAction.wander,
  ];

  final List<IdleAction> _actionPool;

  final VoidCallback onTick;
  final Random _random = Random();

  IdleAction _currentAction = IdleAction.none;
  double _progress = 0;
  double _blinkAmount = 0;
  Timer? _scheduleTimer;
  Timer? _actionTimer;
  Timer? _blinkTimer;
  bool _enabled = true;
  bool _disposed = false;
  bool _paused = false;

  IdleAction get currentAction => _currentAction;
  double get progress => _progress;
  double get blinkAmount => _blinkAmount;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _stopAll();
      _currentAction = IdleAction.none;
      _progress = 0;
      onTick();
    } else if (!_paused) {
      _scheduleNext();
      _startBlinkLoop();
    }
  }

  void pause() {
    _paused = true;
    _scheduleTimer?.cancel();
    _actionTimer?.cancel();
    _currentAction = IdleAction.none;
    _progress = 0;
    onTick();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    if (_enabled && !_disposed) {
      _scheduleNext();
    }
  }

  void start() {
    _scheduleNext();
    _startBlinkLoop();
  }

  void dispose() {
    _disposed = true;
    _stopAll();
  }

  void _stopAll() {
    _scheduleTimer?.cancel();
    _actionTimer?.cancel();
    _blinkTimer?.cancel();
  }

  void _startBlinkLoop() {
    _blinkTimer?.cancel();
    if (!_enabled || _disposed) return;

    final delay = Duration(
      milliseconds: 2500 + _random.nextInt(5000),
    );
    _blinkTimer = Timer(delay, _performBlink);
  }

  void _performBlink() {
    if (_disposed || !_enabled) return;

    _blinkAmount = 1;
    onTick();

    Timer(const Duration(milliseconds: 120), () {
      if (_disposed) return;
      _blinkAmount = 0;
      onTick();
      _startBlinkLoop();
    });
  }

  void _scheduleNext() {
    _scheduleTimer?.cancel();
    if (!_enabled || _disposed || _paused) return;

    final delayMs = AppConstants.idleMinDelay.inMilliseconds +
        _random.nextInt(
          AppConstants.idleMaxDelay.inMilliseconds -
              AppConstants.idleMinDelay.inMilliseconds,
        );

    _scheduleTimer = Timer(Duration(milliseconds: delayMs), _startAction);
  }

  void _startAction() {
    if (_disposed || !_enabled || _paused) return;

    _currentAction = _actionPool[_random.nextInt(_actionPool.length)];
    _progress = 0;
    onTick();

    // Wander ticks at ~60fps because the companion controller maps each
    // progress tick straight to Byte's on-screen position — 50ms ticks
    // (20fps) made the walk visibly stutter. Poses stay at 50ms.
    final tickMs = _currentAction == IdleAction.wander ? 16 : 50;
    final totalTicks =
        _durationFor(_currentAction).inMilliseconds ~/ tickMs;
    var tick = 0;

    _actionTimer?.cancel();
    _actionTimer = Timer.periodic(Duration(milliseconds: tickMs), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      tick++;
      _progress = (tick / totalTicks).clamp(0.0, 1.0);
      onTick();

      if (tick >= totalTicks) {
        t.cancel();
        _currentAction = IdleAction.none;
        _progress = 0;
        onTick();
        _scheduleNext();
      }
    });
  }

  /// How long one run of [action] lasts. Wanders vary so Byte doesn't
  /// march at a fixed cadence.
  Duration _durationFor(IdleAction action) {
    if (action == IdleAction.wander) {
      return Duration(milliseconds: 2800 + _random.nextInt(1800));
    }
    return AppConstants.idleActionDuration;
  }
}
