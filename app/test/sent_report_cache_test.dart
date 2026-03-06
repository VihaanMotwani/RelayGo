import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/core/sent_report_cache.dart';
import 'package:relaygo/models/extraction_result.dart';

void main() {
  late SentReportCache cache;

  setUp(() {
    cache = SentReportCache();
  });

  final testExtraction = ExtractionResult(
    type: 'fire',
    urg: 5,
    desc: 'Building fire',
  );

  group('add and lookup', () {
    test('starts empty', () {
      expect(cache.isEmpty, isTrue);
      expect(cache.isNotEmpty, isFalse);
      expect(cache.entries, isEmpty);
      expect(cache.latest, isNull);
    });

    test('add and find by eventId', () {
      cache.add(
        extraction: testExtraction,
        eventId: 'evt123',
        ts: 1000,
        lat: 1.283,
        lng: 103.852,
      );

      expect(cache.isNotEmpty, isTrue);
      expect(cache.entries.length, 1);

      final entry = cache.findByEventId('evt123');
      expect(entry, isNotNull);
      expect(entry!.extraction.type, 'fire');
      expect(entry.ts, 1000);
    });

    test('returns null for unknown eventId', () {
      cache.add(
        extraction: testExtraction,
        eventId: 'evt123',
        ts: 1000,
        lat: 1.283,
        lng: 103.852,
      );

      expect(cache.findByEventId('unknown'), isNull);
    });

    test('latest returns last added', () {
      cache.add(
        extraction: testExtraction,
        eventId: 'evt1',
        ts: 1000,
        lat: 1.0,
        lng: 103.0,
      );
      cache.add(
        extraction: ExtractionResult(type: 'flood', urg: 3, desc: 'Flooding'),
        eventId: 'evt2',
        ts: 2000,
        lat: 2.0,
        lng: 104.0,
      );

      expect(cache.latest!.eventId, 'evt2');
      expect(cache.entries.length, 2);
    });
  });

  group('hasMoved', () {
    test('returns true for unknown eventId', () {
      expect(cache.hasMoved('unknown', 1.0, 103.0), isTrue);
    });

    test('returns false when location unchanged', () {
      cache.add(
        extraction: testExtraction,
        eventId: 'evt1',
        ts: 1000,
        lat: 1.283,
        lng: 103.852,
      );

      expect(cache.hasMoved('evt1', 1.283, 103.852), isFalse);
    });

    test('returns false for small movement (< 25m)', () {
      cache.add(
        extraction: testExtraction,
        eventId: 'evt1',
        ts: 1000,
        lat: 1.283,
        lng: 103.852,
      );

      // ~10m offset
      expect(cache.hasMoved('evt1', 1.28309, 103.852), isFalse);
    });

    test('returns true for significant movement (> 25m)', () {
      cache.add(
        extraction: testExtraction,
        eventId: 'evt1',
        ts: 1000,
        lat: 1.283,
        lng: 103.852,
      );

      // ~100m offset
      expect(cache.hasMoved('evt1', 1.284, 103.852), isTrue);
    });

    test('respects custom threshold', () {
      cache.add(
        extraction: testExtraction,
        eventId: 'evt1',
        ts: 1000,
        lat: 1.283,
        lng: 103.852,
      );

      // ~100m offset, with 200m threshold → should not have moved
      expect(
        cache.hasMoved('evt1', 1.284, 103.852, thresholdMeters: 200),
        isFalse,
      );
    });
  });

  group('updateLocation', () {
    test('updates cached GPS', () {
      cache.add(
        extraction: testExtraction,
        eventId: 'evt1',
        ts: 1000,
        lat: 1.283,
        lng: 103.852,
      );

      cache.updateLocation('evt1', 1.290, 103.860);

      final entry = cache.findByEventId('evt1');
      expect(entry!.lastLat, 1.290);
      expect(entry.lastLng, 103.860);
    });

    test('no-op for unknown eventId', () {
      // Should not throw
      cache.updateLocation('unknown', 1.0, 103.0);
    });
  });
}
