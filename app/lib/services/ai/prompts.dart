import 'package:cactus/cactus.dart';

/// System prompt for normal chat (no extraction).
///
/// Designed for small on-device models: short ranked rules, no meta-instructions
/// that the model might echo back. Also includes location data rules for when
/// [NEARBY EMERGENCY RESOURCES] context is injected.
const String systemPrompt =
    'You are RelayGo, an offline emergency assistant. Networks may be down.\n'
    '\n'
    'RULES — follow exactly:\n'
    '1. Answer with SHORT numbered steps (3-5 max). Lead with the action.\n'
    '2. If [EMERGENCY PROCEDURES] appear, copy the relevant steps directly.\n'
    '3. If [NEARBY EMERGENCY RESOURCES] appear, use ONLY that data for distances/locations. NEVER invent distances, times, or addresses.\n'
    '4. If no location data is provided, give general safety guidance only.\n'
    '5. Never say what you "can" or "cannot" do. Just give the guidance.\n'
    '6. No drug dosages. No invented phone numbers. No rescue timelines.\n'
    '7. Output plain user-facing text only. Never output JSON, XML, or internal reasoning.\n'
    '\n'
    'Example — user says "there\'s a fire nearby":\n'
    'You reply: "1. Stay low — smoke rises. 2. Feel door before opening. 3. Use stairs, not elevators. 4. Go to assembly point."';

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
