import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../companion/models/idle_action.dart';
import '../../companion/widgets/detective_byte_character.dart';
import '../../core/theme/app_theme.dart';
import '../../services/media_pet_analysis_service.dart';

enum _Stage { analyzing, result, error }

/// Byte investigates a real image the user dropped on him — not one of the
/// curated [PictureCaseBank] cases. There's no ground truth to check
/// against here, so unlike [PictureCaseDialog] this doesn't score a
/// verdict; it shows the live analysis from the Media-Pet AI backend and
/// lets the child land on their own call, purely for their own reflection.
class LiveInvestigationDialog extends StatefulWidget {
  const LiveInvestigationDialog({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  static Future<void> show(
    BuildContext context, {
    required Uint8List imageBytes,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => LiveInvestigationDialog(imageBytes: imageBytes),
    );
  }

  @override
  State<LiveInvestigationDialog> createState() =>
      _LiveInvestigationDialogState();
}

class _LiveInvestigationDialogState extends State<LiveInvestigationDialog> {
  _Stage _stage = _Stage.analyzing;
  String? _analysis;
  String? _errorMessage;
  String? _userCall;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final result = await MediaPetAnalysisService.analyze(widget.imageBytes);
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _stage = _Stage.result;
      });
    } on MediaPetAnalysisException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _stage = _Stage.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.darkPanel.copyWith(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ByteHeader(line: _headerLine, onClose: _close),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  widget.imageBytes,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildStage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _headerLine {
    switch (_stage) {
      case _Stage.analyzing:
        return "Let's investigate this! Give me a moment to look closely…";
      case _Stage.result:
        return "Here's what I found. What do you think, detective?";
      case _Stage.error:
        return "Hmm, I couldn't get a good look at this one.";
    }
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.analyzing:
        return const _AnalyzingBody(key: ValueKey('analyzing'));
      case _Stage.result:
        return _ResultBody(
          key: const ValueKey('result'),
          analysis: _analysis!,
          selectedCall: _userCall,
          onSelectCall: (call) => setState(() => _userCall = call),
          onDone: _close,
        );
      case _Stage.error:
        return _ErrorBody(
          key: const ValueKey('error'),
          message: _errorMessage!,
          onRetry: () {
            setState(() => _stage = _Stage.analyzing);
            _runAnalysis();
          },
          onClose: _close,
        );
    }
  }

  void _close() => Navigator.of(context).pop();
}

class _ByteHeader extends StatelessWidget {
  const _ByteHeader({required this.line, required this.onClose});

  final String line;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          height: 68,
          child: Center(
            child: Transform.scale(
              scale: 0.3,
              // Same reasoning as picture_case_dialog.dart's _ByteHeader:
              // a small supporting portrait doesn't need a perpetual
              // breathing repaint loop running for the dialog's whole
              // lifetime.
              child: const DetectiveByteCharacter(
                pose: BytePose(
                  thinking: 1,
                  headTilt: -0.06,
                  idleActionKind: IdleAction.thinking,
                ),
                breathingEnabled: false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.panelElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              line,
              style: const TextStyle(
                color: AppTheme.panelText,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.panelMuted, size: 20),
          onPressed: onClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

class _AnalyzingBody extends StatelessWidget {
  const _AnalyzingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.foxOrange,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Checking the lighting, the details, the little things…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.panelMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: const TextStyle(color: AppTheme.panelText, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onClose,
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.foxOrange,
                ),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Renders the backend's markdown-ish (`**bold**`) analysis text with real
/// bold spans, plus an optional "what's your call" reflection row — no
/// scoring, no "correct" answer, since there's no known ground truth for an
/// arbitrary dropped image.
class _ResultBody extends StatelessWidget {
  const _ResultBody({
    super.key,
    required this.analysis,
    required this.selectedCall,
    required this.onSelectCall,
    required this.onDone,
  });

  final String analysis;
  final String? selectedCall;
  final ValueChanged<String> onSelectCall;
  final VoidCallback onDone;

  static const _calls = ['Looks real', 'Looks AI-made', 'Not sure yet'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.panelElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text.rich(_parseBold(analysis)),
        ),
        const SizedBox(height: 18),
        const Text(
          "What's your call?",
          style: TextStyle(
            color: AppTheme.panelText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final call in _calls)
              ChoiceChip(
                label: Text(call),
                selected: selectedCall == call,
                onSelected: (_) => onSelectCall(call),
                selectedColor: AppTheme.foxOrange,
                backgroundColor: AppTheme.panel,
                labelStyle: TextStyle(
                  color: selectedCall == call
                      ? AppTheme.coatDark
                      : AppTheme.panelText,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: AppTheme.panelBorder),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.foxOrange),
          child: const Text('Back to case files'),
        ),
      ],
    );
  }

  TextSpan _parseBold(String text) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return TextSpan(
      style: const TextStyle(
        color: AppTheme.panelText,
        fontSize: 13.5,
        height: 1.5,
      ),
      children: spans,
    );
  }
}
