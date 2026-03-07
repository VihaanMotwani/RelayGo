/// Accumulates streaming LLM tokens and emits speakable sentence-level chunks.
///
/// Flush rules (in priority order):
///   1. Newline — paragraph boundary
///   2. Sentence-ending punctuation (. ? ! :) followed by whitespace
///   3. Buffer exceeds [maxLength] — split at last word boundary
///
/// Call [push] for each incoming token; it returns zero or more ready chunks.
/// Call [flush] at the end of the stream to emit any remaining text.
class SpeechChunker {
  final int maxLength;

  final StringBuffer _buf = StringBuffer();

  SpeechChunker({this.maxLength = 200});

  static final _sentenceEnd = RegExp(r'[.?!:]\s');

  /// Append [token] and return any chunks ready to speak.
  List<String> push(String token) {
    _buf.write(token);
    return _drain();
  }

  /// Emit whatever remains in the buffer (call when the LLM stream ends).
  String? flush() {
    final remaining = _buf.toString().trim();
    _buf.clear();
    return remaining.isNotEmpty ? remaining : null;
  }

  /// Discard all buffered content (call on stop/cancel).
  void reset() {
    _buf.clear();
  }

  List<String> _drain() {
    final chunks = <String>[];
    var text = _buf.toString();

    while (true) {
      // Rule 1: newline
      final nl = text.indexOf('\n');
      if (nl >= 0) {
        final chunk = text.substring(0, nl).trim();
        if (chunk.isNotEmpty) chunks.add(chunk);
        text = text.substring(nl + 1);
        continue;
      }

      // Rule 2: sentence-ending punctuation
      final m = _sentenceEnd.firstMatch(text);
      if (m != null) {
        final chunk = text.substring(0, m.end).trim();
        if (chunk.isNotEmpty) chunks.add(chunk);
        text = text.substring(m.end);
        continue;
      }

      // Rule 3: buffer too long — split at last word boundary
      if (text.length > maxLength) {
        final spaceIdx = text.lastIndexOf(' ', maxLength);
        if (spaceIdx > 0) {
          final chunk = text.substring(0, spaceIdx).trim();
          if (chunk.isNotEmpty) chunks.add(chunk);
          text = text.substring(spaceIdx + 1);
          continue;
        }
      }

      break;
    }

    _buf.clear();
    _buf.write(text);
    return chunks;
  }
}
