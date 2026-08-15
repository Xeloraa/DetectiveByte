import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/overlay_hit_region.dart';
import '../controllers/companion_controller.dart';
import '../models/investigation_phase.dart';

/// Phone analysis + mission-complete UI from the product mockup.
class InvestigationOverlay extends StatelessWidget {
  const InvestigationOverlay({
    super.key,
    required this.controller,
    this.reportOverlayHits = false,
  });

  final CompanionController controller;
  final bool reportOverlayHits;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        if (!state.isEnabled) return const SizedBox.shrink();

        final showAnalyze = state.phase == InvestigationPhase.analyzing;
        final showComplete = state.phase == InvestigationPhase.completed;

        if (!showAnalyze && !showComplete) return const SizedBox.shrink();

        final card = showAnalyze
            ? _AnalyzeCard(
                key: const ValueKey('analyze'),
                progress: state.analyzeProgress,
                platform: state.videoPlatform,
                title: state.videoTitle,
                author: state.videoAuthor,
                thumbnailUrl: state.videoThumbnailUrl,
              )
            : _CaseReportCard(
                key: const ValueKey('complete'),
                foundVideo: state.videoPlatform != null,
                platform: state.videoPlatform,
                title: state.videoTitle,
                author: state.videoAuthor,
              );

        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: reportOverlayHits
                  ? OverlayHitTarget(
                      id: 'investigation',
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: card,
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: card,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _AnalyzeCard extends StatelessWidget {
  const _AnalyzeCard({
    super.key,
    required this.progress,
    this.platform,
    this.title,
    this.author,
    this.thumbnailUrl,
  });

  final double progress;
  final String? platform;
  final String? title;
  final String? author;
  final String? thumbnailUrl;

  bool get _hasVideo => platform != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: AppTheme.darkPanel.copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 160,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A2A48), Color(0xFF1C2434)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_hasVideo && thumbnailUrl != null)
                  Image.network(
                    thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white38,
                          ),
                        ),
                      );
                    },
                  ),
                if (_hasVideo)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                if (_hasVideo)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.amber,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            platform!,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.link_off_rounded,
                      color: Colors.white38,
                      size: 36,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Text(
                      AppConstants.noLinkHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                Positioned(
                  right: 10,
                  top: 10,
                  child: Icon(
                    Icons.search_rounded,
                    color: AppTheme.amber.withValues(alpha: 0.9),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _stepLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.panelText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF3A3A3A),
              color: AppTheme.accentGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'He looks for clues, context, and hidden details.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.panelMuted.withValues(alpha: 0.95),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Narrates what Byte is doing as the bar fills, so analyzing reads as
  /// a real check with steps — not a silent progress bar.
  String get _stepLabel {
    if (_hasVideo) {
      if (progress < 0.35) return 'Checking who posted it…';
      if (progress < 0.7) return 'Reading the title and details…';
      return 'Comparing it with the claim…';
    }
    if (progress < 0.5) return 'Looking for a link to check…';
    return 'No link found — that tells us something too!';
  }
}

/// Byte's case report — the verdict (found / can't tell yet) plus the
/// evidence for it, so a child sees *why*, not just that the mission ended.
///
/// Framing matters here: finding the real video is evidence about the
/// *video*, never proof of the *story* around it — the card says exactly
/// that, which is the app's core media-literacy lesson.
class _CaseReportCard extends StatelessWidget {
  const _CaseReportCard({
    super.key,
    required this.foundVideo,
    this.platform,
    this.title,
    this.author,
  });

  final bool foundVideo;
  final String? platform;
  final String? title;
  final String? author;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: AppTheme.darkPanel.copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_special_rounded,
                color: AppTheme.amber,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Case Report',
                style: TextStyle(
                  color: AppTheme.panelText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(
                foundVideo ? Icons.verified_rounded : Icons.help_rounded,
                color: foundVideo ? AppTheme.accentGreen : AppTheme.amber,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _VerdictPill(foundVideo: foundVideo),
          const SizedBox(height: 12),
          if (foundVideo) ...[
            _EvidenceLine(
              icon: Icons.check_circle_rounded,
              color: AppTheme.accentGreen,
              text: 'It really exists on $platform.',
            ),
            if (author != null && author!.isNotEmpty)
              _EvidenceLine(
                icon: Icons.check_circle_rounded,
                color: AppTheme.accentGreen,
                text: 'Posted by “$author”.',
              ),
            if (title != null && title!.isNotEmpty)
              _EvidenceLine(
                icon: Icons.play_circle_outline_rounded,
                color: AppTheme.panelMuted,
                text: '“${_ellipsize(title!, 60)}”',
              ),
            _EvidenceLine(
              icon: Icons.help_rounded,
              color: AppTheme.amber,
              text: 'When and why it was posted — still unknown.',
            ),
            _EvidenceLine(
              icon: Icons.priority_high_rounded,
              color: const Color(0xFFE8756B),
              text: 'A real video doesn’t prove the caption is true.',
            ),
            const SizedBox(height: 10),
            Text(
              'Next: check the date, the account, and who else is '
              'reporting it.',
              style: TextStyle(
                color: AppTheme.panelMuted.withValues(alpha: 0.9),
                fontSize: 11,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ] else ...[
            _EvidenceLine(
              icon: Icons.link_off_rounded,
              color: AppTheme.panelMuted,
              text: 'No video link found to check.',
            ),
            _EvidenceLine(
              icon: Icons.looks_one_rounded,
              color: AppTheme.accentGreen,
              text: 'Copy a TikTok, YouTube, or Reels link.',
            ),
            _EvidenceLine(
              icon: Icons.looks_two_rounded,
              color: AppTheme.accentGreen,
              text: 'Tap Byte to investigate it together.',
            ),
            const SizedBox(height: 10),
            Text(
              'No link, no check — that’s an “inconclusive,” not a yes.',
              style: TextStyle(
                color: AppTheme.panelMuted.withValues(alpha: 0.9),
                fontSize: 11,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _ellipsize(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
  }
}

/// The one-word answer at a glance, color-coded: green = verified,
/// amber = can't tell yet. Deliberately no "fake" pill in the video flow
/// — Byte can only confirm what oEmbed proves, never declare a video fake.
class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.foundVideo});

  final bool foundVideo;

  @override
  Widget build(BuildContext context) {
    final color = foundVideo ? AppTheme.accentGreen : AppTheme.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        foundVideo
            ? 'FOUND — but is the story true?'
            : 'CAN’T TELL YET — no link to check',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.panelText,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
