import 'package:flutter/material.dart';

import '../companion/controllers/companion_controller.dart';
import '../core/theme/app_theme.dart';
import '../services/desktop_overlay.dart';
import '../services/overlay_hit_region.dart';

/// Dark floating settings panel matching the product mockup.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.controller,
  });

  final CompanionController controller;

  static Future<void> show(
    BuildContext context,
    CompanionController controller,
  ) async {
    // While the modal is open, accept clicks across the whole window so the
    // barrier remains interactive in overlay/click-through mode.
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
          ? Colors.black26
          : Colors.black38,
      builder: (_) => SettingsSheet(controller: controller),
    );

    if (context.mounted) {
      OverlayHitRegionHost.of(context)?.scheduleSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final percent = (state.transparency * 100).round();

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
            decoration: AppTheme.darkPanel.copyWith(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Detective Byte Settings',
                        style: TextStyle(
                          color: AppTheme.panelText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppTheme.panelMuted,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  label: 'Enable Detective Byte',
                  value: state.isEnabled,
                  onChanged: controller.setEnabled,
                ),
                const SizedBox(height: 14),
                _SettingRow(
                  label: 'Start with system',
                  subtitle: 'Show Byte when device starts',
                  value: state.startWithSystem,
                  onChanged: controller.setStartWithSystem,
                ),
                const SizedBox(height: 14),
                _SettingRow(
                  label: 'Idle animations',
                  subtitle: 'Byte blinks, thinks, and wanders around on his own',
                  value: state.idleAnimationsEnabled,
                  onChanged: controller.setIdleAnimationsEnabled,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transparency',
                            style: TextStyle(
                              color: AppTheme.panelText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Adjust how solid Byte looks',
                            style: TextStyle(
                              color: AppTheme.panelMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Slider(
                  value: state.transparency,
                  min: 0.2,
                  max: 1.0,
                  onChanged: controller.setTransparency,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () async {
                    await controller.resetPosition();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Reset position',
                    style: TextStyle(
                      color: AppTheme.panelMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.panelText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppTheme.panelMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
