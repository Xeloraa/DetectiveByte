import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../investigation/data/picture_case_bank.dart';
import '../../investigation/widgets/picture_case_dialog.dart';
import '../../services/overlay_hit_region.dart';
import '../../settings/settings_sheet.dart';
import '../controllers/companion_controller.dart';

/// Top-right dark widgets from the product mockup.
class OverlayPanels extends StatelessWidget {
  const OverlayPanels({
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
        final column = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusCard(
                enabled: state.isEnabled,
                onToggle: controller.setEnabled,
                onOpenSettings: () => SettingsSheet.show(context, controller),
              ),
              const SizedBox(height: 10),
              _MissionCard(
                progress: state.missionProgress,
                target: state.missionTarget,
                onTap: () => PictureCaseDialog.show(
                  context,
                  pictureCase: PictureCaseBank.caseForToday(),
                  onSolved: controller.recordCaseSolved,
                ),
              ),
              const SizedBox(height: 10),
              _JournalCard(casesSolved: state.casesSolved),
            ],
          ),
        );

        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: reportOverlayHits
                  ? OverlayHitTarget(id: 'panels', child: column)
                  : column,
            ),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.enabled,
    required this.onToggle,
    required this.onOpenSettings,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: AppTheme.darkPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppTheme.panelElevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: AppTheme.foxOrange,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Detective Byte',
                  style: TextStyle(
                    color: AppTheme.panelText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                enabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: enabled ? AppTheme.accentGreen : AppTheme.panelMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                value: enabled,
                onChanged: onToggle,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              IconButton(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_rounded, size: 18),
                color: AppTheme.panelMuted,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            enabled ? 'Click me to investigate!' : 'Byte is hidden',
            style: const TextStyle(
              color: AppTheme.panelMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.progress,
    required this.target,
    required this.onTap,
  });

  final int progress;
  final int target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
    final done = progress >= target;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: AppTheme.darkPanel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's Mission",
                    style: TextStyle(
                      color: AppTheme.panelText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$progress/$target',
                  style: TextStyle(
                    color: done ? AppTheme.accentGreen : AppTheme.panelMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.todaysMission,
              style: const TextStyle(
                color: AppTheme.panelMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 7,
                      backgroundColor: const Color(0xFF3A3A3A),
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  done
                      ? Icons.card_giftcard_rounded
                      : Icons.card_giftcard_outlined,
                  color: done ? AppTheme.accentGreen : AppTheme.panelMuted,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.casesSolved});

  final int casesSolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: AppTheme.darkPanel,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cases Solved',
                  style: TextStyle(
                    color: AppTheme.panelMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$casesSolved',
                  style: const TextStyle(
                    color: AppTheme.panelText,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.panelElevated,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppTheme.amber,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
