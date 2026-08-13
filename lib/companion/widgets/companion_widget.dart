import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../services/desktop_overlay.dart';
import '../../services/overlay_hit_region.dart';
import '../controllers/companion_controller.dart';
import '../models/companion_position.dart';
import 'detective_byte_character.dart';
import 'speech_bubble.dart';

/// Draggable floating companion — the core product experience.
class CompanionWidget extends StatefulWidget {
  const CompanionWidget({
    super.key,
    required this.controller,
    this.reportOverlayHits = false,
  });

  final CompanionController controller;
  final bool reportOverlayHits;

  @override
  State<CompanionWidget> createState() => _CompanionWidgetState();
}

class _CompanionWidgetState extends State<CompanionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapAnim;
  Offset? _dragOffset;

  @override
  void initState() {
    super.initState();
    _tapAnim = AnimationController(
      vsync: this,
      duration: AppConstants.tapScaleDuration,
    );
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (widget.controller.state.isTapped) {
      _tapAnim.forward();
    } else {
      _tapAnim.reverse();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _tapAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final screenSize = MediaQuery.sizeOf(context);
    final baseOffset = _dragOffset ?? state.position.toOffset(screenSize);

    if (!state.isEnabled) {
      return Positioned(
        left: baseOffset.dx,
        top: baseOffset.dy,
        child: _wrapHit(
          _HiddenSilhouette(
            onTap: () => widget.controller.setEnabled(true),
          ),
        ),
      );
    }

    final pose = BytePose.fromState(
      isTapped: state.isTapped,
      idleAction: state.currentIdleAction,
      idleProgress: state.idleProgress,
      blinkAmount: state.blinkAmount,
      phase: state.phase,
    );

    return Positioned(
      left: baseOffset.dx,
      top: baseOffset.dy,
      child: _wrapHit(
        Opacity(
          opacity: state.transparency,
          child: GestureDetector(
            onTap: widget.controller.onTap,
            // Byte floats alone (no chrome, no window controls) while
            // minimized to the overlay — double-tap is the way back to the
            // full app window.
            onDoubleTap: widget.reportOverlayHits
                ? DesktopOverlay.restoreNormalWindow
                : null,
            onPanUpdate: (details) {
              setState(() {
                final current = _dragOffset ?? baseOffset;
                _dragOffset = Offset(
                  (current.dx + details.delta.dx).clamp(
                    0.0,
                    screenSize.width - AppConstants.companionWidth,
                  ),
                  (current.dy + details.delta.dy).clamp(
                    0.0,
                    screenSize.height - AppConstants.companionHeight - 100,
                  ),
                );
              });
              if (widget.reportOverlayHits) {
                OverlayHitRegionHost.of(context)?.scheduleSync();
              }
            },
            onPanEnd: (_) {
              if (_dragOffset != null) {
                final position = CompanionPosition.fromOffset(
                  _dragOffset!,
                  screenSize,
                );
                widget.controller.updatePosition(position);
                setState(() => _dragOffset = null);
              }
            },
            child: AnimatedBuilder(
              animation: _tapAnim,
              builder: (context, child) {
                final tapPop = Curves.easeOutCubic.transform(_tapAnim.value);
                // Stack, not Column: the speech bubble used to sit above
                // Byte in a Column, so every time speechText toggled
                // empty/non-empty the bubble's height jumped from 0 to
                // ~70px and shoved Byte down/up with it — a real position
                // jump that read as "shaking" on every line of dialogue.
                // Anchoring Byte to the bottom and floating the bubble
                // above it (Positioned, not laid out in flow) keeps Byte's
                // position independent of whether a bubble is showing.
                return SizedBox(
                  width: AppConstants.companionWidth,
                  height: AppConstants.companionHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: AppConstants.companionHeight + 4,
                        child: Center(
                          child: SpeechBubble(text: state.speechText ?? ''),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Transform.scale(
                          scale: 1.0 + tapPop * 0.06,
                          child: DetectiveByteCharacter(pose: pose),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrapHit(Widget child) {
    if (!widget.reportOverlayHits) return child;
    return OverlayHitTarget(id: 'companion', child: child);
  }
}

/// Dashed silhouette when Byte is OFF — matches "You're in control" mockup.
class _HiddenSilhouette extends StatelessWidget {
  const _HiddenSilhouette({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        size: const Size(
          AppConstants.companionWidth,
          AppConstants.companionHeight,
        ),
        painter: _SilhouettePainter(),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8A8A8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height * 0.55);
    _dashCircle(canvas, center.translate(0, -22), 28, paint);
    _dashRRect(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 22), width: 52, height: 48),
        const Radius.circular(18),
      ),
      paint,
    );
  }

  void _dashCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    final circumference = 2 * math.pi * r;
    final count = (circumference / (dash + gap)).floor();
    for (var i = 0; i < count; i++) {
      final start = i * (dash + gap) / r;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        dash / r,
        false,
        paint,
      );
    }
  }

  void _dashRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
