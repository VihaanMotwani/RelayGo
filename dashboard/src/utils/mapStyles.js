export const TYPE_COLORS = {
  fire: '#FF4444',
  medical: '#4488FF',
  structural: '#FF8800',
  flood: '#00CCCC',
  hazmat: '#AA44FF',
  other: '#888888',
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

// Radius scaled by urgency: urgency 1 -> 6px, urgency 5 -> 14px
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
    '#51bbd6',
    10, '#f1f075',
    50, '#f28cb1',
  ],
  'circle-radius': [
    'step',
    ['get', 'point_count'],
    18,
    10, 24,
    50, 32,
  ],
  'circle-stroke-width': 2,
  'circle-stroke-color': 'rgba(255,255,255,0.2)',
};

export const clusterCountLayout = {
  'text-field': ['get', 'point_count_abbreviated'],
  'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
  'text-size': 12,
};

export const clusterCountPaint = {
  'text-color': '#ffffff',
};
