import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'chat_models.dart';

class _SourceMeta {
  final String topic;
  final String label;
  final List<String> keywords;
  const _SourceMeta(this.topic, this.label, this.keywords);
}

/// Loads bundled knowledge assets, splits them into passage-sized units,
/// and computes a stable content hash used for cache invalidation.
class KnowledgeRepository {
  static const Map<String, _SourceMeta> _meta = {
    'fire_evacuation': _SourceMeta('fire', 'Fire Evacuation', [
      'fire', 'smoke', 'flames', 'evacuation', 'evacuate', 'exit',
      'trapped', 'hot', 'burn', 'stop drop roll',
    ]),
    'cpr_instructions': _SourceMeta('medical', 'CPR', [
      'cpr', 'cardiac', 'heart', 'chest', 'compressions', 'breathing',
      'aed', 'resuscitate', 'pulse', 'unconscious', 'not breathing',
    ]),
    'earthquake_response': _SourceMeta('earthquake', 'Earthquake', [
      'earthquake', 'quake', 'shaking', 'tremor', 'aftershock',
      'tsunami', 'drop', 'cover', 'rumbling',
    ]),
    'first_aid_basics': _SourceMeta('medical', 'First Aid', [
      'bleeding', 'wound', 'burn', 'fracture', 'choking', 'shock',
      'injury', 'blood', 'hurt', 'broken', 'cut',
    ]),
    'flood_response': _SourceMeta('flood', 'Flood Response', [
      'flood', 'water', 'drowning', 'rain', 'river', 'submerged',
      'drown', 'swept',
    ]),
    'general_emergency': _SourceMeta('emergency', 'General Emergency', [
      'emergency', '911', 'help', 'call', 'panic', 'calm', 'triage',
      'urgent', 'danger', 'crisis',
    ]),
    'hazmat_safety': _SourceMeta('hazmat', 'Hazmat Safety', [
      'chemical', 'gas', 'toxic', 'hazmat', 'leak', 'fumes',
      'poisonous', 'spill', 'contamination', 'odor',
    ]),
  };

  List<Passage> _passages = [];
  String _contentHash = '';

  List<Passage> get passages => _passages;
  String get contentHash => _contentHash;

  Future<void> initialize() async {
    final allContent = StringBuffer();
    final passages = <Passage>[];

    for (final entry in _meta.entries) {
      final docId = entry.key;
      final meta = entry.value;
      final content =
          await rootBundle.loadString('assets/knowledge/$docId.txt');
      allContent.write(content);

      final blocks = _splitIntoBlocks(content);
      for (int i = 0; i < blocks.length; i++) {
        passages.add(Passage(
          id: '$docId#$i',
          docId: docId,
          topic: meta.topic,
          text: blocks[i],
          keywords: meta.keywords,
          sourceLabel: meta.label,
        ));
      }
    }

    _passages = passages;
    // 16-char prefix of SHA-256 is enough for cache invalidation.
    _contentHash = sha256
        .convert(utf8.encode(allContent.toString()))
        .toString()
        .substring(0, 16);
  }

  /// Split a knowledge file into logical passage blocks.
  /// Blocks are separated by one or more blank lines.
  List<String> _splitIntoBlocks(String content) {
    return content
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
  }
}
