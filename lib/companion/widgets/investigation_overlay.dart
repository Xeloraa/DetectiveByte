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
            : const _MissionCompleteCard(
                key: ValueKey('complete'),
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
            _hasVideo ? 'Analyzing the video…' : AppConstants.analyzingSpeechNoLink,
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
}

class _MissionCompleteCard extends StatelessWidget {
  const _MissionCompleteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: AppTheme.darkPanel.copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accentGreen, width: 2),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppTheme.accentGreen,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mission Completed!',
            style: TextStyle(
              color: AppTheme.panelText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Great detective work — keep questioning what you see.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.panelMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
