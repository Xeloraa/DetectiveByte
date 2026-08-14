import 'package:flutter/material.dart';

import '../models/picture_case.dart';

/// Small bundled set of picture-judgment cases. Fictional/generic scenarios
/// on purpose — the mechanic (learning to check sourcing, timing, and
/// corroboration before trusting a caption) matters more than any specific
/// real-world image, and avoids ever needing to state a real claim is fake.
abstract final class PictureCaseBank {
  /// Deterministic "today's case" — same case all day if reopened, cycles
  /// day to day, no network/random-seed dependency.
  static PictureCase caseForToday() {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    return cases[dayOfYear % cases.length];
  }

  static const List<PictureCase> cases = [
    PictureCase(
      id: 'crowd-protest',
      caption: '"MASSIVE protest happening downtown RIGHT NOW!! 😱"',
      placeholderEmoji: '👥',
      placeholderColor: Color(0xFF5B8DEF),
      zoomOutReveal:
          'Looking closer, the crop was hiding something: string lights, a '
          'stage, and a food truck at the edge of the frame.',
      isReal: false,
      clues: [
        CaseClue(
          question: 'Who posted this?',
          reveal:
              'An account with no other posts, made this week — no history '
              'of ever being downtown before.',
          isStrongSignal: true,
        ),
        CaseClue(
          question: 'When was this photo actually taken?',
          reveal:
              'The same photo shows up in a search from over a year ago — '
              'it\'s from a summer concert, not today.',
          isStrongSignal: true,
        ),
      ],
      verdictExplanation:
          'The photo is real — it\'s just from the wrong day, the wrong '
          'event, and re-posted with a caption that has nothing to do with '
          'it.',
      lessonLine:
          'A real photo can still tell a fake story if it\'s dropped into '
          'the wrong caption.',
    ),
    PictureCase(
      id: 'park-cleanup',
      caption:
          '"Our class picked up 40 bags of trash at Riverbend Park this '
          'Saturday!"',
      placeholderEmoji: '🧹',
      placeholderColor: Color(0xFF4CAF6A),
      zoomOutReveal:
          'Zooming out, there\'s a school banner in the background and a '
          'stack of labeled trash bags lined up for counting.',
      isReal: true,
      clues: [
        CaseClue(
          question: 'Who posted this?',
          reveal:
              'The school\'s own account, which regularly posts about class '
              'projects with real names and dates.',
          isStrongSignal: true,
        ),
        CaseClue(
          question: 'Is anyone else reporting it?',
          reveal:
              'The local park department shared the same event with extra '
              'photos from a different angle.',
          isStrongSignal: true,
        ),
      ],
      verdictExplanation:
          'This one checks out — a known source, matching details from a '
          'second independent source, nothing hidden by the crop.',
      lessonLine:
          'Ordinary-looking posts deserve the same quick check as '
          'wild ones — this time, it held up.',
    ),
    PictureCase(
      id: 'giant-shadow',
      caption:
          '"Scientists baffled by giant shadow spotted over the lake at '
          'sunset 👀"',
      placeholderEmoji: '🌫️',
      placeholderColor: Color(0xFF9C6ADE),
      zoomOutReveal:
          'Looking closer, the "shadow" lines up exactly with a boat mast '
          'just out of frame, stretched long by the low sun.',
      isReal: false,
      clues: [
        CaseClue(
          question: 'Is the lighting and shadow consistent?',
          reveal:
              'The shadow bends in a direction the sunset angle can\'t '
              'actually produce — a sign of an edited-in shape.',
          isStrongSignal: true,
        ),
        CaseClue(
          question: 'Is anyone else reporting it?',
          reveal:
              'No news, park ranger, or weather account near the lake '
              'mentions anything unusual that day.',
          isStrongSignal: true,
        ),
      ],
      verdictExplanation:
          'The "mystery" has a simple, boring explanation — ordinary boat, '
          'long shadow, dramatic caption.',
      lessonLine:
          'The spookier or more amazing a photo looks, the more it\'s '
          'worth a second check before believing it.',
    ),
  ];
}
