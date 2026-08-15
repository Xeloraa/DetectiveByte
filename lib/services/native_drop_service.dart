import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef ImageDroppedCallback = void Function(Uint8List bytes, String filename);

/// Bridge to the native OLE drop target (windows/runner/native_drop_target.*)
/// registered on the desktop companion window.
///
/// Handles both a real file drop (Explorer, a saved image) and a "virtual
/// file" drop — no file on disk, bytes handed over live via a stream, which
/// is how Chrome/Edge offer an in-page `<img>` dragged straight off a
/// webpage. `desktop_drop`, the community package this replaced, only
/// checked for real files, so a browser-image drag silently did nothing;
/// this exists specifically to cover that case.
abstract final class NativeDropService {
  static const MethodChannel _channel = MethodChannel(
    'detective_byte/native_drop',
  );

  /// True while a drag carrying a supported format is hovering the window.
  static final ValueNotifier<bool> hoveringNotifier = ValueNotifier<bool>(
    false,
  );

  static ImageDroppedCallback? onImageDropped;
  static VoidCallback? onDropFailed;

  static bool _listening = false;

  /// Idempotent — safe to call from every widget that cares about drops
  /// without worrying about double-registration.
  static void ensureListening() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler(_handleCall);
  }

  static Future<void> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'dragEntered':
        hoveringNotifier.value = true;
      case 'dragExited':
        hoveringNotifier.value = false;
      case 'imageDropped':
        hoveringNotifier.value = false;
        final args = (call.arguments as Map).cast<Object?, Object?>();
        final bytes = args['bytes'] as Uint8List?;
        final filename = args['filename'] as String? ?? 'dropped_image';
        if (bytes != null && bytes.isNotEmpty) {
          onImageDropped?.call(bytes, filename);
        } else {
          onDropFailed?.call();
        }
      case 'dropFailed':
        hoveringNotifier.value = false;
        onDropFailed?.call();
    }
  }
}
