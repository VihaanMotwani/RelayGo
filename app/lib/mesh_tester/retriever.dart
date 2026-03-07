import 'chat_models.dart';

/// Deterministic lexical retrieval over a corpus of [Passage] objects.
///
/// Scoring per passage:
///   +2  for each passage keyword found anywhere in the query string
///   +1  for each query token (len > 2) found in the passage text
///
/// Returns up to [maxResults] passages sorted by descending score,
/// filtered to score > 0.
class Retriever {
  static const int maxResults = 2;

  List<ScoredPassage> retrieve(String query, List<Passage> passages) {
    final queryLower = query.toLowerCase();
    final queryTokens = _tokenize(queryLower);
    if (queryTokens.isEmpty) return [];

    final scored = <ScoredPassage>[];

    for (final passage in passages) {
      double score = 0;
      final passageText = passage.text.toLowerCase();

      // Keyword hits: passage keywords present in the raw query string.
      for (final kw in passage.keywords) {
        if (queryLower.contains(kw)) {
          score += 2;
        }
      }

      // Token hits: query words present in the passage body.
      for (final token in queryTokens) {
        if (token.length > 2 && passageText.contains(token)) {
          score += 1;
        }
      }

      if (score > 0) {
        scored.add(ScoredPassage(passage: passage, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).toList();
  }

  List<String> _tokenize(String text) =>
      text.split(RegExp(r'[^\w]+'))
          .where((t) => t.length > 1)
          .toList();
}
