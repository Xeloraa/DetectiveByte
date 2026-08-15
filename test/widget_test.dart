import 'package:detective_byte/companion/controllers/companion_controller.dart';
import 'package:detective_byte/main.dart';
import 'package:detective_byte/onboarding/onboarding_screen.dart';
import 'package:detective_byte/screens/companion_screen.dart';
import 'package:detective_byte/services/storage/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Onboarding shows on first launch', (WidgetTester tester) async {
    final storage = LocalStorageService.memory();
    final controller = CompanionController(storage: storage);
    await controller.setIdleAnimationsEnabled(false);

    await tester.pumpWidget(
      DetectiveByteApp(
        controller: controller,
        storage: storage,
        hasSeenOnboarding: false,
      ),
    );
    await tester.pump();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
    expect(find.text('Byte is idle on your screen.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    controller.dispose();
  });

  testWidgets('Detective Byte appears after onboarding is seen',
      (WidgetTester tester) async {
    final storage = LocalStorageService.memory();
    await storage.saveHasSeenOnboarding(true);
    final controller = CompanionController(storage: storage);
    await controller.setIdleAnimationsEnabled(false);

    await tester.pumpWidget(
      DetectiveByteApp(
        controller: controller,
        storage: storage,
        hasSeenOnboarding: true,
      ),
    );
    await tester.pump();

    expect(find.byType(CompanionScreen), findsOneWidget);
    expect(find.text('Detective Byte'), findsWidgets);
    expect(find.text("Today's Mission"), findsOneWidget);
    expect(find.text('Cases Solved'), findsOneWidget);
    // Fresh storage starts with zero solved cases (the old assertion
    // expected '3' from an early build that seeded the counter).
    expect(find.text('0'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    controller.dispose();
  });

  testWidgets('Get started dismisses onboarding and persists flag',
      (WidgetTester tester) async {
    final storage = LocalStorageService.memory();
    final controller = CompanionController(storage: storage);
    await controller.setIdleAnimationsEnabled(false);

    await tester.pumpWidget(
      DetectiveByteApp(
        controller: controller,
        storage: storage,
        hasSeenOnboarding: false,
      ),
    );
    await tester.pump();

    // Advance to last page. pumpAndSettle can't be used here: Byte's
    // breathing animation repeats forever by design, so settle the page
    // transitions (280ms each) with fixed-duration pumps instead.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CompanionScreen), findsOneWidget);
    expect(storage.loadHasSeenOnboarding(), isTrue);

    await tester.pump(const Duration(seconds: 4));
    controller.dispose();
  });

  testWidgets('Preview background shows demo chrome', (WidgetTester tester) async {
    final storage = LocalStorageService.memory();
    final controller = CompanionController(storage: storage);
    await controller.setIdleAnimationsEnabled(false);

    await tester.pumpWidget(
      MaterialApp(
        home: CompanionScreen(
          controller: controller,
          showPreviewBackground: true,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Drag Byte anywhere · Click to investigate'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    controller.dispose();
  });
}
