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
      test('help', () {
        expect(EmergencyIntentFilter.isEmergency('Please help'), isTrue);
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

    group('avoids false positives', () {
      test('"fired" should not trigger "fire"', () {
        expect(EmergencyIntentFilter.isEmergency('I got fired today'), isFalse);
      });

      test('"crashing" should not trigger "crash"', () {
        // "crashing" doesn't match word-boundary "crash"
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

    group('case insensitivity', () {
      test('FIRE (uppercase)', () {
        expect(EmergencyIntentFilter.isEmergency('FIRE FIRE FIRE'), isTrue);
      });

      test('Earthquake (mixed case)', () {
        expect(EmergencyIntentFilter.isEmergency('Earthquake!'), isTrue);
      });
    });
  });
}
