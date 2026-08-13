import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows desktop-pet overlay bridge.
///
/// The native host owns exactly one window that switches chrome at runtime:
/// a normal decorated window (full app UI) by default, and a borderless /
/// transparent / click-through overlay (Byte only) while minimized. This
/// class mirrors that current mode reactively via [modeNotifier] — native
/// pushes a "chromeModeChanged" call whenever the user minimizes/restores,
/// so Dart can swap its UI without a restart. The `--overlay` launch flag
/// still exists for dev testing the overlay chrome standalone.
class DesktopOverlay {
  DesktopOverlay._();

  static const MethodChannel _channel =
      MethodChannel('detective_byte/desktop_overlay');

  static bool _resolved = false;

  /// True when the Win32 host is currently borderless / transparent /
  /// always-on-top. Updates live as the window is minimized/restored.
  static final ValueNotifier<bool> modeNotifier = ValueNotifier<bool>(false);

  static bool get isOverlayMode => modeNotifier.value;

  static bool get _isWindowsHost =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Resolves overlay mode from dart entrypoint args and (on Windows) the
  /// host, then wires up live updates from native. Call once at startup.
  static Future<bool> resolve(List<String> args) async {
    if (_resolved) return modeNotifier.value;
    _resolved = true;

    final fromArgs = args.contains('--overlay');
    final fromEnv =
        const bool.fromEnvironment('DESKTOP_OVERLAY', defaultValue: false);

    var native = false;
    if (_isWindowsHost) {
      _channel.setMethodCallHandler(_handleNativeCall);
      try {
        final result = await _channel.invokeMethod<bool>('isOverlayMode');
        native = result ?? false;
      } on MissingPluginException {
        native = false;
      } on PlatformException {
        native = false;
      }
    }

    modeNotifier.value = native || fromArgs || fromEnv;
    return modeNotifier.value;
  }

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'chromeModeChanged') {
      modeNotifier.value = call.arguments as bool? ?? modeNotifier.value;
    }
  }

  /// Asks the native host to switch back to the normal decorated window —
  /// e.g. after the user double-taps Byte while it's floating minimized.
  /// No-op if there's no normal window to restore to (a standalone
  /// `--overlay`-launched process).
  static Future<void> restoreNormalWindow() async {
    if (!_isWindowsHost) return;
    try {
      await _channel.invokeMethod<void>('restoreNormalWindow');
    } on MissingPluginException {
      // Host without the channel (tests / non-Windows embeds).
    } on PlatformException {
      // Ignore transient channel failures during teardown.
    }
  }

  /// Quits the app via the same path as clicking the window's close button
  /// (WM_CLOSE), rather than exiting the process directly, so teardown
  /// happens the same way either way.
  static Future<void> closeApp() async {
    if (!_isWindowsHost) return;
    try {
      await _channel.invokeMethod<void>('closeApp');
    } on MissingPluginException {
      // Host without the channel (tests / non-Windows embeds).
    } on PlatformException {
      // Ignore transient channel failures during teardown.
    }
  }

  /// Reports interactive regions in **physical** pixels (client coordinates).
  static Future<void> updateHitRegions(List<Rect> regions) async {
    if (!isOverlayMode || !_isWindowsHost) return;

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
