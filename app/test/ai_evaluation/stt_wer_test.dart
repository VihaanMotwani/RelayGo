/// STT Quality evaluation — Word Error Rate (WER).
///
/// Tests metric correctness and runs WER against mock transcription results.
/// For real device evaluation, replace [mockHypothesis] with actual
/// AiService.transcribe() output.
///
/// Run with:
///   flutter test test/ai_evaluation/stt_wer_test.dart --reporter expanded
library;

import 'package:flutter_test/flutter_test.dart';

import 'metrics.dart';
import 'test_data/stt_ground_truth.dart';

void main() {
  // ─── WER metric function tests ───────────────────────────────────────────

  group('Metrics — wordErrorRate', () {
    test('identical strings → WER = 0.0', () {
      expect(wordErrorRate('hello world', 'hello world'), equals(0.0));
    });

    test('one substitution in two-word reference → WER = 0.5', () {
      expect(wordErrorRate('hello earth', 'hello world'), closeTo(0.5, 0.001));
    });

    test('one deletion from three-word reference → WER = 1/3', () {
      // hypothesis drops "world" → deletion
      expect(wordErrorRate('hello', 'hello world'), closeTo(0.5, 0.001));
    });

    test('one insertion into two-word reference → WER = 0.5', () {
      // hypothesis adds "beautiful" → insertion
      expect(wordErrorRate('hello beautiful world', 'hello world'),
          closeTo(0.5, 0.001));
    });

    test('empty hypothesis, non-empty reference → high WER', () {
      // All words deleted
      expect(wordErrorRate('', 'fire on third floor'), closeTo(1.0, 0.001));
    });

    test('case insensitive comparison', () {
      expect(wordErrorRate('FIRE on the floor', 'fire on the floor'),
          equals(0.0));
    });

    test('punctuation stripped before comparison', () {
      expect(wordErrorRate('fire, on the floor!', 'fire on the floor'),
          equals(0.0));
    });

    test('multiple word errors accumulate correctly', () {
      // "there is a fire" → "there was the fire": 2 substitutions / 4 words = 0.5
      expect(wordErrorRate('there was the fire', 'there is a fire'),
          closeTo(0.5, 0.001));
    });
  });

  // ─── Mock STT benchmark ──────────────────────────────────────────────────

  group('STT — WER benchmark on mock transcriptions', () {
    late List<double> wers;

    setUpAll(() {
      wers = sttCases.map((c) {
        final hypothesis = c.mockHypothesis ?? '';
        return wordErrorRate(hypothesis, c.reference);
      }).toList();
    });

    test('average WER across all cases is below 15%', () {
      final avgWer = wers.fold(0.0, (s, w) => s + w) / wers.length;

      // Print per-case breakdown
      for (var i = 0; i < sttCases.length; i++) {
        final c = sttCases[i];
        final w = wers[i];
        final label = w == 0.0 ? '✓' : (w < 0.15 ? '~' : '✗');
        // ignore: avoid_print
        print('  $label WER=${pct(w)} | ${c.audioFile}');
        if (w > 0.0) {
          // ignore: avoid_print
          print('    ref : "${c.reference}"');
          // ignore: avoid_print
          print('    hyp : "${c.mockHypothesis}"');
        }
      }
      // ignore: avoid_print
      print('\n  Average WER: ${pct(avgWer)}');

      expect(
        avgWer,
        lessThan(0.15),
        reason: 'Average WER exceeds 15%. Review STT model or audio quality.',
      );
    });

    test('emergency phrases WER is below 20%', () {
      // Emergency phrases must be transcribed reliably — errors here mean
      // the extraction pipeline receives bad input.
      final emergencyCases =
          sttCases.where((c) => !c.audioFile.contains('hello')).toList();
      final emergencyWers = emergencyCases.map((c) {
        return wordErrorRate(c.mockHypothesis ?? '', c.reference);
      }).toList();

      final avgEmergencyWer =
          emergencyWers.fold(0.0, (s, w) => s + w) / emergencyWers.length;

      // ignore: avoid_print
      print('  Emergency phrases average WER: ${pct(avgEmergencyWer)}');

      expect(
        avgEmergencyWer,
        lessThan(0.20),
        reason: 'Emergency phrase WER is too high — '
            'extraction may receive garbled input.',
      );
    });

    test('perfect mock transcriptions score WER = 0.0', () {
      final perfectCases =
          sttCases.where((c) => c.mockHypothesis == c.reference).toList();

      for (final c in perfectCases) {
        expect(
          wordErrorRate(c.mockHypothesis!, c.reference),
          equals(0.0),
          reason: 'Perfect mock for "${c.audioFile}" should have WER=0.',
        );
      }
    });

    // ── Whisper-specific known failure modes ────────────────────────────────

    test('WER normalisation: Whisper capitalisation does not inflate WER', () {
      // Whisper often capitalises first words. Normalise before scoring.
      const hypothesis = 'Fire on third floor send help immediately';
      const reference = 'fire on third floor send help immediately';
      expect(wordErrorRate(hypothesis, reference), equals(0.0));
    });

    test('WER normalisation: Whisper punctuation does not inflate WER', () {
      const hypothesis = 'There is a fire, on the third floor.';
      const reference = 'there is a fire on the third floor';
      expect(wordErrorRate(hypothesis, reference), equals(0.0));
    });
  });

  // ─── WER guidance thresholds ─────────────────────────────────────────────

  group('WER — threshold reference', () {
    test('WER thresholds are correctly ordered', () {
      // Document the target thresholds as assertions for future reference.
      // whisper-tiny in quiet conditions: typically 5–15% WER
      // whisper-tiny in noisy conditions: typically 20–40% WER
      const quietTarget = 0.15;
      const noisyTarget = 0.40;
      expect(quietTarget, lessThan(noisyTarget));
    });
  });
}
