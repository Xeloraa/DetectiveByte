import 'package:flutter/material.dart';

import '../models/picture_case.dart';

/// Small bundled set of picture-judgment cases.
///
/// Three are grounded in real, extremely well-documented "fooled the whole
/// internet" moments — chosen because their ground truth is settled and
/// widely reported by fact-checkers and news organizations (not because
/// they're "trending now"; this bank has no live data source, on purpose —
/// a hackathon demo shouldn't depend on a network call or a live scrape of
/// real people's images working on stage). The fourth stays fictional: it
/// teaches "not enough evidence yet," which only works if the case is
/// deliberately unresolved, and inventing a fake unresolved real-world
/// story would be dishonest in a way a fictional one isn't.
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
    // Real event: an AI-generated image of Pope Francis in a white puffer
    // coat (March 2023) spread worldwide and fooled huge numbers of people
    // before it was traced to an AI-art account. One of the most widely
    // cited "AI fooled the internet" case studies in media-literacy
    // education — chosen for exactly that reason.
    PictureCase(
      id: 'ai-pope-jacket',
      caption:
          '"Pope Francis just stepped out in the DRIPPIEST white puffer '
          'coat ever 🔥🧥"',
      placeholderEmoji: '🧥',
      placeholderColor: Color(0xFFE8E0D0),
      zoomOutReveal:
          'Looking closer, the hand holding his coffee cup blurs strangely '
          'into the fingers, and his crucifix chain doesn\'t quite connect '
          'to anything.',
      truth: CaseVerdict.fake,
      clues: [
        CaseClue(
          question: 'Who posted this first?',
          reveal:
              'An account that only ever shares AI-art experiments — not a '
              'single real news photo anywhere in its history.',
          isStrongSignal: true,
        ),
        CaseClue(
          question: 'Did any real news outlet confirm it?',
          reveal:
              'None. No wire service, no photographer credit, no official '
              'account — just people resharing it, over and over.',
          isStrongSignal: true,
        ),
      ],
      verdictExplanation:
          'This photo never existed — it was made by an AI image tool and '
          'looked convincing enough to fool millions of people, including '
          'some who really should have checked first.',
      lessonLine:
          'This is one of the most famous "AI fooled the whole internet" '
          'moments ever — a photo "looking right" isn\'t the same as it '
          'being real.',
    ),
    // Real event: an AI-generated image of an explosion near a government
    // building (May 2023) spread on social media and briefly moved real
    // stock markets before it was debunked within the hour.
    PictureCase(
      id: 'ai-explosion',
      caption:
          '"BREAKING: huge explosion just rocked a government building 💥"',
      placeholderEmoji: '💥',
      placeholderColor: Color(0xFFE8756B),
      zoomOutReveal:
          'Looking closer, the fence in front of the building bends in a '
          'way real metal doesn\'t, and the smoke plume casts no shadow at '
          'all.',
      truth: CaseVerdict.fake,
      clues: [
        CaseClue(
          question: 'Did any verified news account confirm it?',
          reveal:
              'No — every major outlet checked and found nothing. Local '
              'emergency services reported no such incident.',
          isStrongSignal: true,
        ),
        CaseClue(
          question: 'Where did it first appear?',
          reveal:
              'An account with a fake "verified" badge, created only weeks '
              'earlier — not a real journalist or news organization.',
          isStrongSignal: true,
        ),
      ],
      verdictExplanation:
          'This image was AI-generated. It spread so fast that it briefly '
          'moved real financial markets before anyone could confirm it —  '
          'nothing like it ever happened.',
      lessonLine:
          'A fake image doesn\'t need to fool everyone forever — it only '
          'needs a few minutes to cause real damage before the truth '
          'catches up.',
    ),
    // Real event: "volcanic lightning" (a "dirty thunderstorm") is a
    // genuine, documented phenomenon, captured independently by multiple
    // photographers during real eruptions. The "real" counterweight to the
    // two AI cases above — not everything dramatic-looking is fake.
    PictureCase(
      id: 'volcanic-lightning',
      caption:
          '"Insane photo: lightning bolts shooting out of an erupting '
          'volcano ⚡🌋"',
      placeholderEmoji: '⚡',
      placeholderColor: Color(0xFF6B4A9C),
      photoAsset: 'assets/byte/cases/volcanic_lightning.jpg',
      photoAttribution:
          'Photo: Etrhamjr, retouched by Hike395 — CC BY-SA 4.0, '
          'Wikimedia Commons',
      zoomOutReveal:
          'Looking closer, the ash cloud has real turbulence and texture — '
          'nothing about the lightning looks pasted on top.',
      truth: CaseVerdict.real,
      clues: [
        CaseClue(
          question: 'Is there a real explanation for this?',
          reveal:
              'Yes — scientists call it a "dirty thunderstorm." Volcanic ash '
              'particles rub together and build up static electricity, the '
              'same way storm clouds do.',
          isStrongSignal: true,
        ),
        CaseClue(
          question: 'Did other photographers capture it too?',
          reveal:
              'Several photographers at different angles caught the same '
              'eruption that night, with matching timestamps.',
          isStrongSignal: true,
        ),
      ],
      verdictExplanation:
          'This one\'s real — volcanic lightning is a genuine, if rare, '
          'natural phenomenon, and independent photos from that night back '
          'each other up.',
      lessonLine:
          'Sometimes the wildest-looking photo is the true one — that\'s '
          'exactly why it\'s worth checking instead of guessing.',
    ),
    // Deliberately inconclusive: no red flags, but no corroboration either.
    // Teaches that "not enough evidence yet" is a real verdict — absence
    // of proof isn't proof of fake, and picking a side anyway is the trap.
    PictureCase(
      id: 'purple-bridge',
      caption:
          '"The old bridge downtown glowed PURPLE last night!! No one '
          'knows why 😲💜"',
      placeholderEmoji: '🌉',
      placeholderColor: Color(0xFF7B68C8),
      zoomOutReveal:
          'Looking closer, the colors blend smoothly and there\'s no '
          'obvious edit mark — but one photo can\'t show how the light '
          'got there.',
      truth: CaseVerdict.inconclusive,
      clues: [
        CaseClue(
          question: 'Who posted this?',
          reveal:
              'A local account that posts town photos every week — legit '
              'history, but this is their first post about anything like '
              'this.',
          isStrongSignal: false,
        ),
        CaseClue(
          question: 'Is anyone else reporting it?',
          reveal:
              'No other posts or news yet — but it happened late at night, '
              'so maybe people just haven\'t posted. Absence of posts '
              'isn\'t proof either way.',
          isStrongSignal: false,
        ),
      ],
      verdictExplanation:
          'Nothing says it\'s edited — but nothing confirms it happened '
          'either. With only this one photo, the story can\'t be proved '
          'in any direction. Detectives call that inconclusive.',
      lessonLine:
          '"Not sure yet" is a smart, honest answer. You don\'t have to '
          'pick a side before the evidence is there.',
    ),
  ];
}
