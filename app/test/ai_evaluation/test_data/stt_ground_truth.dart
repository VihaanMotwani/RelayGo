/// Ground-truth transcription pairs for STT (Word Error Rate) evaluation.
///
/// Each entry pairs a [audioFile] path (relative to test/ai_evaluation/audio/)
/// with the [reference] text — the correct transcription.
///
/// The audio files are NOT committed to the repo. To run STT evaluation:
///   1. Record real audio using the RelayGo app
///   2. Copy WAV files to test/ai_evaluation/audio/
///   3. Update file names here to match
///
/// For CI without audio hardware, the WER tests mock AiService.transcribe()
/// using [mockHypothesis] so metric functions can be validated.
library;

class SttGroundTruthCase {
  /// Path to audio file, relative to test/ai_evaluation/audio/
  final String audioFile;

  /// Correct reference transcription (lower-cased, no punctuation for WER).
  final String reference;

  /// Optional mock hypothesis to use in offline/CI mode instead of real STT.
  final String? mockHypothesis;

  const SttGroundTruthCase({
    required this.audioFile,
    required this.reference,
    this.mockHypothesis,
  });
}

/// Real audio test cases — add recorded WAV files here.
/// Format: 16kHz, mono, WAV (matching AudioService specs).
const List<SttGroundTruthCase> sttCases = [
  // ── EMERGENCY PHRASES ─────────────────────────────────────────────────────
  SttGroundTruthCase(
    audioFile: 'fire_third_floor.wav',
    reference: 'there is a fire on the third floor of my building',
    // Perfect hypothesis — baseline for WER = 0.0
    mockHypothesis: 'there is a fire on the third floor of my building',
  ),
  SttGroundTruthCase(
    audioFile: 'person_not_breathing.wav',
    reference: 'a person collapsed and is not breathing please help',
    // One substitution (collapsed→collapse): WER = 1/8 ≈ 0.125
    mockHypothesis: 'a person collapse and is not breathing please help',
  ),
  SttGroundTruthCase(
    audioFile: 'gas_leak.wav',
    reference: 'i smell gas in the apartment and there is a small flame near the stove',
    // Deletion of "small": WER = 1/14 ≈ 0.071
    mockHypothesis: 'i smell gas in the apartment and there is a flame near the stove',
  ),
  SttGroundTruthCase(
    audioFile: 'trapped_rubble.wav',
    reference: 'i am trapped under rubble and cannot move my leg is broken',
    // Two insertions: WER = 2/12 ≈ 0.167
    mockHypothesis: 'i am trapped under the rubble and i cannot move my leg is broken',
  ),
  SttGroundTruthCase(
    audioFile: 'flood_rising.wav',
    reference: 'water is rising fast already waist high we need rescue now',
    // Near-perfect, one substitution (waist→waste)
    mockHypothesis: 'water is rising fast already waste high we need rescue now',
  ),

  // ── CASUAL PHRASES (non-emergency) ────────────────────────────────────────
  SttGroundTruthCase(
    audioFile: 'hello_test.wav',
    reference: 'hello how are you',
    mockHypothesis: 'hello how are you',
  ),
  SttGroundTruthCase(
    audioFile: 'how_to_cpr.wav',
    reference: 'how do i perform cpr i want to learn',
    // Common whisper error: CPR → cpr (case only — WER treats as identical after normalize)
    mockHypothesis: 'how do i perform cpr i want to learn',
  ),

  // ── NOISY / DIFFICULT CONDITIONS ─────────────────────────────────────────
  SttGroundTruthCase(
    audioFile: 'fire_noisy.wav', // recorded with background noise
    reference: 'fire on third floor send help immediately',
    // Noisy transcription — higher WER expected
    mockHypothesis: 'fire on the third floor send help immediately',
  ),
  SttGroundTruthCase(
    audioFile: 'medical_distressed.wav', // speaker crying / distressed
    reference: 'my father is not breathing i do not know what to do',
    mockHypothesis: 'my father is not breathing i do not know what to do',
  ),
];
