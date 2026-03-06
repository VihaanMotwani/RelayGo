import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/models/emergency_report.dart';

void main() {
  group('EmergencyReport.event_id — stable across coordinate updates', () {
    final baseReport = EmergencyReport(
      ts: 1709712000,
      lat: 1.2830,
      lng: 103.8520,
      type: 'fire',
      urg: 5,
      desc: 'Building fire 3rd floor',
      src: 'dev01',
    );

    test(
      'event_id does not change when lat/lng are different for the same incident',
      () {
        final updatedReport = EmergencyReport(
          ts: 1709712000,
          lat: 1.2832, // GPS refined by 20m
          lng: 103.8522,
          type: 'fire',
          urg: 5,
          desc: 'Building fire 3rd floor',
          src: 'dev01',
        );
        // Same physical event — should share the same event_id
        expect(baseReport.eventId, equals(updatedReport.eventId));
      },
    );

    test('id (content hash) changes when lat/lng change', () {
      final updatedReport = EmergencyReport(
        ts: 1709712000,
        lat: 1.2832,
        lng: 103.8522,
        type: 'fire',
        urg: 5,
        desc: 'Building fire 3rd floor',
        src: 'dev01',
      );
      // The mesh dedup hash must still differ so nodes treat these as distinct Wire packets
      expect(baseReport.id, isNot(equals(updatedReport.id)));
    });

    test('toJson() includes event_id', () {
      final json = baseReport.toJson();
      expect(json.containsKey('event_id'), isTrue);
      expect(json['event_id'], isA<String>());
      expect((json['event_id'] as String).length, equals(16));
    });

    test('fromJson() round-trips event_id correctly', () {
      final json = baseReport.toJson();
      final restored = EmergencyReport.fromJson(json);
      expect(restored.eventId, equals(baseReport.eventId));
    });

    test('toWireJson() includes event_id for BLE propagation', () {
      final wire = baseReport.toWireJson();
      // Wire key: 'ei' (event_id abbreviated to save BLE bytes)
      expect(wire.containsKey('ei'), isTrue);
      expect(wire['ei'], equals(baseReport.eventId));
    });

    test('fromWireJson() round-trips event_id correctly', () {
      final wire = baseReport.toWireJson();
      final restored = EmergencyReport.fromWireJson(wire);
      expect(restored.eventId, equals(baseReport.eventId));
    });
  });
}
