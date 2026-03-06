export const TYPE_COLORS = {
  fire: '#ff453a',
  medical: '#0a84ff',
  structural: '#ff9f0a',
  flood: '#64d2ff',
  hazmat: '#bf5af2',
  other: '#636366',
};

export const TYPE_LABELS = {
  fire: 'Fire',
  medical: 'Medical',
  structural: 'Structural',
  flood: 'Flood',
  hazmat: 'Hazmat',
  other: 'Other',
};

export const TYPE_CODES = {
  fire: 'FIR',
  medical: 'MED',
  structural: 'STR',
  flood: 'FLD',
  hazmat: 'HAZ',
  other: 'OTH',
};

export function getMarkerColor(type) {
  return TYPE_COLORS[type?.toLowerCase()] || TYPE_COLORS.other;
}

export const colorMatchExpression = [
  'match',
  ['get', 'type'],
  'fire', TYPE_COLORS.fire,
  'medical', TYPE_COLORS.medical,
  'structural', TYPE_COLORS.structural,
  'flood', TYPE_COLORS.flood,
  'hazmat', TYPE_COLORS.hazmat,
  TYPE_COLORS.other,
];
