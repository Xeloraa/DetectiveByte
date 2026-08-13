import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'companion/controllers/companion_controller.dart';
import 'core/theme/app_theme.dart';
import 'onboarding/onboarding_screen.dart';
import 'screens/companion_screen.dart';
import 'services/desktop_overlay.dart';
import 'services/local_bridge_server.dart';
import 'services/overlay_hit_region.dart';
import 'services/storage/local_storage_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Overlay mode: transparent floating pet over the real desktop.
  // Dev default stays a normal window. Enable with:
  //   flutter run -d windows -- --overlay
  // or --dart-define=DESKTOP_OVERLAY=true
  final desktopOverlay = await DesktopOverlay.resolve(args);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final storage = await LocalStorageService.create();
  final controller = CompanionController(storage: storage);
  final hasSeenOnboarding = storage.loadHasSeenOnboarding();

  // Lets the companion browser extension hand off a video URL the instant
  // playback starts, instead of requiring a clipboard copy first. No-op on
  // web; silently skips if the port's already taken by another instance.
  unawaited(LocalBridgeServer(controller).start());

  runApp(
    DetectiveByteApp(
      controller: controller,
      storage: storage,
      desktopOverlay: desktopOverlay,
      hasSeenOnboarding: hasSeenOnboarding,
    ),
  );
}

class DetectiveByteApp extends StatefulWidget {
  const DetectiveByteApp({
    super.key,
    required this.controller,
    required this.storage,
    this.desktopOverlay = false,
    this.hasSeenOnboarding = false,
  });

  final CompanionController controller;
  final LocalStorageService storage;
  final bool desktopOverlay;
  final bool hasSeenOnboarding;

  @override
  State<DetectiveByteApp> createState() => _DetectiveByteAppState();
}

class _DetectiveByteAppState extends State<DetectiveByteApp> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = !widget.hasSeenOnboarding;
  }

  Future<void> _finishOnboarding() async {
    await widget.storage.saveHasSeenOnboarding(true);
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.light;
    // Keep parchment theme during onboarding so the carousel is readable;
    // switch to transparent chrome once the companion is live in overlay mode.
    final useTransparentChrome =
        widget.desktopOverlay && !_showOnboarding;
    final theme = useTransparentChrome
        ? base.copyWith(
            scaffoldBackgroundColor: Colors.transparent,
            canvasColor: Colors.transparent,
            colorScheme: base.colorScheme.copyWith(
              surface: Colors.transparent,
            ),
          )
        : base;

    return MaterialApp(
      title: 'Detective Byte',
      debugShowCheckedModeBanner: false,
      theme: theme,
      color: useTransparentChrome ? Colors.transparent : null,
      builder: (context, child) {
        return OverlayHitRegionHost(
          enabled: useTransparentChrome,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _showOnboarding
          ? OnboardingScreen(onFinished: _finishOnboarding)
          : CompanionScreen(
              controller: widget.controller,
              desktopOverlay: widget.desktopOverlay,
              // Only the real native overlay shows the actual desktop through
              // transparency — everywhere else (web, plain windowed dev run)
              // needs the painted office scene or the app looks blank.
              showPreviewBackground: !widget.desktopOverlay,
            ),
    );
  }
}
