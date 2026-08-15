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

  static const _defaultPrompt =
      'Analyze this image like a detective. Is it real or AI-generated? '
      'Point out specific visual clues a curious kid could check for '
      'themselves, and end with one factual tip.';

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
