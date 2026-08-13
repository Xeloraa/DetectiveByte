import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../models/idle_action.dart';
import '../models/investigation_phase.dart';

/// Visual pose parameters derived from companion state.
class BytePose {
  const BytePose({
    this.scale = 1.0,
    this.leanForward = 0.0,
    this.headTilt = 0.0,
    this.magnifierRaise = 0.0,
    this.armAngle = 0.0,
    this.notebookOpen = 0.0,
    this.hatAdjust = 0.0,
    this.stretchAmount = 0.0,
    this.lookDirection = 0.0,
    this.blinkAmount = 0.0,
    this.handToBrow = 0.0,
    this.thinking = 0.0,
    this.thumbsUp = 0.0,
    this.wink = 0.0,
    this.showQuestion = false,
    this.showLightbulb = false,
    this.idleActionKind,
  });

  final double scale;
  final double leanForward;
  final double headTilt;
  final double magnifierRaise;
  final double armAngle;
  final double notebookOpen;
  final double hatAdjust;
  final double stretchAmount;
  final double lookDirection;
  final double blinkAmount;
  final double handToBrow;
  final double thinking;
  final double thumbsUp;
  final double wink;
  final bool showQuestion;
  final bool showLightbulb;

  /// Which idle action is driving this pose, if any. _poseToAsset() keys
  /// off this directly rather than inferring the pose from continuous
  /// fields like [hatAdjust] or [stretchAmount] — those oscillate through
  /// zero mid-animation (sine-driven sway), and picking an asset from
  /// "is this value near zero" caused the picked image to flicker between
  /// the idle pose and the action pose every time the wave crossed zero.
  final IdleAction? idleActionKind;

  factory BytePose.fromState({
    required bool isTapped,
    required IdleAction idleAction,
    required double idleProgress,
    required double blinkAmount,
    required InvestigationPhase phase,
  }) {
    if (phase == InvestigationPhase.completed) {
      return BytePose(
        scale: 1.05,
        thumbsUp: 1,
        wink: 1,
        blinkAmount: blinkAmount,
      );
    }

    if (phase == InvestigationPhase.analyzing || isTapped) {
      return BytePose(
        scale: AppConstants.tapScale,
        leanForward: 0.12,
        magnifierRaise: 1.0,
        headTilt: -0.05,
        blinkAmount: blinkAmount,
      );
    }

    final t = _ease(idleProgress);

    return switch (idleAction) {
      IdleAction.lookAround => BytePose(
          lookDirection: math.sin(t * math.pi * 2) * 0.28,
          headTilt: math.sin(t * math.pi * 2) * 0.1,
          handToBrow: 0.85,
          showQuestion: true,
          blinkAmount: blinkAmount,
          idleActionKind: idleAction,
        ),
      IdleAction.readNotebook => BytePose(
          notebookOpen: math.max(0.55, t),
          armAngle: -0.25,
          headTilt: 0.14,
          leanForward: 0.08,
          blinkAmount: blinkAmount,
          idleActionKind: idleAction,
        ),
      IdleAction.thinking => BytePose(
          thinking: 1,
          headTilt: -0.06 + math.sin(t * math.pi * 2) * 0.04,
          showLightbulb: t > 0.2,
          blinkAmount: blinkAmount,
          idleActionKind: idleAction,
        ),
      IdleAction.polishMagnifyingGlass => BytePose(
          magnifierRaise: 0.6,
          armAngle: math.sin(t * math.pi * 4) * 0.3,
          blinkAmount: blinkAmount,
          idleActionKind: idleAction,
        ),
      IdleAction.adjustHat => BytePose(
          hatAdjust: math.sin(t * math.pi * 2) * 0.15,
          headTilt: math.sin(t * math.pi) * 0.08,
          blinkAmount: blinkAmount,
          idleActionKind: idleAction,
        ),
      IdleAction.stretch => BytePose(
          stretchAmount: math.sin(t * math.pi) * 0.15,
          armAngle: math.sin(t * math.pi) * 0.4,
          blinkAmount: blinkAmount,
          idleActionKind: idleAction,
        ),
      IdleAction.blink => BytePose(blinkAmount: 1.0),
      IdleAction.none => BytePose(blinkAmount: blinkAmount),
    };
  }

  static double _ease(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t * t * (3 - 2 * t);
  }
}

/// Asset filenames under `assets/byte/` (transparent PNGs).
abstract final class ByteAssets {
  static const String idle = 'idle.png';
  static const String investigating = 'investigating.png';
  static const String lookAround = 'look_around.png';
  static const String readNotebook = 'read_notebook.png';
  static const String thinking = 'thinking.png';
  static const String polishGlass = 'polish_glass.png';
  static const String adjustHat = 'adjust_hat.png';
  static const String stretch = 'stretch.png';
  static const String blink = 'blink.png';
  static const String celebrate = 'celebrate.png';

  static String pathFor(String fileName) => 'assets/byte/$fileName';
}

/// Flip to `false` once real PNGs are dropped into `assets/byte/`.
const bool kUseBytePosePlaceholders = false;

