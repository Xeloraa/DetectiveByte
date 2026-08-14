import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/desktop_overlay.dart';
import '../../services/overlay_hit_region.dart';
import '../controllers/picture_case_controller.dart';
import '../models/picture_case.dart';

/// Full-screen-ish modal walking a child through one [PictureCase]:
/// briefing → look closer → certainty dial → clue → (repeat) → verdict →
/// case closed with the confidence line and lesson.
class PictureCaseDialog extends StatefulWidget {
  const PictureCaseDialog({
    super.key,
    required this.pictureCase,
    required this.onSolved,
  });

  final PictureCase pictureCase;

  /// Called once, right before the dialog closes, if the child reached the
  /// case-closed screen (not if they dismiss early).
  final VoidCallback onSolved;

  /// Opens the case flow. Handles overlay-mode hit-region widening the same
  /// way [SettingsSheet.show] does, so the modal stays interactive when
  /// Byte is floating in click-through mode.
  static Future<void> show(
    BuildContext context, {
    required PictureCase pictureCase,
    required VoidCallback onSolved,
  }) async {
    if (DesktopOverlay.isOverlayMode) {
      final size = MediaQuery.sizeOf(context);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      await DesktopOverlay.updateHitRegions([
        Rect.fromLTWH(0, 0, size.width * dpr, size.height * dpr),
      ]);
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: DesktopOverlay.isOverlayMode
          ? Colors.black45
          : Colors.black54,
      builder: (_) =>
          PictureCaseDialog(pictureCase: pictureCase, onSolved: onSolved),
    );

    if (context.mounted) {
      OverlayHitRegionHost.of(context)?.scheduleSync();
    }
  }

  @override
  State<PictureCaseDialog> createState() => _PictureCaseDialogState();
}

class _PictureCaseDialogState extends State<PictureCaseDialog> {
  late final PictureCaseController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PictureCaseController(widget.pictureCase);
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.darkPanel.copyWith(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildStage(context),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    switch (_controller.stage) {
      case CaseStage.briefing:
        return _Briefing(
          key: const ValueKey('briefing'),
          pictureCase: widget.pictureCase,
          onInvestigate: _controller.beginInvestigating,
        );
      case CaseStage.zoomedOut:
        return _ZoomedOut(
          key: const ValueKey('zoomedOut'),
          pictureCase: widget.pictureCase,
          onContinue: _controller.continueFromZoomOut,
        );
      case CaseStage.certainty:
        return _CertaintyDial(
          key: ValueKey('certainty-${_controller.clueIndex}'),
          isFirstRead: _controller.clueIndex == -1,
          value: _controller.pendingCertainty,
          onChanged: (v) => _controller.pendingCertainty = v,
          onLockIn: _controller.lockInCertainty,
        );
      case CaseStage.clue:
        return _ClueReveal(
          key: ValueKey('clue-${_controller.clueIndex}'),
          clue: _controller.currentClue!,
          isLastClue: _controller.isLastClue,
          onContinue: _controller.continueFromClue,
        );
      case CaseStage.verdict:
        return _Verdict(
          key: const ValueKey('verdict'),
          onSubmit: _controller.submitVerdict,
        );
      case CaseStage.closed:
        return _CaseClosed(
          key: const ValueKey('closed'),
          pictureCase: widget.pictureCase,
          controller: _controller,
          onDone: () {
            widget.onSolved();
            Navigator.of(context).pop();
          },
        );
    }
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.pictureCase});

  final PictureCase pictureCase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pictureCase.placeholderColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        pictureCase.placeholderEmoji,
        style: const TextStyle(fontSize: 56),
      ),
    );
  }
}

class _StageHeading extends StatelessWidget {
  const _StageHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.panelText,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accentGreen,
          foregroundColor: AppTheme.ink,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}

class _Briefing extends StatelessWidget {
  const _Briefing({
    super.key,
    required this.pictureCase,
    required this.onInvestigate,
  });

