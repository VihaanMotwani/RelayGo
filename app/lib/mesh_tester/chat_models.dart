// Data models shared across the RAG + caching chat layer.

class NearbyResource {
  final String name;
  final String type;        // e.g. "fire_station"
  final double distanceKm;
  final String address;

  const NearbyResource({
    required this.name,
    required this.type,
    required this.distanceKm,
    required this.address,
  });

  String get formattedType => type.replaceAll('_', ' ');

  String get distanceStr => distanceKm < 1
      ? '${(distanceKm * 1000).round()} m'
      : '${distanceKm.toStringAsFixed(1)} km';
}

class Passage {
  final String id;          // e.g. "fire_evacuation#0"
  final String docId;       // e.g. "fire_evacuation"
  final String topic;       // e.g. "fire"
  final String text;
  final List<String> keywords;
  final String sourceLabel; // e.g. "Fire Evacuation"

  const Passage({
    required this.id,
    required this.docId,
    required this.topic,
    required this.text,
    required this.keywords,
    required this.sourceLabel,
  });
}

class ScoredPassage {
  final Passage passage;
  final double score;

  const ScoredPassage({required this.passage, required this.score});
}

class ChatMeta {
  final bool fromCache;
  final bool usedRag;
  final List<String> sourceLabels;
  final bool fallback;
  final int nearbyCount;

  const ChatMeta({
    this.fromCache = false,
    this.usedRag = false,
    this.sourceLabels = const [],
    this.fallback = false,
    this.nearbyCount = 0,
  });
}