/// Maps [BytePose] fields to an asset name — mirrors [BytePose.fromState] priority.
String _poseToAsset(BytePose pose) {
  // InvestigationPhase.completed
  if (pose.thumbsUp > 0.5 || pose.wink > 0.5) {
    return ByteAssets.celebrate;
  }

  // Analyzing / tapped — full magnifier raise
  if (pose.magnifierRaise >= 0.95) {
    return ByteAssets.investigating;
  }

  // Idle actions — keyed off the stable action identity, not continuous
  // pose parameters. Those oscillate (sine-driven sway) and cross zero
  // mid-animation, so picking an asset from "is this value non-zero" made
  // the picked image flicker between poses every time the wave crossed 0.
  //
  // Deliberately excludes blink here — blink is applied separately in
  // _DetectiveByteCharacterState as an un-animated overlay swap, not a
  // pose change. Blinks last 120ms, far shorter than AnimatedSwitcher's
  // 320ms crossfade, so routing blink through this function (and the
  // switcher) reversed an in-flight scale/fade transition on every single
  // blink — a visible jolt every 2.5-7.5s that read as Byte "shaking".
  switch (pose.idleActionKind) {
    case IdleAction.lookAround:
      return ByteAssets.lookAround;
    case IdleAction.readNotebook:
      return ByteAssets.readNotebook;
    case IdleAction.thinking:
      return ByteAssets.thinking;
    case IdleAction.adjustHat:
      return ByteAssets.adjustHat;
    case IdleAction.stretch:
      return ByteAssets.stretch;
    case IdleAction.polishMagnifyingGlass:
      return ByteAssets.polishGlass;
    case IdleAction.blink:
    case IdleAction.none:
    case null:
      return ByteAssets.idle;
  }
}

/// Image-asset Detective Byte — pose-driven sprites with crossfade.
///
/// Poses are static PNGs, so without help they'd sit frozen for the full
/// 2.4s of each idle action. A continuous "breathing" bob/scale runs
/// underneath every pose so Byte never looks like a paused video.
class DetectiveByteCharacter extends StatefulWidget {
  const DetectiveByteCharacter({
    super.key,
    required this.pose,
  });

  final BytePose pose;

  @override
  State<DetectiveByteCharacter> createState() =>
      _DetectiveByteCharacterState();
}

class _DetectiveByteCharacterState extends State<DetectiveByteCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseAsset = _poseToAsset(widget.pose);
    // Blink is a same-key, un-animated swap (see _poseToAsset) so it never
    // fights the pose-change crossfade below.
    final isBlinking =
        widget.pose.idleActionKind == null && widget.pose.blinkAmount >= 0.85;
    final displayAsset = isBlinking ? ByteAssets.blink : baseAsset;

    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, child) {
        final wave = Curves.easeInOut.transform(_breathe.value);
        final bobY = -wave * 3.0;
        final breatheScale = 1.0 + wave * 0.012;

        return Transform.translate(
          offset: Offset(0, bobY),
          child: Transform.scale(
            scale: widget.pose.scale * breatheScale,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: AppConstants.companionWidth,
        height: AppConstants.companionHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
          child: _BytePoseImage(
            key: ValueKey<String>(baseAsset),
            assetFileName: displayAsset,
          ),
        ),
      ),
    );
  }
}

class _BytePoseImage extends StatelessWidget {
  const _BytePoseImage({
    super.key,
    required this.assetFileName,
  });

  final String assetFileName;

  @override
  Widget build(BuildContext context) {
    if (kUseBytePosePlaceholders) {
      return _PosePlaceholder(label: assetFileName);
    }

    return Image.asset(
      ByteAssets.pathFor(assetFileName),
      width: AppConstants.companionWidth,
      height: AppConstants.companionHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          _PosePlaceholder(label: assetFileName),
    );
  }
}

/// Colored stand-in until transparent PNGs are added to `assets/byte/`.
class _PosePlaceholder extends StatelessWidget {
  const _PosePlaceholder({required this.label});

  final String label;

  static const Map<String, Color> _colors = {
    ByteAssets.idle: Color(0xFFF08A3C),
    ByteAssets.investigating: Color(0xFFE8A85C),
    ByteAssets.lookAround: Color(0xFF5B8DEF),
    ByteAssets.readNotebook: Color(0xFF4CAF6A),
    ByteAssets.thinking: Color(0xFFFFD54F),
    ByteAssets.polishGlass: Color(0xFF9C6ADE),
    ByteAssets.adjustHat: Color(0xFF6B4A32),
    ByteAssets.stretch: Color(0xFF3DDC84),
    ByteAssets.blink: Color(0xFF90A4AE),
    ByteAssets.celebrate: Color(0xFFE85D75),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[label] ?? AppTheme.foxOrange;
    final short = label.replaceAll('.png', '');

    return Container(
      width: AppConstants.companionWidth,
      height: AppConstants.companionHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white70, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets_rounded,
              color: Colors.white.withValues(alpha: 0.95),
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              short,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
