import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/models/directive.dart';

void main() {
  group('Directive.fromJson', () {
    test('parses full JSON from backend', () {
      final json = {
        'kind': 'directive',
        'id': 'abc-123',
        'ts': 1709337600,
        'src': 'responder-alpha',
        'name': 'Alpha Command',
        'to': null,
        'zone': 'sector-7',
        'body': 'Evacuate via north exit immediately.',
        'priority': 'high',
        'hops': 2,
        'ttl': 15,
      };

      final d = Directive.fromJson(json);

      expect(d.id, 'abc-123');
      expect(d.ts, 1709337600);
      expect(d.src, 'responder-alpha');
      expect(d.name, 'Alpha Command');
      expect(d.to, isNull);
      expect(d.zone, 'sector-7');
      expect(d.body, 'Evacuate via north exit immediately.');
      expect(d.priority, 'high');
      expect(d.hops, 2);
      expect(d.ttl, 15);
    });

    test('defaults priority to high when field is missing', () {
      final json = {
        'id': 'xyz-999',
        'ts': 1709337600,
        'src': 'responder-beta',
        'name': 'Beta',
        'body': 'Stand by.',
      };

      final d = Directive.fromJson(json);

      expect(d.priority, 'high');
    });

    test('fromJson handles null zone', () {
      final json = {
        'id': 'no-zone-id',
        'ts': 1709337600,
        'src': 'src',
        'name': 'Name',
        'body': 'Body',
        'zone': null,
      };

      final d = Directive.fromJson(json);

      expect(d.zone, isNull);
    });

    test('toJson round-trips correctly', () {
      final original = Directive(
        id: 'round-trip-id',
        ts: 1709337600,
        src: 'responder-gamma',
        name: 'Gamma',
        body: 'Check in.',
        priority: 'medium',
        zone: 'sector-3',
        hops: 0,
        ttl: 15,
      );

      final json = original.toJson();
      final parsed = Directive.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.priority, 'medium');
      expect(parsed.zone, 'sector-3');
    });
  });
}
