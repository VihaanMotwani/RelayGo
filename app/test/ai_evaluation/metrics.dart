/// Pure Dart metric functions for AI evaluation.
///
/// No Flutter or plugin dependencies — safe to run in standard `dart test`.
library;

// ═══════════════════════════════════════════════════════════════════════════
// TYPE ACCURACY
// ═══════════════════════════════════════════════════════════════════════════

/// Computes the fraction of predictions where [predicted] exactly matches
/// [expected] (case-insensitive).
///
/// Returns a value in [0.0, 1.0].
///
/// ```dart
/// typeAccuracy([
///   (predicted: 'fire', expected: 'fire'),
///   (predicted: 'medical', expected: 'fire'),
/// ]); // → 0.5
/// ```
double typeAccuracy(
  List<({String predicted, String expected})> pairs,
) {
  if (pairs.isEmpty) return 0.0;
  final correct = pairs
      .where((p) => p.predicted.toLowerCase() == p.expected.toLowerCase())
      .length;
  return correct / pairs.length;
}

// ═══════════════════════════════════════════════════════════════════════════
// URGENCY MAE
// ═══════════════════════════════════════════════════════════════════════════

/// Mean Absolute Error for urgency predictions (integer scale 1–5).
///
/// Lower is better. A MAE of 0 means perfect urgency prediction.
/// A MAE of 1.0 means off by one level on average.
///
/// ```dart
/// urgencyMAE([
///   (predicted: 5, expected: 5),
///   (predicted: 3, expected: 5),
/// ]); // → 1.0
/// ```
double urgencyMAE(
  List<({int predicted, int expected})> pairs,
) {
  if (pairs.isEmpty) return 0.0;
  final totalError = pairs.fold<double>(
    0.0,
    (sum, p) => sum + (p.predicted - p.expected).abs(),
  );
  return totalError / pairs.length;
}

// ═══════════════════════════════════════════════════════════════════════════
// HAZARDS F1
// ═══════════════════════════════════════════════════════════════════════════

/// F1 score for hazard set prediction (micro-averaged over all cases).
///
/// Treats hazards as a set classification problem per example, then
/// micro-averages across the full dataset.
///
/// Returns a value in [0.0, 1.0]. 1.0 = perfect, 0.0 = no overlap at all.
///
/// ```dart
/// hazardsF1([
///   (predicted: {'fire_spread', 'gas_leak'}, expected: {'fire_spread'}),
/// ]); // precision=0.5, recall=1.0 → F1=0.667
/// ```
double hazardsF1(
  List<({Set<String> predicted, Set<String> expected})> pairs,
) {
  int totalTp = 0;
  int totalFp = 0;
  int totalFn = 0;

  for (final pair in pairs) {
    final tp = pair.predicted.intersection(pair.expected).length;
    final fp = pair.predicted.difference(pair.expected).length;
    final fn = pair.expected.difference(pair.predicted).length;
    totalTp += tp;
    totalFp += fp;
    totalFn += fn;
  }

  final precision = totalTp + totalFp == 0
      ? 1.0
      : totalTp / (totalTp + totalFp);
  final recall = totalTp + totalFn == 0
      ? 1.0
      : totalTp / (totalTp + totalFn);

  if (precision + recall == 0) return 0.0;
  return 2 * precision * recall / (precision + recall);
}

// ═══════════════════════════════════════════════════════════════════════════
// WORD ERROR RATE (WER)
// ═══════════════════════════════════════════════════════════════════════════

/// Standard Word Error Rate: (S + D + I) / N
///
/// Where:
///   S = substitutions, D = deletions, I = insertions
///   N = number of words in [reference]
///
/// Both [hypothesis] and [reference] are normalised before comparison:
///   - lowercased
///   - punctuation stripped
///   - multiple spaces collapsed
///
/// Returns a value >= 0.0. Values > 1.0 are possible when insertions are
/// very high relative to reference length. Lower is better; 0.0 = perfect.
///
/// ```dart
/// wordErrorRate('hello world', 'hello world'); // → 0.0
/// wordErrorRate('hello earth', 'hello world'); // → 0.5 (one substitution / 2 words)
/// ```
double wordErrorRate(String hypothesis, String reference) {
  final hyp = _normalise(hypothesis).split(' ');
  final ref = _normalise(reference).split(' ');

  if (ref.isEmpty) return hyp.isEmpty ? 0.0 : double.infinity;

  // Levenshtein edit distance (word-level)
  final d = _editDistance(hyp, ref);
  return d / ref.length;
}

/// Normalise text: lowercase, strip punctuation, collapse whitespace.
String _normalise(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Word-level Levenshtein distance using standard DP.
int _editDistance(List<String> hyp, List<String> ref) {
  final m = ref.length;
  final n = hyp.length;

  // dp[i][j] = edit distance between ref[0..i) and hyp[0..j)
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

  for (var i = 0; i <= m; i++) dp[i][0] = i;
  for (var j = 0; j <= n; j++) dp[0][j] = j;

  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (ref[i - 1] == hyp[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        dp[i][j] = 1 +
            [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                .reduce((a, b) => a < b ? a : b);
      }
    }
  }

  return dp[m][n];
}

// ═══════════════════════════════════════════════════════════════════════════
// FALSE ALARM RATE
// ═══════════════════════════════════════════════════════════════════════════

/// Fraction of non-emergency inputs that were incorrectly flagged as emergency.
///
/// [triggered] is the list of booleans where `true` means the system
/// (intent filter or LLM) incorrectly fired.
///
/// Returns a value in [0.0, 1.0]. Lower is better; 0.0 = no false alarms.
double falseAlarmRate(List<bool> triggered) {
  if (triggered.isEmpty) return 0.0;
  return triggered.where((t) => t).length / triggered.length;
}

// ═══════════════════════════════════════════════════════════════════════════
// PRETTY PRINT
// ═══════════════════════════════════════════════════════════════════════════

/// Formats a metric value as a percentage string for console output.
String pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

/// Formats a MAE value with two decimal places.
String mae(double value) => value.toStringAsFixed(2);
