import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/core/emergency_intent_filter.dart';

void main() {
  group('EmergencyIntentFilter', () {
    group('detects emergency keywords', () {
      test('fire', () {
        expect(EmergencyIntentFilter.isEmergency('There is a fire'), isTrue);
      });

      test('flood', () {
        expect(
          EmergencyIntentFilter.isEmergency('The street is flooding'),
          isTrue,
        );
      });

      test('gas leak (multi-word)', () {
        expect(
          EmergencyIntentFilter.isEmergency('There is a gas leak on 3rd'),
          isTrue,
        );
      });

      test('heart attack (multi-word)', () {
        expect(
          EmergencyIntentFilter.isEmergency('Someone is having a heart attack'),
          isTrue,
        );
      });

      test('trapped', () {
        expect(
          EmergencyIntentFilter.isEmergency('People are trapped inside'),
          isTrue,
        );
      });

      test('bleeding', () {
        expect(
          EmergencyIntentFilter.isEmergency('He is bleeding heavily'),
          isTrue,
        );
      });
    });

    group('detects urgency keywords', () {
      test('help with emergency context', () {
        // 'help' alone is low-signal (+1.0), below threshold (2.0).
        // Combined with another keyword it triggers.
        expect(
          EmergencyIntentFilter.isEmergency('Please help, there is a fire'),
          isTrue,
        );
      });

      test('SOS (case insensitive)', () {
        expect(EmergencyIntentFilter.isEmergency('SOS SOS SOS'), isTrue);
      });

      test('emergency', () {
        expect(
          EmergencyIntentFilter.isEmergency('This is an emergency'),
          isTrue,
        );
      });

      test('ambulance', () {
        expect(EmergencyIntentFilter.isEmergency('Call an ambulance'), isTrue);
      });
    });

    group('avoids false positives — word boundary', () {
      test('"fired" should not trigger "fire"', () {
        expect(EmergencyIntentFilter.isEmergency('I got fired today'), isFalse);
      });

      test('"crashing" should not trigger "crash"', () {
        expect(
          EmergencyIntentFilter.isEmergency('The app keeps crashing'),
          isFalse,
        );
      });

      test('normal greeting', () {
        expect(EmergencyIntentFilter.isEmergency('Hi there'), isFalse);
      });

      test('normal question', () {
        expect(
          EmergencyIntentFilter.isEmergency('What is the weather today?'),
          isFalse,
        );
      });

      test('thank you', () {
        expect(EmergencyIntentFilter.isEmergency('Thank you so much'), isFalse);
      });

      test('empty string', () {
        expect(EmergencyIntentFilter.isEmergency(''), isFalse);
      });
    });

    group('negative suppression — educational/hypothetical queries', () {
      test('"how to handle a fire" is suppressed', () {
        // 'fire' +3.0, 'how to ' -4.0 = -1.0 → below threshold
        expect(
          EmergencyIntentFilter.isEmergency('how to handle a fire'),
          isFalse,
        );
      });

      test('"what is an earthquake" is suppressed', () {
        // 'earthquake' +3.0, 'what is ' -4.0 = -1.0
        expect(
          EmergencyIntentFilter.isEmergency('what is an earthquake'),
          isFalse,
        );
      });

      test('"hypothetically if there was a flood" is suppressed', () {
        // 'flood' +3.0, 'hypothetically' -4.0, 'if there was' -4.0 = -5.0
        expect(
          EmergencyIntentFilter.isEmergency(
            'hypothetically if there was a flood',
          ),
          isFalse,
        );
      });

      test('"I watched a documentary about fires" is suppressed', () {
        // 'fire' would match via word-boundary in 'fires'? No — 'fires'
        // doesn't match \bfire\b. So score = 0 from keywords,
        // -2.0 from 'i watched', -2.0 from 'documentary' = -4.0
        expect(
          EmergencyIntentFilter.isEmergency(
            'I watched a documentary about fires',
          ),
          isFalse,
        );
      });

      test('"hello, how are you" is suppressed', () {
        expect(
          EmergencyIntentFilter.isEmergency('hello, how are you'),
          isFalse,
        );
      });

      test('"bonfire at the beach" is suppressed', () {
        // 'fire' matches inside 'bonfire'? \bfire\b won't match 'bonfire'.
        // 'bonfire' -2.0 → -2.0 total → no trigger
        expect(
          EmergencyIntentFilter.isEmergency('bonfire at the beach'),
          isFalse,
        );
      });
    });

    group('weighted scoring', () {
      test('single low-signal word does not trigger', () {
        // 'help' = +1.0, below threshold 2.0
        expect(EmergencyIntentFilter.isEmergency('Please help'), isFalse);
        expect(EmergencyIntentFilter.score('Please help'), equals(1.0));
      });

      test('combined signals cross threshold', () {
        // 'fire' +3.0, 'trapped' +3.0 = 6.0
        expect(
          EmergencyIntentFilter.isEmergency('fire and people trapped'),
          isTrue,
        );
        expect(
          EmergencyIntentFilter.score('fire and people trapped'),
          greaterThanOrEqualTo(6.0),
        );
      });

      test('strong emergency resists moderate negatives', () {
        // 'fire' +3.0, 'trapped' +3.0, 'yesterday' -2.0 = 4.0 → still triggers
        expect(
          EmergencyIntentFilter.isEmergency(
            'fire yesterday and people are trapped',
          ),
          isTrue,
        );
      });

      test('medium signal alone triggers', () {
        // 'emergency' = +2.0, exactly at threshold
        expect(
          EmergencyIntentFilter.isEmergency('This is an emergency'),
          isTrue,
        );
      });
    });

    group('case insensitivity', () {
      test('FIRE (uppercase)', () {
        expect(EmergencyIntentFilter.isEmergency('FIRE FIRE FIRE'), isTrue);
      });

      test('Earthquake (mixed case)', () {
        expect(EmergencyIntentFilter.isEmergency('Earthquake!'), isTrue);
      });
    });

    group('debugMatches', () {
      test('returns matched keywords by tier', () {
        final matches = EmergencyIntentFilter.debugMatches(
          'There is a fire and gas leak, help!',
        );
        expect(matches['high'], contains('fire'));
        expect(matches['high'], contains('gas leak'));
        expect(matches['low'], contains('help'));
      });
    });
  });
}
