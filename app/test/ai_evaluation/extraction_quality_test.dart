/// Extraction Quality evaluation.
///
/// Runs the ground-truth emergency cases through the MOCK extraction pipeline
/// and computes:
///   - Type accuracy
///   - Urgency MAE (mean absolute error)
///   - Hazards F1
///
/// IMPORTANT: This file tests the METRIC FUNCTIONS and the IntentFilter's
/// ability to correctly classify emergency inputs. It does NOT run real LLM
/// inference (that requires a device with the model downloaded).
///
/// To evaluate real LLM extraction quality, use the ExtractionBenchmark
/// harness in tool_benchmark.dart (device test).
///
/// Run with:
///   flutter test test/ai_evaluation/extraction_quality_test.dart --reporter expanded
library;

import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/ai/intent_filter.dart';
import 'metrics.dart';
import 'test_data/extraction_cases.dart';

void main() {
  // ─── Metric function unit tests ──────────────────────────────────────────

  group('Metrics — typeAccuracy', () {
    test('perfect predictions = 1.0', () {
      final pairs = [
        (predicted: 'fire', expected: 'fire'),
        (predicted: 'medical', expected: 'medical'),
      ];
      expect(typeAccuracy(pairs), equals(1.0));
    });

    test('no correct predictions = 0.0', () {
      final pairs = [
        (predicted: 'fire', expected: 'medical'),
        (predicted: 'flood', expected: 'fire'),
      ];
      expect(typeAccuracy(pairs), equals(0.0));
    });

    test('half correct = 0.5', () {
      final pairs = [
        (predicted: 'fire', expected: 'fire'),
        (predicted: 'flood', expected: 'medical'),
      ];
      expect(typeAccuracy(pairs), equals(0.5));
    });

    test('case insensitive', () {
      final pairs = [(predicted: 'FIRE', expected: 'fire')];
      expect(typeAccuracy(pairs), equals(1.0));
    });

    test('empty list = 0.0', () {
      expect(typeAccuracy([]), equals(0.0));
    });
  });

  group('Metrics — urgencyMAE', () {
    test('perfect predictions = 0.0', () {
      final pairs = [
        (predicted: 5, expected: 5),
        (predicted: 3, expected: 3),
      ];
      expect(urgencyMAE(pairs), equals(0.0));
    });

    test('one level off average = 1.0', () {
      final pairs = [
        (predicted: 4, expected: 5),
        (predicted: 2, expected: 3),
      ];
      expect(urgencyMAE(pairs), equals(1.0));
    });

    test('symmetry: over and under predict cancel in MAE', () {
      final pairs = [
        (predicted: 3, expected: 5), // error = 2
        (predicted: 5, expected: 3), // error = 2
      ];
      expect(urgencyMAE(pairs), equals(2.0));
    });

    test('empty list = 0.0', () {
      expect(urgencyMAE([]), equals(0.0));
    });
  });

  group('Metrics — hazardsF1', () {
    test('perfect match = 1.0', () {
      final pairs = [
        (
          predicted: {'fire_spread', 'gas_leak'},
          expected: {'fire_spread', 'gas_leak'},
        ),
      ];
      expect(hazardsF1(pairs), closeTo(1.0, 0.001));
    });

    test('no overlap = 0.0', () {
      final pairs = [
        (predicted: {'gas_leak'}, expected: {'fire_spread'}),
      ];
      expect(hazardsF1(pairs), equals(0.0));
    });

    test('partial overlap', () {
      // predicted: {A, B}, expected: {A, C}
      // TP=1, FP=1, FN=1 → precision=0.5, recall=0.5 → F1=0.5
      final pairs = [
        (
          predicted: {'gas_leak', 'flooding'},
          expected: {'gas_leak', 'fire_spread'},
        ),
      ];
      expect(hazardsF1(pairs), closeTo(0.5, 0.001));
    });

    test('empty predicted, non-empty expected = 0.0', () {
      final pairs = [
        (predicted: <String>{}, expected: {'fire_spread'}),
      ];
      expect(hazardsF1(pairs), equals(0.0));
    });

    test('empty predicted and expected = 1.0', () {
      // Both agree there are no hazards
      final pairs = [
        (predicted: <String>{}, expected: <String>{}),
      ];
      expect(hazardsF1(pairs), equals(1.0));
    });
  });

  // ─── IntentFilter on extraction cases ────────────────────────────────────

  group('IntentFilter — emergency detection rate on labeled cases', () {
    test('at least 90% of labeled emergencies are detected', () {
      final detected = extractionCases
          .where((c) => IntentFilter.isLikelyEmergency(c.input))
          .length;
      final rate = detected / extractionCases.length;

      // Print misses for easy debugging
      for (final c in extractionCases) {
        if (!IntentFilter.isLikelyEmergency(c.input)) {
          // ignore: avoid_print
          print('  MISSED [score=${IntentFilter.score(c.input).toStringAsFixed(1)}]: '
              '${c.description}');
          // ignore: avoid_print
          print('    input: "${c.input}"');
        }
      }

      // ignore: avoid_print
      print('\n  Detection rate: ${pct(rate)} ($detected/${extractionCases.length})');

      expect(
        rate,
        greaterThanOrEqualTo(0.90),
        reason: 'IntentFilter missed too many labeled emergency cases. '
            'Check keyword coverage in intent_filter.dart.',
      );
    });

    test('urgency=5 cases are always detected', () {
      final criticalCases =
          extractionCases.where((c) => c.expectedUrgency == 5).toList();

      for (final c in criticalCases) {
        expect(
          IntentFilter.isLikelyEmergency(c.input),
          isTrue,
          reason: 'Critical emergency (urgency=5) should always be detected.\n'
              'Description: ${c.description}\n'
              'Input: "${c.input}"',
        );
      }
    });
  });

  // ─── Simulate mock extraction and compute metrics ─────────────────────────
  //
  // In a real benchmark you would call AiService.chat() on each case.
  // Here we simulate with a deterministic mock that maps known inputs to
  // expected outputs, allowing metric function testing without a model.

  group('Extraction metrics — mock pipeline simulation', () {
    // Mock: perfect extraction (simulates ideal model output)
    ({String type, int urgency, Set<String> hazards}) mockExtract(
        ExtractionCase c) {
      return (
        type: c.expectedType,
        urgency: c.expectedUrgency,
        hazards: c.expectedHazards,
      );
    }

    test('mock perfect extraction scores 1.0 type accuracy', () {
      final typePairs = extractionCases
          .map((c) => (predicted: mockExtract(c).type, expected: c.expectedType))
          .toList();
      expect(typeAccuracy(typePairs), equals(1.0));
    });

    test('mock perfect extraction scores 0.0 urgency MAE', () {
      final urgencyPairs = extractionCases
          .map((c) =>
              (predicted: mockExtract(c).urgency, expected: c.expectedUrgency))
          .toList();
      expect(urgencyMAE(urgencyPairs), equals(0.0));
    });

    test('mock perfect extraction scores 1.0 hazards F1', () {
      final hazardPairs = extractionCases
          .map((c) => (
                predicted: mockExtract(c).hazards,
                expected: c.expectedHazards,
              ))
          .toList();
      expect(hazardsF1(hazardPairs), equals(1.0));
    });

    // Simulate off-by-one urgency (typical small model error)
    test('off-by-one urgency predictions have MAE <= 1.0', () {
      final urgencyPairs = extractionCases.map((c) {
        // Simulate model predicting one level lower (floor at 1)
        final predicted = (c.expectedUrgency - 1).clamp(1, 5);
        return (predicted: predicted, expected: c.expectedUrgency);
      }).toList();

      final result = urgencyMAE(urgencyPairs);
      // ignore: avoid_print
      print('  Simulated off-by-one urgency MAE: ${mae(result)}');
      expect(result, lessThanOrEqualTo(1.0));
    });
  });
}
