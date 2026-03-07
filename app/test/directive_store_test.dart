import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/models/directive.dart';
import 'package:relaygo/services/mesh/packet_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late PacketStore store;

  setUp(() async {
    store = PacketStore(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  group('PacketStore directives', () {
    Directive _makeDirective({
      String id = 'dir-001',
      int ts = 1000,
      String priority = 'high',
    }) {
      return Directive(
        id: id,
        ts: ts,
        src: 'responder-test',
        name: 'Test',
        body: 'Test body',
        priority: priority,
        zone: null,
        hops: 0,
        ttl: 15,
      );
    }

    test('insertDirective returns true for a new directive', () async {
      final result = await store.insertDirective(_makeDirective());
      expect(result, isTrue);
    });

    test('insertDirective returns false for a duplicate id', () async {
      await store.insertDirective(_makeDirective(id: 'dup-id'));
      final second = await store.insertDirective(_makeDirective(id: 'dup-id'));
      expect(second, isFalse);
    });

    test('getAllDirectives returns results sorted by ts descending', () async {
      await store.insertDirective(_makeDirective(id: 'd1', ts: 100));
      await store.insertDirective(_makeDirective(id: 'd2', ts: 300));
      await store.insertDirective(_makeDirective(id: 'd3', ts: 200));

      final all = await store.getAllDirectives();

      expect(all.length, 3);
      expect(all[0].ts, 300);
      expect(all[1].ts, 200);
      expect(all[2].ts, 100);
    });

    test('getAllDirectives returns empty list when store is empty', () async {
      final all = await store.getAllDirectives();
      expect(all, isEmpty);
    });
  });
}
