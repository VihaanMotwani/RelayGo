/// False Alarm Rate evaluation for the intent pre-filter.
///
/// Tests that non-emergency messages are correctly NOT flagged as emergencies
/// by IntentFilter.isLikelyEmergency(). Run with:
///
///   flutter test test/ai_evaluation/false_alarm_test.dart --reporter expanded
///
/// No device or plugin needed — pure Dart.
library;

import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/ai/intent_filter.dart';
import 'metrics.dart';
import 'test_data/non_emergency_cases.dart';

void main() {
  group('IntentFilter — False Alarm Rate', () {
    late List<bool> results;

    setUpAll(() {
      results = nonEmergencyCases
          .map((c) => IntentFilter.isLikelyEmergency(c.input))
          .toList();
    });

    test('false alarm rate is below 10%', () {
      final rate = falseAlarmRate(results);

      // Print per-case breakdown for visibility
      for (var i = 0; i < nonEmergencyCases.length; i++) {
        final c = nonEmergencyCases[i];
        final fired = results[i];
        final score = IntentFilter.score(c.input);
        if (fired) {
          // ignore: avoid_print
          print('  FALSE ALARM [score=${score.toStringAsFixed(1)}]: ${c.description}');
          // ignore: avoid_print
          print('    input: "${c.input}"');
          // ignore: avoid_print
          print('    matches: ${IntentFilter.debugMatches(c.input)}');
        }
      }

      // ignore: avoid_print
      print('\n  False alarm rate: ${pct(rate)} '
          '(${results.where((t) => t).length}/${results.length} fired)');

      expect(
        rate,
        lessThan(0.10),
        reason: 'More than 10% of non-emergency messages triggered extraction. '
            'Adjust IntentFilter keyword weights or threshold.',
      );
    });

    test('greetings never trigger extraction', () {
      final greetings = nonEmergencyCases
          .where((c) =>
              c.description.toLowerCase().contains('greet') ||
              c.description.toLowerCase().contains('hello') ||
              c.description.toLowerCase().contains('small talk'))
          .toList();

      for (final c in greetings) {
        expect(
          IntentFilter.isLikelyEmergency(c.input),
          isFalse,
          reason: 'Greeting "${c.input}" should not trigger extraction.',
        );
      }
    });

    test('educational how-to queries never trigger extraction', () {
      final educational = nonEmergencyCases
          .where((c) =>
              c.description.toLowerCase().contains('educational') ||
              c.description.toLowerCase().contains('how-to') ||
              c.description.toLowerCase().contains('how to'))
          .toList();

      for (final c in educational) {
        expect(
          IntentFilter.isLikelyEmergency(c.input),
          isFalse,
          reason: 'Educational query "${c.input}" should not trigger extraction.',
        );
      }
    });

    test('historical / hypothetical references never trigger extraction', () {
      final historical = nonEmergencyCases
          .where((c) =>
              c.description.toLowerCase().contains('historical') ||
              c.description.toLowerCase().contains('hypothetical') ||
              c.description.toLowerCase().contains('past event'))
          .toList();

      for (final c in historical) {
        expect(
          IntentFilter.isLikelyEmergency(c.input),
          isFalse,
          reason: '"${c.input}" should not trigger extraction.',
        );
      }
    });

    test('individual scores are positive for emergencies', () {
      // Sanity-check: a clear emergency phrase should score well above threshold.
      const clearEmergency = 'There is a fire on the third floor and people are trapped.';
      expect(IntentFilter.score(clearEmergency), greaterThan(4.0));
      expect(IntentFilter.isLikelyEmergency(clearEmergency), isTrue);
    });

    test('individual scores are low for casual messages', () {
      const casual = 'Good morning, how are you today?';
      expect(IntentFilter.score(casual), lessThan(2.0));
      expect(IntentFilter.isLikelyEmergency(casual), isFalse);
    });
  });
}