  final PictureCase pictureCase;
  final VoidCallback onInvestigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageHeading("Today's Case"),
        const SizedBox(height: 12),
        _PhotoPlaceholder(pictureCase: pictureCase),
        const SizedBox(height: 12),
        Text(
          pictureCase.caption,
          style: const TextStyle(
            color: AppTheme.panelText,
            fontSize: 15,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryButton(label: 'Investigate', onPressed: onInvestigate),
      ],
    );
  }
}

class _ZoomedOut extends StatelessWidget {
  const _ZoomedOut({
    super.key,
    required this.pictureCase,
    required this.onContinue,
  });

  final PictureCase pictureCase;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageHeading('Look Closer'),
        const SizedBox(height: 12),
        _PhotoPlaceholder(pictureCase: pictureCase),
        const SizedBox(height: 12),
        Text(
          pictureCase.zoomOutReveal,
          style: const TextStyle(
            color: AppTheme.panelMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryButton(label: 'Continue', onPressed: onContinue),
      ],
    );
  }
}

class _CertaintyDial extends StatelessWidget {
  const _CertaintyDial({
    super.key,
    required this.isFirstRead,
    required this.value,
    required this.onChanged,
    required this.onLockIn,
  });

  final bool isFirstRead;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onLockIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageHeading(
          isFirstRead ? 'How sure are you?' : 'Now how sure are you?',
        ),
        const SizedBox(height: 8),
        const Text(
          'How sure are you this post is telling the truth?',
          style: TextStyle(
            color: AppTheme.panelMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${value.round()}% sure',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.accentGreen,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
        _PrimaryButton(label: 'Lock it in', onPressed: onLockIn),
      ],
    );
  }
}

class _ClueReveal extends StatelessWidget {
  const _ClueReveal({
    super.key,
    required this.clue,
    required this.isLastClue,
    required this.onContinue,
  });

  final CaseClue clue;
  final bool isLastClue;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageHeading('New Clue'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.panelElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clue.question,
                style: const TextStyle(
                  color: AppTheme.panelText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                clue.reveal,
                style: const TextStyle(
                  color: AppTheme.panelMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Here's what that tells us — worth weighing in, not a final "
          'answer on its own.',
          style: TextStyle(
            color: AppTheme.panelMuted.withValues(alpha: 0.8),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryButton(
          label: isLastClue ? "What's your call?" : 'Keep investigating',
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({super.key, required this.onSubmit});

  final ValueChanged<bool> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageHeading('Your Verdict'),
        const SizedBox(height: 8),
        const Text(
          "You've seen the clues. What's the call?",
          style: TextStyle(
            color: AppTheme.panelMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onSubmit(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentGreen,
                  side: const BorderSide(color: AppTheme.accentGreen),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'True',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onSubmit(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE8756B),
                  side: const BorderSide(color: Color(0xFFE8756B)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Fake / Misleading',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaseClosed extends StatelessWidget {
  const _CaseClosed({
    super.key,
    required this.pictureCase,
    required this.controller,
    required this.onDone,
  });

  final PictureCase pictureCase;
  final PictureCaseController controller;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final correct = controller.verdictWasCorrect;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              correct ? Icons.check_circle_rounded : Icons.info_rounded,
              color: correct ? AppTheme.accentGreen : AppTheme.amber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StageHeading(
                pictureCase.isReal ? 'This one checked out' : 'Case closed',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          pictureCase.verdictExplanation,
          style: const TextStyle(
            color: AppTheme.panelText,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your certainty line',
          style: TextStyle(
            color: AppTheme.panelMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _ConfidenceLine(values: controller.certaintyHistory),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.panelElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pictureCase.lessonLine,
                  style: const TextStyle(
                    color: AppTheme.panelText,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PrimaryButton(label: 'Back to case files', onPressed: onDone),
      ],
    );
  }
}

class _ConfidenceLine extends StatelessWidget {
  const _ConfidenceLine({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.panelMuted,
                size: 16,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.panelElevated,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${values[i].round()}%',
              style: const TextStyle(
                color: AppTheme.panelText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
