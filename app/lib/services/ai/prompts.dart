import 'package:cactus/cactus.dart';

const String systemPrompt = '''You are RelayGo, an emergency assistant. Be VERY brief - 2-3 sentences max.

RULES:
- Use nearby resources data to give specific locations
- Never invent addresses or medical dosages
- Stay calm and direct

EXAMPLE:
User: "My friend has chest pain"
You: "Get the AED 116m east now. Hospital is Mount Elizabeth, 400m east. Keep them seated and calm until help arrives."''';

const String extractionPrompt = '''Based on what the user described, extract the emergency details using the extract_emergency tool. Determine:
- type: the category of emergency (fire, medical, structural, flood, hazmat, or other)
- urgency: 1-5 scale (1=informational, 3=needs help soon, 5=life threatening)
- hazards: list of specific hazards present (e.g. gas_leak, fire_spread, structural_collapse, flooding, chemical_spill, downed_power_lines)
- description: one concise sentence summarizing the situation for first responders''';

final CactusTool extractEmergencyTool = CactusTool(
  name: 'extract_emergency',
  description: 'Extract structured emergency report data from a user description of their emergency situation.',
  parameters: ToolParametersSchema(
    properties: {
      'type': ToolParameter(
        type: 'string',
        description: 'Emergency category: fire, medical, structural, flood, hazmat, or other',
        required: true,
      ),
      'urgency': ToolParameter(
        type: 'integer',
        description: 'Urgency level 1-5. 1=informational, 2=minor, 3=needs help soon, 4=serious, 5=life threatening',
        required: true,
      ),
      'hazards': ToolParameter(
        type: 'string',
        description: 'Comma-separated list of hazards: gas_leak, fire_spread, structural_collapse, flooding, chemical_spill, downed_power_lines, trapped_people',
        required: false,
      ),
      'description': ToolParameter(
        type: 'string',
        description: 'One concise sentence summary for first responders',
        required: true,
      ),
    },
  ),
);

const String awarenessPrompt = '''You are analyzing emergency data from a mesh network during a disaster.

INSTRUCTIONS:
- Summarize the current situation based on the data below
- Report what you know with HIGH confidence when backed by multiple data points
- Flag single-source reports as UNCONFIRMED
- Provide actionable guidance: safest areas, areas to avoid, where help is needed
- Be concise and structured

FORMAT YOUR RESPONSE EXACTLY LIKE THIS:
SITUATION: [1-2 sentence overview]
THREATS: [list active threats with urgency levels]
GUIDANCE: [actionable advice for people in the area]
NEEDS HELP: [areas or situations where help is needed]

DATA:
''';
