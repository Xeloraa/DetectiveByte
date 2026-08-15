import 'package:detective_byte/companion/controllers/companion_controller.dart';
import 'package:detective_byte/companion/models/companion_position.dart';
import 'package:detective_byte/companion/models/idle_action.dart';
import 'package:detective_byte/companion/models/investigation_phase.dart';
import 'package:detective_byte/core/constants/app_constants.dart';
import 'package:detective_byte/investigation/data/picture_case_bank.dart';
import 'package:detective_byte/investigation/models/picture_case.dart';
import 'package:detective_byte/screens/companion_screen.dart';
import 'package:detective_byte/services/storage/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // pumpAndSettle can't be used anywhere Byte renders: his breathing
  // animation repeats forever by design. Settle transitions with
  // fixed-duration pumps instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Byte wanders on his own and persists where he stops',
      (WidgetTester tester) async {
    final storage = LocalStorageService.memory();
    // Wander-only pool makes the test deterministic: the very first idle
    // action scheduled is a walk.
    final controller = CompanionController(
      storage: storage,
      idleActionPool: const [IdleAction.wander],
    );

    await tester.pumpWidget(
      MaterialApp(home: CompanionScreen(controller: controller)),
    );
    await tester.pump();

    // Park Byte in the top-left corner so nearly every legal target
    // (panel zone excluded) clears the minimum-walk-distance filter.
    await controller.updatePosition(const CompanionPosition(x: 0, y: 0));
    final start = controller.state.position;

    // Greeting holds 3s, schedule delay 4-10s, walk 2.8-4.6s. Observe
    // second by second until the first walk starts and then finishes.
    var sawWalk = false;
    var finished = false;
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (controller.state.currentIdleAction == IdleAction.wander) {
        sawWalk = true;
      } else if (sawWalk) {
        finished = true;
        break;
      }
    }
    expect(finished, isTrue, reason: 'a walk should start and finish');

    // Freeze the scheduler so a follow-up walk can't disturb the asserts.
    controller.onDragStart();

    final end = controller.state.position;
    expect(
      end.x != start.x || end.y != start.y,
      isTrue,
      reason: 'Byte should have walked somewhere by now',
    );
    expect(controller.state.walkPhase, 0,
        reason: 'the walk finished and the hop cycle reset');

    // Where he stopped is what gets saved for next launch.
    await tester.pump();
    final saved = storage.loadPosition();
    expect((saved.x - end.x).abs() < 0.0001, isTrue);
    expect((saved.y - end.y).abs() < 0.0001, isTrue);

    controller.onDragEnd();
    await tester.pump(const Duration(seconds: 4));
    controller.dispose();
  });

  testWidgets('dragging Byte freezes wandering, releasing resumes it',
      (WidgetTester tester) async {
    final storage = LocalStorageService.memory();
    final controller = CompanionController(
      storage: storage,
      idleActionPool: const [IdleAction.wander],
    );

    await tester.pumpWidget(
      MaterialApp(home: CompanionScreen(controller: controller)),
    );
    await tester.pump();

    // Wait for the first walk to be in flight — it starts after the 3s
    // greeting plus a 4-10s schedule delay, and lasts 2.8-4.6s, so sample
    // second by second instead of guessing one exact moment.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (controller.state.currentIdleAction == IdleAction.wander) break;
    }
    expect(controller.state.currentIdleAction, IdleAction.wander);
    final midWalk = controller.state.position;

    controller.onDragStart();
    await tester.pump();
    expect(controller.state.currentIdleAction, IdleAction.none,
        reason: 'grabbing Byte stops the walk immediately');
    expect(controller.state.walkPhase, 0);

    // Position stayed wherever the walk was interrupted, and was saved.
    await tester.pump();
    final saved = storage.loadPosition();
    expect((saved.x - midWalk.x).abs() < 0.0001, isTrue);
    expect((saved.y - midWalk.y).abs() < 0.0001, isTrue);

    controller.onDragEnd();
    await tester.pump();

    await tester.pump(const Duration(seconds: 4));
    controller.dispose();
  });

  testWidgets('picture case flow runs end-to-end to a verdict',
      (WidgetTester tester) async {
    final storage = LocalStorageService.memory();
    final controller = CompanionController(storage: storage);
    await controller.setIdleAnimationsEnabled(false);

    final todayCase = PictureCaseBank.caseForToday();

    await tester.pumpWidget(
      MaterialApp(home: CompanionScreen(controller: controller)),
    );
    await settle(tester);
    // Let the welcome greeting expire so phase settles to idle.
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text("Today's Mission"));
    await settle(tester);

    // Byte's briefing commentary + the case caption are on screen.
    expect(
      find.text("A new case! Let's look at this post together."),
      findsOneWidget,
    );
    expect(find.text(todayCase.caption), findsOneWidget);

    // briefing -> look closer
    await tester.tap(find.text('Investigate'));
    await settle(tester);
    expect(find.text('Look Closer'), findsOneWidget);

    // look closer -> first certainty read
    await tester.tap(find.text('Continue'));
    await settle(tester);

    // certainty/clue loop: lock in, then either keep investigating or
    // move to the verdict after the last clue.
    var certaintyReads = 0;
    while (find.text('Lock it in').evaluate().isNotEmpty) {
      await tester.tap(find.text('Lock it in'));
      certaintyReads++;
      await settle(tester);

      if (find.text('Keep investigating').evaluate().isNotEmpty) {
        await tester.tap(find.text('Keep investigating'));
        await settle(tester);
      } else if (find.text("What's your call?").evaluate().isNotEmpty) {
        await tester.tap(find.text("What's your call?"));
        await settle(tester);
      } else {
        break;
      }
    }
    expect(certaintyReads, todayCase.clues.length + 1);

    // Verdict stage — pick the button matching the ground truth so the
    // "your call matched the evidence" path is exercised.
    expect(find.text('Your Verdict'), findsOneWidget);
    final choice = switch (todayCase.truth) {
      CaseVerdict.real => 'True',
      CaseVerdict.fake => 'Fake / Misleading',
      CaseVerdict.inconclusive => 'Not sure yet — need more evidence',
    };
    await tester.tap(find.text(choice));
    await settle(tester);

    // Case closed: the 3-state banner, the evidence recap, and the
    // certainty line are all present.
    final expectedBanner = switch (todayCase.truth) {
      CaseVerdict.real => 'Checks out — REAL',
      CaseVerdict.fake => 'FAKE / MISLEADING',
      CaseVerdict.inconclusive => 'INCONCLUSIVE — not enough evidence yet',
    };
    expect(find.text(expectedBanner), findsOneWidget);
    expect(find.text('Your call matched the evidence.'), findsOneWidget);
    expect(find.text('The evidence, recapped'), findsOneWidget);
    expect(find.text('Your certainty line'), findsOneWidget);
    // Every clue shows up in the recap with its reliability chip.
    for (final clue in todayCase.clues) {
      expect(find.text(clue.question), findsOneWidget);
      expect(
        find.text(clue.isStrongSignal ? 'Strong clue' : 'Just a hint'),
        findsWidgets,
      );
    }

    // The done button can sit below the fold on short viewports.
    await tester.scrollUntilVisible(
      find.text('Back to case files'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Back to case files'));
    await settle(tester);

    // Counters moved and Byte celebrates the solve on the main stage.
    expect(controller.state.casesSolved, 1);
    expect(controller.state.missionProgress, 1);
    expect(controller.state.phase, InvestigationPhase.celebrating);
    expect(controller.state.speechText, AppConstants.caseSolvedSpeech);

    // The celebrate beat ends on its own.
    await tester.pump(const Duration(seconds: 4));
    expect(controller.state.phase, InvestigationPhase.idle);

    await tester.pump(const Duration(seconds: 4));
    controller.dispose();
  });
}
