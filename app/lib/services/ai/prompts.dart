import 'package:cactus/cactus.dart';

/// System prompt for normal chat (no extraction).
///
/// Designed for small on-device models: short ranked rules, no meta-instructions
/// that the model might echo back. Also includes location data rules for when
/// [NEARBY EMERGENCY RESOURCES] context is injected.
const String systemPrompt =
    'You are an emergency assistant. The user is reporting an emergency.\n'
    '\n'
    'CRITICAL RULES:\n'
    '1. TRUST the user - if they say "fire", "earthquake", "injured", etc., respond AS IF IT IS HAPPENING RIGHT NOW.\n'
    '2. Give IMMEDIATE action steps (3-5 max). Start each with a number. Be direct.\n'
    '3. If [EMERGENCY PROCEDURES] appear below, use those exact steps.\n'
    '4. If [NEARBY EMERGENCY RESOURCES] appear, include the closest 2-3 with distances.\n'
    '5. NEVER suggest the user is imagining it or feeling anxious. NEVER say "you are not experiencing [emergency]".\n'
    '6. No explanations. No questions. Just the steps to stay safe RIGHT NOW.\n'
    '7. Plain text only - NO asterisks, NO ** for bold, NO markdown, NO formatting symbols.\n'
    '\n'
    'Example:\n'
    'User: "I felt an earthquake"\n'
    'You: "1. Drop, cover, hold on. 2. Stay away from windows. 3. When shaking stops, check for injuries. 4. Exit if safe."\n'
    '\n'
    'WRONG: "**Drop** to the ground"\n'
    'RIGHT: "Drop to the ground"';

/// Appended to the system prompt ONLY when the intent filter detects an
/// active emergency. Instructs the model to call the extraction tool silently.
///
/// Placed BEFORE the RAG context so the small model sees it early.
const String extractionPrompt =
    'CALL extract_emergency now based on what the user described.\n'
    'This call is automatic — do not tell the user about it, do not ask permission.\n'
    'After the tool call, give the user emergency guidance using the steps below.';

/// Tool definition for structured emergency data extraction.
final CactusTool extractEmergencyTool = CactusTool(
  name: 'extract_emergency',
  description:
      'Extract structured data from a user description of their emergency.',
  parameters: ToolParametersSchema(
    properties: {
      'type': ToolParameter(
        type: 'string',
        description:
            'Emergency category: fire, medical, structural, flood, hazmat, or other',
        required: true,
      ),
      'urgency': ToolParameter(
        type: 'integer',
        description:
            'Urgency 1-5. 1=informational, 2=minor, 3=needs help soon, 4=serious, 5=life threatening',
        required: true,
      ),
      'hazards': ToolParameter(
        type: 'string',
        description:
            'Comma-separated hazards: gas_leak, fire_spread, structural_collapse, flooding, chemical_spill, downed_power_lines, trapped_people',
        required: false,
      ),
      'description': ToolParameter(
        type: 'string',
        description: 'One sentence summary for first responders',
        required: true,
      ),
    },
  ),
);

/// Prompt for generating disaster awareness summaries from mesh network data.
const String awarenessPrompt =
    'You are analyzing emergency data from a mesh network during a disaster.\n'
    '\n'
    'INSTRUCTIONS:\n'
    '- Summarize the situation from the data below\n'
    '- Flag single-source reports as UNCONFIRMED\n'
    '- Be concise and actionable\n'
    '\n'
    'FORMAT EXACTLY:\n'
    'SITUATION: [1-2 sentences]\n'
    'THREATS: [list active threats with urgency]\n'
    'GUIDANCE: [what people should do]\n'
    'NEEDS HELP: [areas or situations needing assistance]\n'
    '\n'
    'DATA:\n';
