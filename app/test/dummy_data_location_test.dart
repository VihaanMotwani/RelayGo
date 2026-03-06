import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/mesh_tester/dummy_data.dart';

void main() {
  group('DummyData.generateReports — GPS injection', () {
    const realLat = 35.6952;
    const realLng = 51.4231;
    const realAcc = 8.5;

    test('all reports are within ±200m of the passed-in GPS coordinates', () {
      final reports = DummyData.generateReports(lat: realLat, lng: realLng);
      for (final r in reports) {
        // 0.002 degrees ≈ 220m — jitter is ±0.001 so max offset is ~110m each axis
        expect(
          r.lat,
          closeTo(realLat, 0.002),
          reason: 'Report lat ${r.lat} is too far from $realLat',
        );
        expect(
          r.lng,
          closeTo(realLng, 0.002),
          reason: 'Report lng ${r.lng} is too far from $realLng',
        );
      }
    });

    test(
      'reports do not use the hardcoded Singapore fallback when real GPS is given',
      () {
        final reports = DummyData.generateReports(lat: realLat, lng: realLng);
        for (final r in reports) {
          // Singapore fallback is at ~1.28, 103.85 — Tehran coords are ~35.7, 51.4
          expect(
            r.lat,
            isNot(closeTo(1.2830, 0.1)),
            reason: 'Report is using fallback Singapore latitude',
          );
        }
      },
    );

    test(
      'reports fall back to Singapore coordinates when lat/lng are null',
      () {
        final reports = DummyData.generateReports();
        for (final r in reports) {
          expect(
            r.lat,
            closeTo(1.2830, 0.1),
            reason: 'Expected Singapore fallback lat when null GPS provided',
          );
        }
      },
    );

    test('acc field is populated with the passed-in accuracy value', () {
      final reports = DummyData.generateReports(
        lat: realLat,
        lng: realLng,
        acc: realAcc,
      );
      for (final r in reports) {
        expect(r.acc, equals(realAcc));
      }
    });

    test('acc field defaults to 10 when no accuracy is provided', () {
      final reports = DummyData.generateReports(lat: realLat, lng: realLng);
      for (final r in reports) {
        expect(r.acc, equals(10.0));
      }
    });

    test(
      'reports are not identical — jitter produces distinct coordinates',
      () {
        final reports = DummyData.generateReports(lat: realLat, lng: realLng);
        final lats = reports.map((r) => r.lat).toSet();
        // With random jitter, all 5 reports should have different coordinates
        expect(lats.length, greaterThan(1));
      },
    );
  });
}
