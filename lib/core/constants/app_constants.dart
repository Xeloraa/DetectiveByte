/// App-wide constants for Detective Byte companion.
abstract final class AppConstants {
  static const double companionWidth = 184;
  static const double companionHeight = 230;

  static const Duration speechDuration = Duration(seconds: 3);
  static const Duration tapScaleDuration = Duration(milliseconds: 250);
  static const Duration idleMinDelay = Duration(seconds: 4);
  static const Duration idleMaxDelay = Duration(seconds: 10);
  static const Duration idleActionDuration = Duration(milliseconds: 2400);
  static const Duration analyzeDuration = Duration(milliseconds: 3200);
  static const Duration missionCompleteHold = Duration(seconds: 3);

  static const double tapScale = 1.08;
  static const double defaultPositionX = 0.42;
  static const double defaultPositionY = 0.38;
  static const double defaultTransparency = 0.80;

  static const String welcomeSpeech =
      "Hey! I'm Byte. Let's investigate this together!";

  static const List<String> tapDialogue = [
    "Let's investigate this!",
    'Hmm… something feels off.',
    'Interesting…',
    'I wonder what clues we’re missing.',
    'Let’s check the full context.',
  ];

  static const String analyzingSpeech = 'Looking for clues…';
  static const String analyzingSpeechNoLink = 'Hmm, no link to check yet…';
  static const String missionCompleteSpeech = 'Mission completed!';
  static const String todaysMission =
      'Is this TikTok video showing the full context?';
  static const String noLinkHint =
      'Copy a TikTok, YouTube, or Reels link, then tap me to investigate it!';

  static const String storageKeyPositionX = 'companion_position_x';
  static const String storageKeyPositionY = 'companion_position_y';
  static const String storageKeyEnabled = 'companion_enabled';
  static const String storageKeyIdleAnimations = 'companion_idle_animations';
  static const String storageKeyStartWithSystem = 'companion_start_with_system';
  static const String storageKeyTransparency = 'companion_transparency';
  static const String storageKeyCasesSolved = 'companion_cases_solved';
  static const String storageKeyMissionDone = 'companion_mission_done_today';
  static const String storageKeyMissionDay = 'companion_mission_day';
  static const String storageKeyHasSeenOnboarding = 'has_seen_onboarding';
}
