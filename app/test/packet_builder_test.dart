import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/core/packet_builder.dart';
import 'package:relaygo/models/extraction_result.dart';
import 'package:geolocator/geolocator.dart';

// Create a Position for testing
Position _testPosition({
  double lat = 1.283,
  double lng = 103.852,
  double acc = 10.0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    accuracy: acc,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    timestamp: DateTime.now(),
  );
}

void main() {
  group('PacketBuilder.build', () {
    test('creates report from extraction + GPS', () {
      final extraction = ExtractionResult(
        type: 'fire',
        urg: 5,
        haz: ['gas_leak'],
        desc: 'Building fire 3rd floor',
      );

      final report = PacketBuilder.build(
        extraction: extraction,
        position: _testPosition(),
        deviceId: 'dev01',
      );

      expect(report.type, 'fire');
      expect(report.urg, 5);
      expect(report.haz, ['gas_leak']);
      expect(report.desc, 'Building fire 3rd floor');
      expect(report.lat, 1.283);
      expect(report.lng, 103.852);
      expect(report.acc, 10.0);
      expect(report.src, 'dev01');
      expect(report.ttl, 10);
      expect(report.hops, 0);
    });

    test('truncates desc at 100 chars', () {
      final longDesc = 'A' * 150;
      final extraction = ExtractionResult(type: 'fire', urg: 3, desc: longDesc);

      final report = PacketBuilder.build(
        extraction: extraction,
        position: _testPosition(),
        deviceId: 'dev01',
      );

      expect(report.desc.length, 100);
      expect(report.desc.endsWith('…'), isTrue);
    });

    test('does not truncate desc at exactly 100 chars', () {
      final exactDesc = 'B' * 100;
      final extraction = ExtractionResult(
        type: 'fire',
        urg: 3,
        desc: exactDesc,
      );

      final report = PacketBuilder.build(
        extraction: extraction,
        position: _testPosition(),
        deviceId: 'dev01',
      );

      expect(report.desc.length, 100);
      expect(report.desc, exactDesc);
    });

    test('uses sentinel values when GPS is null', () {
      final extraction = ExtractionResult(type: 'fire', urg: 3, desc: 'Fire');

      final report = PacketBuilder.build(
        extraction: extraction,
        position: null,
        deviceId: 'dev01',
      );

      expect(report.lat, 1.3521);
      expect(report.lng, 103.8198);
      expect(report.acc, 999.0);
    });
  });

  group('PacketBuilder.rebuildWithNewLocation', () {
    test('preserves eventId across rebuilds', () {
      final extraction = ExtractionResult(
        type: 'fire',
        urg: 5,
        desc: 'Building fire 3rd floor',
      );

      final original = PacketBuilder.build(
        extraction: extraction,
        position: _testPosition(lat: 1.0, lng: 103.0),
        deviceId: 'dev01',
      );

      final rebuilt = PacketBuilder.rebuildWithNewLocation(
        extraction: extraction,
        originalTs: original.ts,
        position: _testPosition(lat: 1.001, lng: 103.001),
        deviceId: 'dev01',
      );

      // eventId should be the same (same src+ts+type+desc)
      expect(rebuilt.eventId, original.eventId);
      // id should differ (different lat/lng)
      expect(rebuilt.id, isNot(original.id));
      // GPS should be updated
      expect(rebuilt.lat, 1.001);
      expect(rebuilt.lng, 103.001);
    });
  });
}
