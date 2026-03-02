/// Ground-truth dataset of NON-emergency inputs.
///
/// Every input in this list should NOT trigger the extract_emergency tool call.
/// Used by false_alarm_test.dart to measure false alarm rate.
///
/// Pass criteria: IntentFilter.isLikelyEmergency() returns false for all cases.
library;

class NonEmergencyCase {
  final String input;
  final String description; // why this should NOT be flagged

  const NonEmergencyCase({required this.input, required this.description});
}

const List<NonEmergencyCase> nonEmergencyCases = [
  // ── GREETINGS & SMALL TALK ────────────────────────────────────────────────
  NonEmergencyCase(
    description: 'Simple greeting',
    input: 'Hello, how are you?',
  ),
  NonEmergencyCase(
    description: 'Good morning',
    input: 'Good morning! Is the app working?',
  ),
  NonEmergencyCase(
    description: 'Casual question about the app',
    input: 'What can this app do?',
  ),
  NonEmergencyCase(
    description: 'Thank you message',
    input: 'Thanks for your help earlier.',
  ),
  NonEmergencyCase(
    description: 'Status check',
    input: 'Is anyone else connected to the mesh network right now?',
  ),

  // ── EDUCATIONAL / HOW-TO QUERIES ──────────────────────────────────────────
  NonEmergencyCase(
    description: 'How to perform CPR — educational, not active emergency',
    input: 'How do I perform CPR? I want to learn in case of emergency.',
  ),
  NonEmergencyCase(
    description: 'What is a hazmat suit?',
    input: 'What is a hazmat suit and when do you need one?',
  ),
  NonEmergencyCase(
    description: 'General first aid question',
    input: 'What should I put in a basic first aid kit?',
  ),
  NonEmergencyCase(
    description: 'Fire safety info request',
    input: 'Can you explain the PASS method for using a fire extinguisher?',
  ),
  NonEmergencyCase(
    description: 'Earthquake preparedness',
    input: 'What should I do to prepare for an earthquake?',
  ),
  NonEmergencyCase(
    description: 'Flood safety educational',
    input: 'How high does flood water need to be before it can sweep away a car?',
  ),
  NonEmergencyCase(
    description: 'Medical question — not active',
    input: 'What are the signs of a heart attack?',
  ),
  NonEmergencyCase(
    description: 'General safety tip request',
    input: 'Tell me the best evacuation routes from a burning building.',
  ),

  // ── HISTORICAL / HYPOTHETICAL ─────────────────────────────────────────────
  NonEmergencyCase(
    description: 'Historical event reference',
    input: 'I watched a documentary about the 1906 San Francisco earthquake.',
  ),
  NonEmergencyCase(
    description: 'Hypothetical scenario',
    input: 'Hypothetically, if there was a chemical spill, what should people do?',
  ),
  NonEmergencyCase(
    description: 'News report reference',
    input: 'I read that there was a flood in another city last week.',
  ),
  NonEmergencyCase(
    description: 'Past event, resolved',
    input: 'There was a small fire in the park yesterday but the fire department already handled it.',
  ),

  // ── INFORMATIONAL WITHOUT ACTIVE DANGER ───────────────────────────────────
  NonEmergencyCase(
    description: 'Weather observation, no danger',
    input: 'It is raining heavily outside. The streets look a bit wet.',
  ),
  NonEmergencyCase(
    description: 'Power outage, no immediate danger',
    input: 'The power went out in our building. We have candles. Just letting people know.',
  ),
  NonEmergencyCase(
    description: 'Road closure — no emergency',
    input: 'The main road is closed for construction. Use the alternate route.',
  ),
  NonEmergencyCase(
    description: 'Animal sighting',
    input: 'There is a stray dog near the park. It looks hungry but is not aggressive.',
  ),
  NonEmergencyCase(
    description: 'Noise complaint',
    input: 'There is a lot of noise coming from the building across the street. Sounds like a party.',
  ),

  // ── TRICKY EDGE CASES ─────────────────────────────────────────────────────
  NonEmergencyCase(
    description: 'Fire mentioned but past tense, resolved',
    input: 'The fire in building C was put out last night. All residents are safe.',
  ),
  NonEmergencyCase(
    description: 'Medical word in non-emergency context',
    input: 'I need to find a medical clinic to get a routine checkup.',
  ),
  NonEmergencyCase(
    description: 'Testing message',
    input: 'This is just a test message to see if the radio mesh is working.',
  ),
  NonEmergencyCase(
    description: 'Bonfire or controlled burn, low risk',
    input: 'There is smoke visible from the campsite area. Probably a bonfire.',
  ),
];
