# Detective Byte — Agent Handoff

Written 2026-08-15 for whichever agent picks this project up next (originally
handed from Claude Code to OpenCode). Read this before touching anything —
several things in here look like they'd be easy one-line fixes and are not.

## What this project is

**Detective Byte** is a Windows desktop app (Flutter) built for a UNESCO
hackathon: a media-literacy tool for kids. A fox detective character
("Byte") lives on the user's desktop and helps a child investigate whether
something they saw online is real, fake, or missing context — either a
video link (existing flow) or a still image with a caption (flow just
added). The product framing throughout is "here's what that tells us,"
never "you got it wrong" — the app is deliberately not punitive.

Repo root: `c:\Users\vivi\Desktop\UNESCO Detective Byte V.2`
Remote: `https://github.com/Xeloraa/DetectiveByte.git`, branch `main`.
Everything described here is committed and pushed as of commit `310903d`.

## How to build and run

```
flutter build windows --release
build\windows\x64\runner\Release\detective_byte.exe
```

Dev loop: `flutter run -d windows` works normally (no `--overlay` flag —
see "Overlay mode" below, it's mostly vestigial now).

`flutter analyze` is clean (0 issues). `flutter test` has **3 pre-existing
failures that are not your fault** — see "Known failing tests" below.
Don't spend time on those unless asked.

## Current status: what actually works

- Normal windowed app: background image, brand header, Byte, the three
  top-right panels (Status/Mission/Journal), settings sheet. Confirmed
  rendering and interactive.
- Byte idle animations (look around, read notebook, thinking, polish
  magnifying glass, adjust hat, stretch, blink) — all confirmed non-janky
  after two rounds of bug fixes this session (see "Fixed bugs" below).
- Video investigation flow (tap Byte -> clipboard link lookup -> analyze
  animation -> mission complete): pre-existing, untouched this session,
  presumed still working.
- **New: picture-judgment investigation** (tap "Today's Mission" card):
  briefing -> "look closer" reveal -> certainty dial -> clue -> repeat ->
  verdict -> case-closed with confidence line + lesson. Confirmed: opens
  correctly, renders correctly, doesn't crash, state-machine logic
  reviewed carefully. **Not fully click-tested end-to-end** — see
  "Unverified / next steps."
- Settings sheet: enable/disable toggle, idle animations toggle,
  transparency slider, start-with-system toggle.
- Minimize/restore: now **plain default Windows behavior** (minimizes to
  taskbar, click to restore). This was a deliberate revert — read
  "The minimize saga" before touching this.
- Toggling Byte off (the switch in the status card or settings) now
  **quits the whole app**, not just hides Byte. This was an explicit user
  request this session, not a bug.
- Local storage (position, enabled state, transparency, cases solved,
  daily mission progress, onboarding-seen flag) persists to
  `%APPDATA%\detective_byte\settings.json` and is crash-proof (a failed
  write no longer takes the app down — falls back to in-memory only).
- Browser-extension bridge: a loopback HTTP server on port 8791
  (`lib/services/local_bridge_server_io.dart`) that a browser extension
  POSTs a video URL to, so investigation can start the instant the user
  presses play instead of requiring a clipboard copy. No-ops silently if
  the port's taken (another instance already running).

## Architecture

```
lib/
  main.dart                      - entry point, DetectiveByteApp widget, error-catching setup
  screens/companion_screen.dart  - the one screen; Stack of companion + panels + investigation overlay
  companion/
    controllers/companion_controller.dart  - THE central state machine (ChangeNotifier)
    models/                       - CompanionState, CompanionPosition, IdleAction, InvestigationPhase
    animations/idle_animation_controller.dart - timer-driven idle action scheduler
    widgets/
      companion_widget.dart       - draggable Byte, tap-to-investigate, positions everything
      detective_byte_character.dart - BytePose model + sprite selection + breathing animation
      investigation_overlay.dart  - video-flow analyze/complete cards
      overlay_panels.dart         - top-right Status/Mission/Journal cards
      speech_bubble.dart          - Byte's floating dialogue bubble
  investigation/                  - NEW this session, the picture-judgment feature
    models/picture_case.dart      - PictureCase, CaseClue data classes
    data/picture_case_bank.dart   - 3 bundled fictional cases + caseForToday()
    controllers/picture_case_controller.dart - stage state machine for one case
    widgets/picture_case_dialog.dart - the multi-step modal UI
  future/investigation/           - UNUSED scaffolding (InvestigationModule interface,
                                     InvestigationEvent enum) - was seemingly meant for
                                     pluggable investigation types. Nothing implements it.
                                     The new picture feature does NOT use this - it's a
                                     simpler, self-contained flow instead. Worth revisiting
                                     if a third investigation type gets added.
  services/
    desktop_overlay.dart          - bridge to the native window (see below)
    local_bridge_server*.dart     - browser-extension HTTP bridge (io/web split)
    video_lookup_service.dart     - oEmbed lookups for YouTube/TikTok/Instagram
    overlay_hit_region.dart       - collects widget bounding boxes to report to native
                                     for click-through hit-testing
    storage/                      - LocalStorageService + StorageBackend (io/web split,
                                     web backend exists but this is a Windows-only app in
                                     practice)
  settings/settings_sheet.dart    - dialog with all the toggles/slider
  onboarding/onboarding_screen.dart - first-launch carousel (has a pre-existing bug, see below)

windows/runner/                   - native Win32 host
  main.cpp                        - wWinMain, parses --overlay flag, creates the window
  win32_window.h/.cpp              - Win32Window base class: chrome switching, click-through
                                     polling, window messages
  flutter_window.h/.cpp            - FlutterWindow : Win32Window, owns the Flutter engine,
                                     the "detective_byte/desktop_overlay" MethodChannel
```

### State flow (video/companion side)

`CompanionController` (ChangeNotifier) owns `CompanionState` (immutable,
`copyWith`). It's constructed once in `main.dart`, handed down through
`DetectiveByteApp` -> `CompanionScreen` -> all the widgets, which all listen
via `ListenableBuilder`/`AnimatedBuilder`. There's no other state
management library - no Provider/Riverpod/Bloc, just plain
`ChangeNotifier` + manual listener wiring. Keep it that way; don't
introduce a state management dependency without a strong reason.

### The native window layer (important, read carefully)

`Win32Window` supports two "chromes":
- **Normal**: `WS_OVERLAPPEDWINDOW`, opaque, decorated - what you get by
  default (`flutter run` / launching the exe with no args).
- **Overlay**: `WS_POPUP` + `WS_EX_LAYERED` + `WS_EX_TOPMOST` +
  `WS_EX_APPWINDOW`, per-pixel-transparent via `DwmExtendFrameIntoClientArea`,
  covers the monitor work area, and polls the cursor position on a 16ms
  timer to toggle `WS_EX_TRANSPARENT` for click-through (see
  `UpdateClickThroughState()` in `win32_window.cpp`) so clicks pass through
  to whatever's beneath except over Byte/the panels.

`SwitchToOverlayChrome()` / `SwitchToNormalChrome()` can flip between these
at runtime and are still fully functional - they're just **not currently
wired to minimize** (see below). They're still used by the `--overlay`
launch flag (`flutter run -d windows -- --overlay`) for standalone
dev-testing of the overlay chrome.

Dart learns the current chrome via `DesktopOverlay` (`services/desktop_overlay.dart`):
`DesktopOverlay.modeNotifier` is a `ValueNotifier<bool>` kept in sync with
native via the `detective_byte/desktop_overlay` MethodChannel - native can
push `chromeModeChanged` calls to Dart at any time (see
`FlutterWindow::OnChromeModeChanged` in `flutter_window.cpp`), so the UI
reacts live if chrome ever changes after startup, not just at launch. This
machinery is intact and working - it's just currently only exercised by
the dev-only `--overlay` flag, not by anything a real user does.

### The minimize saga - DO NOT re-attempt custom minimize-to-overlay without reading this

Earlier this session, minimize was wired to intercept `WM_SYSCOMMAND`/
`SC_MINIMIZE` and switch to overlay chrome instead of actually minimizing,
so Byte would keep floating on the desktop instead of vanishing to the
taskbar. This went through **five** rounds of bugs:

1. Click-through never worked reliably via the initial `WM_NCHITTEST`
   subclassing approach -> reworked to poll-and-toggle `WS_EX_TRANSPARENT`
   (this part is fine and still in place).
2. The chrome-switch itself crashed (`STATUS_FATAL_APP_EXIT`) - fixed by
   deferring `ApplyOverlayChrome()`'s show/position calls relative to when
   the Flutter D3D surface exists.
3. A blink-vs-pose-crossfade bug made Byte visibly "shake" - actually two
   separate bugs (see "Fixed bugs" below), unrelated to minimize but found
   during this work.
4. Taskbar-click-to-minimize doesn't route through `WM_SYSCOMMAND` the
   same way title-bar-click does, so a `WM_SIZE`/`SIZE_MINIMIZED` fallback
   was added - which itself raced the in-progress minimize and left the
   window stuck genuinely iconic with **no taskbar icon** (`WS_EX_TOOLWINDOW`
   was hiding it) and no way back. Fixed the taskbar icon
   (`WS_EX_APPWINDOW` instead), fixed the race (defer via posted message).
5. Even after all that, the user still couldn't reliably get back to the
   full window after minimizing (double-tap-to-restore was never fully
   verified - screen automation in this dev environment is unreliable, see
   below). At this point minimize was **reverted entirely** to plain OS
   default behavior (commit `c6a8ac8`). Zero custom code in the minimize
   path now.

**If asked to bring back "Byte floats when minimized"**: the
`SwitchToOverlayChrome`/`SwitchToNormalChrome` machinery is still there and
works. What's missing is a *reliable* way back to the normal window - the
double-tap-on-Byte gesture is wired
(`companion_widget.dart`'s `onDoubleTap: DesktopOverlay.restoreNormalWindow`)
but was never confirmed working by a real click (only by direct message
injection, which isn't the same code path as Flutter's gesture arena). If
you re-attempt this, get the user to physically test double-tap and the
taskbar-icon-click path before declaring it done - don't trust automated
screenshots alone here (see "Dev environment quirks").

## Fixed bugs this session (context in case symptoms resurface)

- **Idle-pose flicker**: asset selection was inferring the current pose
  from continuous sine-driven values (`hatAdjust`, `stretchAmount` etc.)
  crossing zero mid-animation, causing the sprite to flicker between idle
  and the active pose. Fixed by carrying the actual `IdleAction` through
  `BytePose.idleActionKind` and switching on that directly
  (`detective_byte_character.dart`).
- **Blink-induced "shake"**: blinking swapped Byte's whole sprite through
  an `AnimatedSwitcher` 320ms crossfade, but blinks last 120ms - shorter
  than the crossfade, so it reversed an in-flight scale/fade transition on
  every blink. Fixed by making blink an un-animated, same-`ValueKey` swap
  that doesn't retrigger the switcher.
- **Real shake cause (the bigger one)**: the speech bubble lived in a
  `Column` above Byte, so every time `speechText` toggled empty/non-empty
  (constantly - every idle action, every tap) the bubble's height jumped
  0->~70px and **pushed Byte's position** with it. Fixed by moving to a
  fixed-size `Stack` with the bubble `Positioned` above Byte instead of in
  document flow (`companion_widget.dart`).
- **Storage crash on full disk**: `FileStorageBackend` had no error
  handling; a failed write threw and could kill the isolate while the
  native window stayed alive (silent "the app disappeared"). Now falls
  back to in-memory-only on any write failure
  (`storage_backend_io.dart`), plus `main.dart` has a top-level
  `runZonedGuarded` + `FlutterError.onError` net.

## Known failing tests (pre-existing, not caused this session)

`flutter test` fails 3 of the 4 tests in `test/widget_test.dart`, all
tracing to the same root cause: a `RenderFlex` overflow in
`lib/onboarding/onboarding_screen.dart:209` at the test harness's default
viewport size. **Verified pre-existing** by stashing all of this session's
changes and re-running - same 3 failures occurred on the untouched
baseline. Nobody has looked at the actual onboarding layout bug itself.
If you touch onboarding, this is a real bug worth fixing while you're in
there.

## Dev environment quirks (read before doing any visual verification)

This box's screen-capture tooling has been unreliable all session:
- `CopyFromScreen` at the app window's own rect sometimes shows a
  **different window's content** (VS Code, a browser tab) even though
  `GetWindowRect`/style queries confirm it's the right HWND - strongly
  suspected to be an artifact of a remote/virtualized display session
  where the automation's coordinate space doesn't always match what gets
  composited to the visible screen.
- A freshly-launched, never-focused window's Direct3D surface appears not
  to present frames at all (blank captures) until it receives **real**
  focus/input - `SetForegroundWindow` from an unrelated process is also
  blocked by Windows' focus-steal prevention unless preceded by a
  synthetic input event (`SendInput` with a harmless key). Once genuinely
  focused, capture becomes reliable.
- Repeated `PrintWindow(..., PW_RENDERFULLCONTENT)` calls against a window
  that has never presented a frame yet appears to have caused one genuine
  `STATUS_ACCESS_VIOLATION` crash this session (confirmed via Windows
  Event Log, not reproducible on retry with a calmer test sequence) -
  suspected ANGLE/D3D11-via-GDI-interop edge case specific to this
  environment, not a bug in app code. Don't hammer `PrintWindow`/
  `CopyFromScreen` in a tight loop against this app.
- **This machine also runs critically low on disk space repeatedly during
  this session** (down to single-digit MB free more than once, which
  broke builds and file writes outright). Check `df -h /c` (or Windows
  Storage settings) before large builds if things start failing
  mysteriously - it may not be your code.
- **Bottom line**: don't trust a single screenshot here, especially early
  after launch. Prefer non-visual verification (window style bits via
  `GetWindowLong`, `IsIconic`, process-alive checks, the persisted
  `settings.json`, Windows Event Log for crashes) as the primary signal,
  and use screenshots only after granting real focus, as a secondary
  confirmation. When in doubt, ask the user to look themselves rather than
  keep probing - blind automated clicking on the user's live, real desktop
  is risky (this session nearly interfered with an unrelated video call
  the user had open, purely by taking full-screen screenshots at the wrong
  moment).

## The new picture-judgment feature - what's solid, what's not

**Solid** (code-reviewed, logic traced by hand):
- `PictureCaseController`'s stage machine
  (`briefing -> zoomedOut -> certainty -> clue -> certainty -> clue -> certainty -> verdict -> closed`,
  3 certainty reads total for 2 clues) - no off-by-one issues found.
- `PictureCaseBank.caseForToday()` - deterministic by day-of-year, no
  network dependency.
- Wiring: tapping the Mission card
  (`overlay_panels.dart`'s `_MissionCard`, now an `InkWell`) calls
  `PictureCaseDialog.show(...)`; on completion calls
  `CompanionController.recordCaseSolved()` which feeds the *same*
  `casesSolved`/`missionProgress` counters the video flow uses. Confirmed
  via direct testing: tapping the card opens the dialog, today's case
  renders correctly (title, placeholder photo, caption, Investigate
  button).

**Not fully verified** - the later stages (`zoomedOut`, `certainty` slider
interaction, `clue` reveal, `verdict` buttons, `closed` summary) were
reviewed by reading the code, not by clicking through them, because
precise blind multi-click sequences against unpredictable dialog layout
proved unreliable in this environment (one attempt missed the button and
hit the dialog's dismiss barrier instead - not a bug, just imprecise
automation). **Ask the user to click through one full case** (tap "Today's
Mission" and go all the way to "Back to case files") before assuming this
feature is 100% done, or do it yourself if you have reliable mouse/screen
tooling.

Other loose ends on this feature:
- `AppConstants.todaysMission` (`"Is this TikTok video showing the full
  context?"`) is the static description text shown on the Mission card
  regardless of which mission type it opens - now stale/misleading since
  the card opens picture cases too. Should probably become dynamic or get
  reworded.
- The "photo" in each case is a colored placeholder + emoji
  (`_PhotoPlaceholder` in `picture_case_dialog.dart`), not a real bundled
  image, by design - see `PictureCase` docstring. Swapping in real curated
  images later just means changing `PictureCase.placeholderEmoji`/
  `placeholderColor` to an asset path and updating `_PhotoPlaceholder`;
  the investigation mechanic doesn't need to change.
- Only 3 cases exist (`picture_case_bank.dart`). `caseForToday()` cycles
  through them by day-of-year, so the same 3 cases repeat every 3 days -
  fine for a hackathon demo, not enough content for real daily use.
- No "skip"/"close early" affordance - the dialog can only be dismissed by
  tapping the barrier (loses progress, no confirmation) or completing it.
  Might be worth a close button depending on how it's meant to be used.

## Things you must NOT break

1. **Don't re-add custom minimize interception** without getting a real,
   user-confirmed working restore-path first (see "The minimize saga").
   The current plain-OS-behavior state is deliberately simple and known-good.
2. **Don't move the speech bubble back into flow layout above Byte** - the
   `Stack`/`Positioned` structure in `companion_widget.dart` is load-bearing
   for the shake fix. If refactoring that widget, keep Byte's position
   independent of the bubble's presence/size.
3. **Don't reintroduce blink as an `AnimatedSwitcher`-keyed asset change**
   in `detective_byte_character.dart` - keep blink as the same-key,
   instant swap (see `isBlinking`/`displayAsset` in that file).
4. **Don't remove the `runZonedGuarded`/`FlutterError.onError` net in
   `main.dart`** or the try/catch in `storage_backend_io.dart` - these
   exist specifically because a failed disk write used to silently kill
   the app.
5. **Don't add a state management dependency** (Provider/Riverpod/Bloc/etc.)
   without discussing it first - the whole app is plain `ChangeNotifier`
   by design, consistently.
6. **Don't break the `--overlay` dev flag** - even though it's not used by
   the default user flow anymore, it's the only way to manually test the
   overlay chrome, and the picture-case dialog's `show()` method already
   has overlay-mode-aware hit-region handling that depends on
   `DesktopOverlay.isOverlayMode` being accurate.
7. **Never commit without running `flutter analyze`** (must stay at 0
   issues) and `flutter test` (compare failures against the 3 known
   pre-existing ones - if a 4th appears, you broke something).

## Session addendum — 2026-08-15 (OpenCode / claude-fable-5)

Polish session on top of commit `76ebb68`. All changes below are tested:
`flutter analyze` = 0 issues, `flutter test` = 7/7 pass (the 3 pre-existing
onboarding failures are FIXED — see below).

**What changed:**
- **Autonomous wandering** (`IdleAction.wander`): Byte now picks a spot and
  trots over to it (~2/7 of idle actions, 2.8–4.6s, eased path at ~60fps —
  the idle scheduler ticks at 16ms during walks only). Walk visuals are
  procedural (hop + sway over the idle sprite; no walk sprite exists and no
  directional flip — sprite facing couldn't be verified). Targets exclude
  the top-right panel stack and leave speech-bubble headroom; position is
  persisted on walk end AND on mid-walk interruption. Drag pauses wandering
  (`onDragStart`/`onDragEnd`); `updateViewportSize` is fed by
  `companion_widget.dart`. Test seam: `idleActionPool` ctor param.
- **Video flow verdict**: `_MissionCompleteCard` → `_CaseReportCard` in
  `investigation_overlay.dart` — verdict pill (FOUND / CAN'T TELL YET) +
  evidence lines. Byte never declares a video fake (oEmbed can't prove
  that); the framing is "real video ≠ true story". `missionCompleteHold`
  bumped 3s → 6.5s so it's readable; analyze card now narrates steps.
- **Picture flow 3-state verdict**: `CaseVerdict` enum (real/fake/
  inconclusive) replaced `bool isReal` in `PictureCase`; verdict buttons
  gained "Not sure yet"; `_CaseClosed` got a color-coded verdict banner +
  evidence recap with "Strong clue"/"Just a hint" chips. 4th case
  (`purple-bridge`) is deliberately inconclusive.
- **Byte participates in the case dialog**: `_ByteCommentary` (mini Byte +
  per-stage line + close button) pinned inside the dialog. `recordCaseSolved`
  now triggers a celebrate beat (`InvestigationPhase.celebrating` — new enum
  value; deliberately NOT rendered by `InvestigationOverlay`). Wander freezes
  while the dialog is open (`onCaseFlowOpened/Closed`).
- **Onboarding overflow FIXED** (`onboarding_screen.dart`): Byte scaled to
  0.72 + tighter spacing → fits 600px viewports; also fixed two stale test
  assertions in `widget_test.dart` ('3' → '0' cases; pumpAndSettle → fixed
  pumps, because the breathe animation never settles).
- Loose ends closed: `AppConstants.todaysMission` reworded for picture
  cases; settings idle subtitle updated.
- New tests: `test/companion_life_test.dart` (wander + persistence, drag
  freeze/resume, full end-to-end picture case click-through — the flow the
  previous session never fully click-tested).

**Still true from the original handoff:** everything under "Things you must
NOT break" is untouched (minimize, speech-bubble Stack, blink swap, error
nets, no state-mgmt deps, `--overlay` flag). The user shared an image with a
design idea this session that couldn't be read (no image-input support) —
if it resurfaces, ask them to describe it in text. Visual (on-screen)
verification of the new animations still hasn't happened in this
environment; ask the user to watch Byte for a minute and click one case.

## Suggested next steps, roughly in priority order

1. Get the user (or yourself, carefully) to click through one full picture
   case end-to-end and confirm the certainty dial / clue / verdict /
   closed screens all look and behave right.
2. Fix the pre-existing onboarding `RenderFlex` overflow
   (`onboarding_screen.dart:209`) - cheap win, also unblocks the 3 failing
   tests.
3. Decide what to do about `AppConstants.todaysMission`'s stale text now
   that the Mission card opens two different flow types.
4. If real image assets become available, wire them into `PictureCase` /
   `_PhotoPlaceholder`.
5. More picture cases - 3 is thin for daily replay.
6. Only if explicitly asked: revisit floating-Byte-on-minimize, with a
   real (not simulated) restore-path verification before calling it done.
