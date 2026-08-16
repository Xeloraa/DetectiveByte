import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thrown when the analysis backend can't be reached or returns something
/// unusable — callers show this message directly, so keep it short and
/// non-technical.
class MediaPetAnalysisException implements Exception {
  MediaPetAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client for the live "Media-Pet AI" backend — a real vision-model-backed
/// service (not bundled with the app, not something this codebase controls)
/// that looks at an arbitrary image and returns a detective-style written
/// analysis. Unlike the curated [PictureCaseBank] cases, there's no known
/// ground truth here — this is genuine analysis of whatever the user drops
/// in, not a hand-authored answer key.
abstract final class MediaPetAnalysisService {
  static const _endpoint = 'https://unesco-hackathon-v1.onrender.com/analyze';

  /// Deliberately never asks the model for a verdict ("is this real or
  /// fake") — this app's design principle (see DESIGN_RULES.md: "Byte
  /// reacts to the investigation, never to the player") is that the child
  /// reaches their own conclusion, not that Byte hands one down. This
  /// prompt keeps the model to plain observation and open questions, and
  /// explicitly bans verdict-adjacent language ("looks authentic", "makes
  /// sense") that would smuggle a judgment in through the back door.
  static const _defaultPrompt =
      'You are Detective Byte, a friendly detective character looking at '
      'an image together with a curious kid (age 8-13). Use short '
      'sentences and simple, everyday words a kid that age would '
      'understand.\n\n'
      'Important rule: describe only what you can actually see in the '
      'image. Do not say or hint whether the image is real or '
      'AI-generated, and do not use words like "authentic," "looks '
      'real," "looks fake," "makes sense," or anything else that judges '
      'whether it can be trusted. That call is for the kid to make, not '
      'you.\n\n'
      'Structure the answer with exactly these section headers, in this '
      'order:\n'
      '1. What I noticed: plainly describe what is in the image — '
      'people, objects, colors, setting, lighting. Just what is '
      'visible.\n'
      '2. Detective Clues: 3-4 specific visible details (an edge, a '
      'shadow, a texture, a reflection, a hand, text) the kid could look '
      'at themselves. Describe each one neutrally, without saying what '
      'it proves.\n'
      '3. Think Like a Detective: 2-3 open questions that help the kid '
      'look closer and reason for themselves, without hinting at an '
      'answer.\n'
      '4. Detective Tip: one short, general media-literacy tip (like how '
      'to reverse-image-search or why checking the source matters) — '
      'general advice, not a claim about this particular image.\n\n'
      'End with exactly one closing question, on its own line, asking '
      'the kid directly what they think: is it real, AI-made, or are '
      'they not sure yet?';

  /// Uploads [imageBytes] and returns the backend's written analysis.
  /// Throws [MediaPetAnalysisException] on any failure — network, timeout,
  /// bad status, or an unexpected response shape.
  static Future<String> analyze(
    Uint8List imageBytes, {
    String filename = 'dropped_image.jpg',
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..fields['prompt'] = _defaultPrompt
      ..files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );

    final http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 45));
    } catch (_) {
      throw MediaPetAnalysisException(
        "Couldn't reach the analysis service — check your connection and "
        'try again.',
      );
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw MediaPetAnalysisException(
        'The analysis service had trouble with that image '
        '(HTTP ${response.statusCode}). Try a different one?',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw MediaPetAnalysisException(
        'Got an answer back that made no sense — try again?',
      );
    }

    final analysis = decoded['analysis'];
    if (analysis is! String || analysis.trim().isEmpty) {
      throw MediaPetAnalysisException(
        "The analysis came back empty — let's try again.",
      );
    }
    return analysis.trim();
  }
}
