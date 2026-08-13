import '../companion/controllers/companion_controller.dart';
import 'local_bridge_server.dart';

/// Web has no loopback server access — no-op implementation.
class LocalBridgeServerImpl implements LocalBridgeServer {
  LocalBridgeServerImpl(this._controller);

  // ignore: unused_field
  final CompanionController _controller;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
