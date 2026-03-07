import 'chat_models.dart';

/// Assembles the full prompt sent to the LLM for a single turn.
///
/// The Qwen2.5-0.5B model has a 1280-token total context (input + output)
/// that is shared across sessions via KV cache. We budget:
///   - System:   ~30 tokens
///   - Passages: top 1, truncated to 200 chars (~50 tokens)
///   - Nearby:   top 2, name + distance only (~30 tokens)
///   - Question: as-is (~30 tokens)
///   Total input ≈ 140 tokens — leaves ~1100 tokens headroom for KV accumulation
///   and ~300 tokens for the response.
class PromptBuilder {
  static const String _system =
      'Emergency assistant. English only. Under 60 words. Direct and actionable.';

  // Maximum characters for a single passage — keeps token count predictable.
  static const int _maxPassageChars = 200;

  static String build(
    String userQuery,
    List<ScoredPassage> passages, {
    List<NearbyResource> nearby = const [],
    bool locationAvailable = false,
  }) {
    final buf = StringBuffer();
    buf.writeln(_system);

    if (passages.isNotEmpty) {
      // Only inject the top-scored passage to minimize tokens.
      final top = passages.first;
      final text = top.passage.text.length > _maxPassageChars
          ? '${top.passage.text.substring(0, _maxPassageChars)}…'
          : top.passage.text;
      buf.writeln();
      buf.writeln('[${top.passage.sourceLabel}]: $text');
    }

    if (nearby.isNotEmpty) {
      buf.writeln();
      // Group by type so the model knows what kind of facility each entry is.
      final byType = <String, List<NearbyResource>>{};
      for (final r in nearby.take(2)) {
        byType.putIfAbsent(r.formattedType, () => []).add(r);
      }
      byType.forEach((type, resources) {
        buf.writeln('Nearest $type:');
        for (final r in resources) {
          buf.writeln('- ${r.name} — ${r.distanceStr}');
        }
      });
    } else if (locationAvailable) {
      // GPS available but no matching facilities found.
      buf.writeln();
      buf.writeln('No relevant facilities found nearby.');
    } else {
      // No GPS — tell the model explicitly so it does not hallucinate addresses.
      buf.writeln();
      buf.writeln('Location: unavailable. Do not guess addresses or distances.');
    }

    buf.writeln();
    buf.write('Q: $userQuery');
    return buf.toString();
  }

  /// Direct synthesis from the top passage when LLM generation fails.
  static String buildFallback(Passage passage) => passage.text;
}
