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

export const radiusExpression = [
  'interpolate',
  ['linear'],
  ['get', 'urgency'],
  1, 6,
  5, 14,
];

export const clusterPaint = {
  'circle-color': [
    'step',
    ['get', 'point_count'],
    '#0a84ff',
    10, '#ff9f0a',
    50, '#ff453a',
  ],
  'circle-radius': [
    'step',
    ['get', 'point_count'],
    18,
    10, 24,
    50, 32,
  ],
  'circle-stroke-width': 1.5,
  'circle-stroke-color': 'rgba(255,255,255,0.12)',
  'circle-opacity': 0.9,
};

export const clusterCountLayout = {
  'text-field': ['get', 'point_count_abbreviated'],
  'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
  'text-size': 12,
};

export const clusterCountPaint = {
  'text-color': '#ffffff',
};
