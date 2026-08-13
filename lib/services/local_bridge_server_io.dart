import 'dart:convert';
import 'dart:io';

import '../companion/controllers/companion_controller.dart';
import 'local_bridge_server.dart';

/// Loopback-only HTTP server the browser extension POSTs a video URL to.
class LocalBridgeServerImpl implements LocalBridgeServer {
  LocalBridgeServerImpl(this._controller);

  final CompanionController _controller;
  HttpServer? _server;

  /// Fixed port the extension is hardcoded to talk to.
  static const int port = 8791;

  @override
  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } catch (_) {
      // Port already taken — most likely another instance of this app is
      // already running and serving it. Nothing to do.
      return;
    }

    _server!.listen((request) async {
      _applyCors(request.response);

      if (request.method == 'OPTIONS') {
        await request.response.close();
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/investigate') {
        await _handleInvestigate(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }

      await request.response.close();
    });
  }

  Future<void> _handleInvestigate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final url = json['url'] as String?;
      if (url == null || url.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        return;
      }
      _controller.investigateUrl(url);
      request.response.statusCode = HttpStatus.ok;
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
    }
  }

  void _applyCors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
  }

  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
