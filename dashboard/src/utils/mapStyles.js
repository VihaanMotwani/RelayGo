export const TYPE_COLORS = {
  fire: '#FF5C38',
  medical: '#38BDF8',
  structural: '#FFA843',
  flood: '#22D3EE',
  hazmat: '#C084FC',
  other: '#64748B',
};

export const TYPE_LABELS = {
  fire: 'Fire',
  medical: 'Medical',
  structural: 'Structural',
  flood: 'Flood',
  hazmat: 'Hazmat',
  other: 'Other',
};

export const TYPE_ICONS = {
  fire: '🔥',
  medical: '🏥',
  structural: '🏗',
  flood: '🌊',
  hazmat: '☢',
  other: '⚠',
};

export function getMarkerColor(type) {
  return TYPE_COLORS[type?.toLowerCase()] || TYPE_COLORS.other;
}

// Mapbox match expression for coloring circles by emergency type
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

// Radius scaled by urgency: urgency 1 -> 6px, urgency 5 -> 16px
export const radiusExpression = [
  'interpolate',
  ['linear'],
  ['get', 'urgency'],
  1, 7,
  5, 16,
];

export const clusterPaint = {
  'circle-color': [
    'step',
    ['get', 'point_count'],
    '#FFB832',
    10, '#FF8800',
    50, '#FF5C38',
  ],
  'circle-radius': [
    'step',
    ['get', 'point_count'],
    20,
    10, 28,
    50, 36,
  ],
  'circle-stroke-width': 2,
  'circle-stroke-color': 'rgba(255, 184, 50, 0.2)',
  'circle-opacity': 0.85,
};

export const clusterCountLayout = {
  'text-field': ['get', 'point_count_abbreviated'],
  'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
  'text-size': 13,
};

export const clusterCountPaint = {
  'text-color': '#0a0c10',
};
