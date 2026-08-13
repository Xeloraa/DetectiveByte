import '../companion/controllers/companion_controller.dart';

import 'local_bridge_server_io.dart'
    if (dart.library.html) 'local_bridge_server_web.dart' as impl;

/// Tiny localhost HTTP bridge so the companion browser extension can hand
/// off a TikTok/YouTube link the instant the user presses play, instead of
/// requiring a copy-paste round trip through the clipboard. No-op on web.
abstract class LocalBridgeServer {
  factory LocalBridgeServer(CompanionController controller) =
      impl.LocalBridgeServerImpl;

  Future<void> start();
  Future<void> stop();
}
