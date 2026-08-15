import 'dart:io';

import 'package:detective_byte/services/media_pet_analysis_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Hits the real Media-Pet AI backend (unesco-hackathon-v1.onrender.com) —
// deliberately not mocked, since the whole point is verifying the actual
// live network + parsing pipeline works end to end, not just that the
// request-building code compiles. Plain test(), not testWidgets(): the
// widget-test fake-async clock doesn't advance in step with real network
// I/O, so a real HTTP round trip inside testWidgets can hang indefinitely
// even though nothing is actually broken.
void main() {
  test(
    'MediaPetAnalysisService.analyze returns a real written analysis',
    () async {
      final bytes = await File(
        'assets/byte/cases/volcanic_lightning.jpg',
      ).readAsBytes();

      final analysis = await MediaPetAnalysisService.analyze(bytes);

      expect(analysis, isNotEmpty);
      // Loose content check — the exact wording isn't ours to pin down (it's
      // a live model response), just that it's a real, substantive analysis
      // rather than an empty or garbage string.
      expect(analysis.length, greaterThan(100));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
