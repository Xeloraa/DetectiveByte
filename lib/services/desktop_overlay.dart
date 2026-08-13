import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows desktop-pet overlay bridge.
///
/// Overlay mode is gated by the native `--overlay` flag
/// (`flutter run -d windows -- --overlay`). Without it, the app runs in a
/// normal decorated window for development.
class DesktopOverlay {
  DesktopOverlay._();

  static const MethodChannel _channel =
      MethodChannel('detective_byte/desktop_overlay');

  static bool _resolved = false;
  static bool _overlayMode = false;

  static bool get _isWindowsHost =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// True when the Win32 host is borderless / transparent / always-on-top.
  static bool get isOverlayMode => _overlayMode;

  /// Resolves overlay mode from dart entrypoint args and (on Windows) the host.
  static Future<bool> resolve(List<String> args) async {
    if (_resolved) return _overlayMode;

    final fromArgs = args.contains('--overlay');
    final fromEnv =
        const bool.fromEnvironment('DESKTOP_OVERLAY', defaultValue: false);

    var native = false;
    if (_isWindowsHost) {
      try {
        final result = await _channel.invokeMethod<bool>('isOverlayMode');
        native = result ?? false;
      } on MissingPluginException {
        native = false;
      } on PlatformException {
        native = false;
      }
    }

    _overlayMode = native || fromArgs || fromEnv;
    _resolved = true;
    return _overlayMode;
  }

  /// Reports interactive regions in **physical** pixels (client coordinates).
  static Future<void> updateHitRegions(List<Rect> regions) async {
    if (!_overlayMode || !_isWindowsHost) return;

    final payload = regions
        .where((r) => r.width > 0 && r.height > 0)
        .map(
          (r) => <String, double>{
            'left': r.left,
            'top': r.top,
            'right': r.right,
            'bottom': r.bottom,
          },
        )
        .toList(growable: false);

    try {
      await _channel.invokeMethod<void>('updateHitRegions', payload);
    } on MissingPluginException {
      // Host without the channel (tests / non-Windows embeds).
    } on PlatformException {
      // Ignore transient channel failures during teardown.
    }
  }
}
