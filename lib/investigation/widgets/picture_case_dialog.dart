import 'package:flutter/material.dart';

import '../../companion/models/idle_action.dart';
import '../../companion/widgets/detective_byte_character.dart';
import '../../core/constants/app_constants.dart';
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Byte investigates *with* the child — a mini Byte plus a
              // running commentary, one line per stage, stays pinned above
              // the stage content instead of Byte being decoration outside
              // the modal.
              _ByteCommentary(
                line: _byteLine,
                pose: _bytePose,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildStage(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Byte's commentary line for the current stage. Kept non-punitive by
  /// design: the closed-stage line celebrates a match and reframes a miss
  /// as learning, never "you got it wrong."
  String get _byteLine {
    switch (_controller.stage) {
      case CaseStage.briefing:
        return "A new case! Let's look at this post together.";
      case CaseStage.zoomedOut:
        return 'Wait… let me get a closer look.';
      case CaseStage.certainty:
        return _controller.clueIndex == -1
            ? 'No wrong answer — how sure do you feel right now?'
            : 'Did that clue change how sure you are?';
      case CaseStage.clue:
        return "Hmm! New evidence. Let's weigh it together.";
      case CaseStage.verdict:
        return "You've seen the clues. What's your call, detective?";
      case CaseStage.closed:
        if (_controller.verdictWasCorrect) {
          return _controller.pictureCase.truth == CaseVerdict.inconclusive
              ? "Sometimes 'not sure yet' is the smartest answer!"
              : 'Great detective work — your call matched the evidence!';
        }
        return 'Good try! Every case teaches us something.';
    }
  }

  BytePose get _bytePose {
    switch (_controller.stage) {
      case CaseStage.briefing:
        return const BytePose();
      case CaseStage.zoomedOut:
        return const BytePose(
          scale: AppConstants.tapScale,
          leanForward: 0.12,
          magnifierRaise: 1.0,
          headTilt: -0.05,
        );
      case CaseStage.certainty:
        return const BytePose(
          thinking: 1,
          headTilt: -0.06,
          idleActionKind: IdleAction.thinking,
        );
      case CaseStage.clue:
        return const BytePose(
          handToBrow: 0.85,
          headTilt: 0.06,
          lookDirection: 0.2,
          idleActionKind: IdleAction.lookAround,
        );
      case CaseStage.verdict:
        return const BytePose();
      case CaseStage.closed:
        return _controller.verdictWasCorrect
            ? const BytePose(scale: 1.05, thumbsUp: 1, wink: 1)
            : const BytePose(thinking: 1, idleActionKind: IdleAction.thinking);
    }
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
    final asset = pictureCase.photoAsset;
    if (asset == null) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            asset,
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
          ),
        ),
        if (pictureCase.photoAttribution != null) ...[
          const SizedBox(height: 4),
          Text(
            pictureCase.photoAttribution!,
            style: const TextStyle(color: AppTheme.panelMuted, fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// Mini Byte + his current commentary line + the dialog close button.
///
/// The sprite is the same [DetectiveByteCharacter] scaled down — one more
/// place where pose assets double as "Byte reacting," so the case flow and
/// the desktop companion feel like the same character.
class _ByteCommentary extends StatelessWidget {
  const _ByteCommentary({
    required this.line,
    required this.pose,
    required this.onClose,
  });

  final String line;
  final BytePose pose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          height: 80,
          child: Center(
            child: Transform.scale(
              scale: 0.34,
              child: DetectiveByteCharacter(pose: pose),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.panelElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                line,
                key: ValueKey<String>(line),
                style: const TextStyle(
                  color: AppTheme.panelText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppTheme.panelMuted,
          tooltip: 'Close case (progress is lost)',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
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
          clue.isStrongSignal
              ? "That's a strong clue — worth leaning on, but still not "
                    'a final answer on its own.'
              : "That's just a hint — too thin to build a verdict on by "
                    'itself.',
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

  final ValueChanged<CaseVerdict> onSubmit;

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
              child: _VerdictButton(
                label: 'True',
                color: AppTheme.accentGreen,
                onPressed: () => onSubmit(CaseVerdict.real),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VerdictButton(
                label: 'Fake / Misleading',
                color: const Color(0xFFE8756B),
                onPressed: () => onSubmit(CaseVerdict.fake),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _VerdictButton(
          label: 'Not sure yet — need more evidence',
          color: AppTheme.amber,
          onPressed: () => onSubmit(CaseVerdict.inconclusive),
        ),
      ],
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
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
    final truth = pictureCase.truth;
    final verdictStyle = _VerdictStyle.of(truth);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The at-a-glance answer: color-coded banner so real / fake /
        // inconclusive is unmistakable before any reading starts.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: verdictStyle.color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: verdictStyle.color.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Icon(verdictStyle.icon, color: verdictStyle.color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdictStyle.banner,
                      style: TextStyle(
                        color: verdictStyle.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      correct
                          ? 'Your call matched the evidence.'
                          : 'Your call was different this time — that’s okay.',
                      style: TextStyle(
                        color: verdictStyle.color.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          pictureCase.verdictExplanation,
          style: const TextStyle(
            color: AppTheme.panelText,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'The evidence, recapped',
          style: TextStyle(
            color: AppTheme.panelMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _EvidenceRecapRow(
          label: 'Look closer',
          text: pictureCase.zoomOutReveal,
          strong: null, // an observation, not a signal either way
        ),
        for (final clue in pictureCase.clues)
          _EvidenceRecapRow(
            label: clue.question,
            text: clue.reveal,
            strong: clue.isStrongSignal,
          ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
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

/// Color/icon/wording for each of the three verdicts, in one place so the
/// banner, and any future surface showing a verdict, can't drift apart.
class _VerdictStyle {
  const _VerdictStyle._(this.color, this.icon, this.banner);

  final Color color;
  final IconData icon;
  final String banner;

  static _VerdictStyle of(CaseVerdict verdict) => switch (verdict) {
    CaseVerdict.real => const _VerdictStyle._(
      AppTheme.accentGreen,
      Icons.verified_rounded,
      'Checks out — REAL',
    ),
    CaseVerdict.fake => const _VerdictStyle._(
      Color(0xFFE8756B),
      Icons.report_gmailerrorred_rounded,
      'FAKE / MISLEADING',
    ),
    CaseVerdict.inconclusive => const _VerdictStyle._(
      AppTheme.amber,
      Icons.help_rounded,
      'INCONCLUSIVE — not enough evidence yet',
    ),
  };
}

/// One row of the case-closed evidence recap: what was checked, what it
/// showed, and whether that signal is actually reliable ("Strong clue"
/// vs "Just a hint") — the "here's what that tells us" framing.
class _EvidenceRecapRow extends StatelessWidget {
  const _EvidenceRecapRow({
    required this.label,
    required this.text,
    required this.strong,
  });

  final String label;
  final String text;

  /// null = not a reliability signal at all (e.g. the look-closer
  /// observation), true/false = strong clue vs weak hint.
  final bool? strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panelElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.panelText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (strong != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (strong! ? AppTheme.accentGreen : AppTheme.amber)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    strong! ? 'Strong clue' : 'Just a hint',
                    style: TextStyle(
                      color: strong! ? AppTheme.accentGreen : AppTheme.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.panelMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
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
