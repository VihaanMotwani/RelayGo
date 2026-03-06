import 'package:flutter_test/flutter_test.dart';
import 'package:relaygo/models/extraction_result.dart';

void main() {
  group('ExtractionResult.fromJson', () {
    test('parses valid JSON with all fields', () {
      final json = {
        'type': 'fire',
        'urg': 5,
        'haz': ['gas_leak', 'fire_spread'],
        'desc': 'Building fire 3rd floor',
        'c': {'t': 'high', 'u': 'medium', 'd': 'high'},
      };
      final result = ExtractionResult.fromJson(json);
      expect(result, isNotNull);
      expect(result!.type, 'fire');
      expect(result.urg, 5);
      expect(result.haz, ['gas_leak', 'fire_spread']);
      expect(result.desc, 'Building fire 3rd floor');
      expect(result.typeConfidence, FieldConfidence.high);
      expect(result.urgConfidence, FieldConfidence.medium);
      expect(result.descConfidence, FieldConfidence.high);
    });

    test('returns null when type is null (not an emergency)', () {
      final json = {'type': null};
      expect(ExtractionResult.fromJson(json), isNull);
    });

    test('returns null when type is invalid', () {
      final json = {'type': 'tornado', 'urg': 3, 'desc': 'Something'};
      expect(ExtractionResult.fromJson(json), isNull);
    });

    test('returns null when urgency out of range', () {
      final json = {'type': 'fire', 'urg': 0, 'desc': 'Something'};
      expect(ExtractionResult.fromJson(json), isNull);

      final json2 = {'type': 'fire', 'urg': 6, 'desc': 'Something'};
      expect(ExtractionResult.fromJson(json2), isNull);
    });

    test('returns null when desc is empty', () {
      final json = {'type': 'fire', 'urg': 3, 'desc': ''};
      expect(ExtractionResult.fromJson(json), isNull);
    });

    test('returns null when desc is missing', () {
      final json = {'type': 'fire', 'urg': 3};
      expect(ExtractionResult.fromJson(json), isNull);
    });

    test('parses hazards from comma-separated string', () {
      final json = {
        'type': 'hazmat',
        'urg': 4,
        'haz': 'gas_leak,chemical_spill',
        'desc': 'Chemical spill at factory',
        'c': {'t': 'high', 'u': 'high', 'd': 'high'},
      };
      final result = ExtractionResult.fromJson(json);
      expect(result, isNotNull);
      expect(result!.haz, ['gas_leak', 'chemical_spill']);
    });

    test('defaults confidence to medium when not provided', () {
      final json = {'type': 'medical', 'urg': 3, 'desc': 'Person collapsed'};
      final result = ExtractionResult.fromJson(json);
      expect(result, isNotNull);
      expect(result!.typeConfidence, FieldConfidence.medium);
      expect(result.urgConfidence, FieldConfidence.medium);
      expect(result.descConfidence, FieldConfidence.medium);
    });

    test('handles urg as string', () {
      final json = {'type': 'fire', 'urg': '4', 'desc': 'Fire on 3rd floor'};
      final result = ExtractionResult.fromJson(json);
      expect(result, isNotNull);
      expect(result!.urg, 4);
    });
  });

  group('ExtractionResult.tryParse', () {
    test('extracts JSON from prose', () {
      final raw =
          'Here is the extraction:\n{"type":"fire","urg":5,"haz":[],"desc":"Building on fire","c":{"t":"high","u":"high","d":"high"}}\nDone.';
      final result = ExtractionResult.tryParse(raw);
      expect(result, isNotNull);
      expect(result!.type, 'fire');
      expect(result.urg, 5);
    });

    test('returns null for no JSON', () {
      expect(ExtractionResult.tryParse('No JSON here'), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(ExtractionResult.tryParse('{"type": "fire"'), isNull);
    });

    test('returns null for empty string', () {
      expect(ExtractionResult.tryParse(''), isNull);
    });
  });

  group('ExtractionResult.toJson', () {
    test('roundtrips correctly', () {
      final original = ExtractionResult(
        type: 'flood',
        urg: 3,
        haz: ['flooding'],
        desc: 'Street flooding',
        typeConfidence: FieldConfidence.high,
        urgConfidence: FieldConfidence.low,
        descConfidence: FieldConfidence.medium,
      );
      final json = original.toJson();
      final parsed = ExtractionResult.fromJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.type, original.type);
      expect(parsed.urg, original.urg);
      expect(parsed.haz, original.haz);
      expect(parsed.desc, original.desc);
    });
  });
}
