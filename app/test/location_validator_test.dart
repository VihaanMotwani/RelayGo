import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/services/location_validator.dart';

void main() {
  group('LocationValidator.isAcceptableAccuracy', () {
    test('accepts a new fix with better accuracy than the last', () {
      // First fix is 30m, new fix is 8m — should accept
      expect(
        LocationValidator.isAcceptableAccuracy(newAcc: 8.0, lastAcc: 30.0),
        isTrue,
      );
    });

    test('accepts a new fix with similar accuracy', () {
      // Tolerance: up to 2x regression allowed
      expect(
        LocationValidator.isAcceptableAccuracy(newAcc: 50.0, lastAcc: 30.0),
        isTrue,
      );
    });

    test('rejects a new fix that is more than 2x worse than the last', () {
      // Last was 10m, new is 300m — clear regression
      expect(
        LocationValidator.isAcceptableAccuracy(newAcc: 300.0, lastAcc: 10.0),
        isFalse,
      );
    });

    test('accepts any fix when there is no prior accuracy reference', () {
      // First fix ever — no lastAcc to compare against
      expect(
        LocationValidator.isAcceptableAccuracy(newAcc: 400.0, lastAcc: null),
        isTrue,
      );
    });

    test(
      'always accepts a fix within the floor accuracy threshold even if regressed',
      () {
        // Both are under 50m — both considered good enough
        expect(
          LocationValidator.isAcceptableAccuracy(newAcc: 45.0, lastAcc: 20.0),
          isTrue,
        );
      },
    );
  });

  group('LocationValidator.isPhysicallyPlausible', () {
    test(
      'accepts a movement of 30m over 5 seconds (6 m/s = walking speed)',
      () {
        expect(
          LocationValidator.isPhysicallyPlausible(
            distanceMetres: 30,
            elapsedSeconds: 5,
          ),
          isTrue,
        );
      },
    );

    test('accepts a movement of 500m over 30 seconds (16 m/s = fast car)', () {
      expect(
        LocationValidator.isPhysicallyPlausible(
          distanceMetres: 500,
          elapsedSeconds: 30,
        ),
        isTrue,
      );
    });

    test(
      'rejects a fix implying movement at 500 km/h (GPS teleportation glitch)',
      () {
        // 2000m in 1 second = 2000 m/s → physically impossible
        expect(
          LocationValidator.isPhysicallyPlausible(
            distanceMetres: 2000,
            elapsedSeconds: 1,
          ),
          isFalse,
        );
      },
    );

    test('rejects teleportation 10km away in 3 seconds', () {
      expect(
        LocationValidator.isPhysicallyPlausible(
          distanceMetres: 10000,
          elapsedSeconds: 3,
        ),
        isFalse,
      );
    });

    test('accepts any fix when elapsed time is zero (first sample)', () {
      // Edge case: very first position fix, no prior timestamp available
      expect(
        LocationValidator.isPhysicallyPlausible(
          distanceMetres: 100,
          elapsedSeconds: 0,
        ),
        isTrue,
      );
    });
  });

  group('LocationValidator.hasMoved', () {
    test('reports moved when distance exceeds the threshold', () {
      expect(
        LocationValidator.hasMoved(distanceMetres: 30, thresholdMetres: 25),
        isTrue,
      );
    });

    test('reports not moved when exactly on the threshold', () {
      expect(
        LocationValidator.hasMoved(distanceMetres: 25, thresholdMetres: 25),
        isFalse,
      );
    });

    test('reports not moved when well below threshold (stationary device)', () {
      expect(
        LocationValidator.hasMoved(distanceMetres: 2, thresholdMetres: 25),
        isFalse,
      );
    });

    test('respects a custom threshold', () {
      // For vehicle tracking, threshold might be 100m
      expect(
        LocationValidator.hasMoved(distanceMetres: 80, thresholdMetres: 100),
        isFalse,
      );
      expect(
        LocationValidator.hasMoved(distanceMetres: 120, thresholdMetres: 100),
        isTrue,
      );
    });
  });
}
