import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'desktop_overlay.dart';

/// Measures registered interactive widgets and pushes hit-rects to Win32.
class OverlayHitRegionHost extends StatefulWidget {
  const OverlayHitRegionHost({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  static OverlayHitRegionHostState? of(BuildContext context) {
    return context.findAncestorStateOfType<OverlayHitRegionHostState>();
  }

  @override
  State<OverlayHitRegionHost> createState() => OverlayHitRegionHostState();
}

class OverlayHitRegionHostState extends State<OverlayHitRegionHost>
    with WidgetsBindingObserver {
  final Map<Object, GlobalKey> _keys = {};
  bool _scheduled = false;

  GlobalKey register(Object id) {
    return _keys.putIfAbsent(id, GlobalKey.new);
  }

  void unregister(Object id) {
    _keys.remove(id);
    scheduleSync();
  }

  void scheduleSync() {
    if (!widget.enabled || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _syncRegions();
    });
  }

  Future<void> _syncRegions() async {
    if (!mounted || !widget.enabled) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final regions = <Rect>[];

    for (final key in _keys.values) {
      final context = key.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;

      final topLeft = box.localToGlobal(Offset.zero);
      final size = box.size;
      regions.add(
        Rect.fromLTWH(
          topLeft.dx * dpr,
          topLeft.dy * dpr,
          size.width * dpr,
          size.height * dpr,
        ),
      );
    }

    await DesktopOverlay.updateHitRegions(regions);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleSync();
  }

  @override
  void didUpdateWidget(covariant OverlayHitRegionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleSync();
  }

  @override
  void didChangeMetrics() {
    scheduleSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Marks [child] as an interactive hit target in desktop overlay mode.
class OverlayHitTarget extends StatefulWidget {
  const OverlayHitTarget({
    super.key,
    required this.id,
    required this.child,
  });

  final Object id;
  final Widget child;

  @override
  State<OverlayHitTarget> createState() => _OverlayHitTargetState();
}

class _OverlayHitTargetState extends State<OverlayHitTarget> {
  OverlayHitRegionHostState? _host;
  GlobalKey? _key;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = OverlayHitRegionHost.of(context);
    if (!identical(host, _host)) {
      _host?.unregister(widget.id);
      _host = host;
      _key = host?.register(widget.id);
      _host?.scheduleSync();
    }
  }

  @override
  void dispose() {
    _host?.unregister(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = _key;
    if (key == null) return widget.child;
    return KeyedSubtree(
      key: key,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _host?.scheduleSync();
          return false;
        },
        child: SizeChangedLayoutNotifier(child: widget.child),
      ),
    );
  }
}
