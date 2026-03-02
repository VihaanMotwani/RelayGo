/// Ground-truth dataset for emergency extraction quality evaluation.
///
/// Each case defines an [input] message and the expected structured output
/// from the extract_emergency tool. Used by extraction_quality_test.dart
/// to compute type accuracy, urgency MAE, and hazards F1.
library;

class ExtractionCase {
  final String input;
  final String expectedType;
  final int expectedUrgency;
  final Set<String> expectedHazards;
  final String description; // human-readable label

  const ExtractionCase({
    required this.input,
    required this.expectedType,
    required this.expectedUrgency,
    required this.expectedHazards,
    required this.description,
  });
}

const List<ExtractionCase> extractionCases = [
  // ── FIRE ──────────────────────────────────────────────────────────────────
  ExtractionCase(
    description: 'Active structure fire with spread risk',
    input: 'There is a fire on the third floor of my building. Smoke is filling the hallway and I can hear it spreading.',
    expectedType: 'fire',
    expectedUrgency: 5,
    expectedHazards: {'fire_spread'},
  ),
  ExtractionCase(
    description: 'Kitchen fire, minor',
    input: 'Small fire in the kitchen, I think it started from the stove. I already used the extinguisher but it might reignite.',
    expectedType: 'fire',
    expectedUrgency: 3,
    expectedHazards: {'fire_spread'},
  ),
  ExtractionCase(
    description: 'Wildfire approaching neighborhood',
    input: 'Wildfire is about 200 meters from our street. Flames are visible over the hill and the wind is pushing it toward us.',
    expectedType: 'fire',
    expectedUrgency: 5,
    expectedHazards: {'fire_spread'},
  ),
  ExtractionCase(
    description: 'Gas leak with fire risk',
    input: 'I smell strong gas in my apartment and there is a small flame near the stove that I cannot extinguish.',
    expectedType: 'fire',
    expectedUrgency: 5,
    expectedHazards: {'gas_leak', 'fire_spread'},
  ),

  // ── MEDICAL ───────────────────────────────────────────────────────────────
  ExtractionCase(
    description: 'Cardiac arrest, unconscious person',
    input: 'My neighbor collapsed in the hallway, he is not breathing and has no pulse. Someone is doing CPR.',
    expectedType: 'medical',
    expectedUrgency: 5,
    expectedHazards: {},
  ),
  ExtractionCase(
    description: 'Severe laceration, heavy bleeding',
    input: 'Person has a deep cut on their arm from broken glass, bleeding heavily. We have a tourniquet but need medical help.',
    expectedType: 'medical',
    expectedUrgency: 4,
    expectedHazards: {},
  ),
  ExtractionCase(
    description: 'Diabetic emergency',
    input: 'My father is diabetic and is unconscious. He was acting confused earlier and now he is not responding.',
    expectedType: 'medical',
    expectedUrgency: 5,
    expectedHazards: {},
  ),
  ExtractionCase(
    description: 'Child trapped, minor injuries',
    input: 'Child is trapped under a collapsed shelf. She is conscious and crying but cannot move her leg.',
    expectedType: 'medical',
    expectedUrgency: 4,
    expectedHazards: {'trapped_people'},
  ),
  ExtractionCase(
    description: 'Multiple injuries after explosion',
    input: 'There was an explosion in the factory, at least 5 people are injured. Some are unconscious.',
    expectedType: 'medical',
    expectedUrgency: 5,
    expectedHazards: {'trapped_people'},
  ),

  // ── STRUCTURAL ────────────────────────────────────────────────────────────
  ExtractionCase(
    description: 'Building collapse after earthquake',
    input: 'Part of the apartment building collapsed. I can hear people screaming from under the rubble.',
    expectedType: 'structural',
    expectedUrgency: 5,
    expectedHazards: {'structural_collapse', 'trapped_people'},
  ),
  ExtractionCase(
    description: 'Damaged bridge, road blocked',
    input: 'The pedestrian bridge over the river has partially collapsed. No injuries confirmed yet but the road is blocked.',
    expectedType: 'structural',
    expectedUrgency: 3,
    expectedHazards: {'structural_collapse'},
  ),
  ExtractionCase(
    description: 'Wall crack post-earthquake, unstable',
    input: 'Large cracks appeared in the walls after the earthquake. The ceiling is sagging and I am afraid it will collapse.',
    expectedType: 'structural',
    expectedUrgency: 4,
    expectedHazards: {'structural_collapse'},
  ),

  // ── FLOOD ─────────────────────────────────────────────────────────────────
  ExtractionCase(
    description: 'Rapid flooding, people on roof',
    input: 'Water is rising fast, already waist high. Several families are on their rooftops waiting for rescue.',
    expectedType: 'flood',
    expectedUrgency: 5,
    expectedHazards: {'flooding', 'trapped_people'},
  ),
  ExtractionCase(
    description: 'Flooded road, car stuck',
    input: 'Car got stuck in flood water on the main road. Water is at door level. Driver is elderly and scared.',
    expectedType: 'flood',
    expectedUrgency: 4,
    expectedHazards: {'flooding'},
  ),
  ExtractionCase(
    description: 'Basement flooding',
    input: 'Basement is flooding rapidly, power is still on and I am worried about electrocution.',
    expectedType: 'flood',
    expectedUrgency: 4,
    expectedHazards: {'flooding', 'downed_power_lines'},
  ),

  // ── HAZMAT ────────────────────────────────────────────────────────────────
  ExtractionCase(
    description: 'Chemical spill at factory',
    input: 'Large chemical spill at the processing plant. Yellow smoke is coming from the storage tanks. People are coughing.',
    expectedType: 'hazmat',
    expectedUrgency: 5,
    expectedHazards: {'chemical_spill'},
  ),
  ExtractionCase(
    description: 'Gas leak from pipeline',
    input: 'Strong smell of gas near the industrial area, hissing sound from a pipe. We evacuated the nearby houses.',
    expectedType: 'hazmat',
    expectedUrgency: 4,
    expectedHazards: {'gas_leak'},
  ),
  ExtractionCase(
    description: 'Downed power lines after storm',
    input: 'Power lines are down across the road after the storm. Sparks visible. A car is parked very close to them.',
    expectedType: 'hazmat',
    expectedUrgency: 4,
    expectedHazards: {'downed_power_lines'},
  ),

  // ── OTHER / EDGE CASES ────────────────────────────────────────────────────
  ExtractionCase(
    description: 'Person lost in wilderness',
    input: 'I am lost in the forest, my phone is at 5%, I have no food or water. It is getting dark.',
    expectedType: 'other',
    expectedUrgency: 4,
    expectedHazards: {},
  ),
  ExtractionCase(
    description: 'Low urgency informational report',
    input: 'Just reporting that the main road near the school is blocked by a fallen tree. No injuries.',
    expectedType: 'other',
    expectedUrgency: 2,
    expectedHazards: {},
  ),

  // ── URGENCY EDGE CASES ────────────────────────────────────────────────────
  ExtractionCase(
    description: 'Very low urgency — informational',
    input: 'I saw smoke in the distance, maybe a bonfire, nothing alarming.',
    expectedType: 'fire',
    expectedUrgency: 1,
    expectedHazards: {},
  ),
  ExtractionCase(
    description: 'Max urgency — immediate life threat',
    input: 'I am pinned under debris, cannot move, bleeding from head. Please send help immediately.',
    expectedType: 'medical',
    expectedUrgency: 5,
    expectedHazards: {'trapped_people'},
  ),
];
