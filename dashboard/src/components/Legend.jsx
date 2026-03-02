import { TYPE_COLORS, TYPE_LABELS } from '../utils/mapStyles';

const styles = {
  container: {
    position: 'absolute',
    bottom: 24,
    left: 24,
    background: 'rgba(15, 15, 26, 0.9)',
    backdropFilter: 'blur(12px)',
    borderRadius: 10,
    padding: '14px 18px',
    border: '1px solid rgba(255,255,255,0.08)',
    zIndex: 10,
  },
  title: {
    fontSize: 11,
    fontWeight: 600,
    textTransform: 'uppercase',
    letterSpacing: '0.08em',
    color: 'rgba(255,255,255,0.45)',
    marginBottom: 10,
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    marginBottom: 6,
  },
  dot: (color) => ({
    width: 10,
    height: 10,
    borderRadius: '50%',
    backgroundColor: color,
    boxShadow: `0 0 6px ${color}55`,
    flexShrink: 0,
  }),
  label: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.7)',
  },
};

export default function Legend() {
  return (
    <div style={styles.container}>
      <div style={styles.title}>Emergency Types</div>
      {Object.entries(TYPE_COLORS).map(([type, color]) => (
        <div key={type} style={styles.row}>
          <div style={styles.dot(color)} />
          <span style={styles.label}>{TYPE_LABELS[type] || type}</span>
        </div>
      ))}
    </div>
  );
}
