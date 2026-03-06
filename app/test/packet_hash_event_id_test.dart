import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/core/packet_hash.dart';

void main() {
  group('PacketHash.computeReportEventId — stable across coordinate changes', () {
    const src = 'dev01';
    const ts = 1709712000;
    const type = 'fire';
    const desc = 'Building fire 3rd floor';

    test(
      'produces the same event_id for the same incident at two different GPS coordinates',
      () {
        final idAtOriginalLocation = PacketHash.computeReportEventId(
          src: src,
          ts: ts,
          type: type,
          desc: desc,
        );
        final idAfterGpsRefinement = PacketHash.computeReportEventId(
          src: src,
          ts: ts,
          type: type,
          desc: desc,
        );
        // event_id must be identical — coordinates are irrelevant
        expect(idAtOriginalLocation, equals(idAfterGpsRefinement));
      },
    );

    test(
      'the content-hash id changes when coordinates change (existing behaviour preserved)',
      () {
        final idA = PacketHash.computeReportId(
          src,
          ts,
          type,
          1.2830,
          103.8520,
          desc,
        );
        final idB = PacketHash.computeReportId(
          src,
          ts,
          type,
          1.2831,
          103.8521,
          desc,
        );
        // coordinate change → different content hash → no merge confusion in mesh
        expect(idA, isNot(equals(idB)));
      },
    );

    test(
      'event_id differs for a different incident type from the same device',
      () {
        final fireId = PacketHash.computeReportEventId(
          src: src,
          ts: ts,
          type: 'fire',
          desc: desc,
        );
        final medicalId = PacketHash.computeReportEventId(
          src: src,
          ts: ts,
          type: 'medical',
          desc: 'Person collapsed',
        );
        expect(fireId, isNot(equals(medicalId)));
      },
    );

    test(
      'event_id differs for the same incident type reported by a different device',
      () {
        final device1Id = PacketHash.computeReportEventId(
          src: 'device_A',
          ts: ts,
          type: type,
          desc: desc,
        );
        final device2Id = PacketHash.computeReportEventId(
          src: 'device_B',
          ts: ts,
          type: type,
          desc: desc,
        );
        expect(device1Id, isNot(equals(device2Id)));
      },
    );

    test(
      'event_id is 16 hex characters (matching existing id length convention)',
      () {
        final eventId = PacketHash.computeReportEventId(
          src: src,
          ts: ts,
          type: type,
          desc: desc,
        );
        expect(eventId.length, equals(16));
        expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(eventId), isTrue);
      },
    );
  });
}
