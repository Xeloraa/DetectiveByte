import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../companion/controllers/companion_controller.dart';
import '../companion/widgets/companion_widget.dart';
import '../companion/widgets/investigation_overlay.dart';
import '../companion/widgets/overlay_panels.dart';
import '../core/theme/app_theme.dart';
import '../investigation/widgets/live_investigation_dialog.dart';
import '../services/overlay_hit_region.dart';

/// Desktop companion stage — transparent over the real desktop by default.
///
/// Set [showPreviewBackground] for screenshots/demo mode (fake desktop chrome).
class CompanionScreen extends StatefulWidget {
  const CompanionScreen({
    super.key,
    required this.controller,
    this.desktopOverlay = false,
    this.showPreviewBackground = false,
  });

  final CompanionController controller;
  final bool desktopOverlay;

  /// When true, shows the detective office background image behind Byte.
  final bool showPreviewBackground;

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> {
  bool _dragHovering = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    super.dispose();
  }

  void _onControllerTick() {
    // Position / visibility changes need fresh Win32 hit regions.
    if (!widget.desktopOverlay) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      OverlayHitRegionHost.of(context)?.scheduleSync();
    });
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _dragHovering = false);
    if (details.files.isEmpty) return;

    final bytes = await details.files.first.readAsBytes();
    if (!mounted || bytes.isEmpty) return;

    widget.controller.onCaseFlowOpened();
    await LiveInvestigationDialog.show(context, imageBytes: bytes);
    if (mounted) widget.controller.onCaseFlowClosed();
  }

  @override
  Widget build(BuildContext context) {
    final overlay = widget.desktopOverlay;
    final preview = widget.showPreviewBackground;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragHovering = true),
      onDragExited: (_) => setState(() => _dragHovering = false),
      onDragDone: _handleDrop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: preview
              ? const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/byte/office_background.png'),
                    fit: BoxFit.cover,
                  ),
                )
              : const BoxDecoration(color: Colors.transparent),
          child: Stack(
            children: [
              if (preview)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      child: _BrandHeader(),
                    ),
                  ),
                ),
              ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  return CompanionWidget(
                    controller: widget.controller,
                    reportOverlayHits: overlay,
                  );
                },
              ),
              OverlayPanels(
                controller: widget.controller,
                reportOverlayHits: overlay,
              ),
              InvestigationOverlay(
                controller: widget.controller,
                reportOverlayHits: overlay,
              ),
              if (preview)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Drag Byte anywhere · Click to investigate',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          shadows: [
                            const Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _dragHovering ? 1 : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.foxOrange, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.panel.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Drop it on Byte to investigate',
                        style: TextStyle(
                          color: AppTheme.panelText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_rounded, color: AppTheme.foxOrange, size: 22),
            const SizedBox(width: 8),
            Text(
              'Detective Byte',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [const Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your pocket detective who investigates with you.',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            shadows: [const Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}
