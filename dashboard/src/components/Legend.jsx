import { TYPE_COLORS, TYPE_LABELS, TYPE_ICONS } from '../utils/mapStyles';

export default function Legend() {
  return (
    <div style={styles.container}>
      <div style={styles.title}>
        <span style={styles.titleIcon}>◇</span>
        CLASSIFICATION
      </div>
      <div style={styles.grid}>
        {Object.entries(TYPE_COLORS).map(([type, color]) => (
          <div key={type} style={styles.row}>
            <div style={{
              ...styles.dot,
              backgroundColor: color,
              boxShadow: `0 0 8px ${color}44`,
            }} />
            <span style={styles.icon}>{TYPE_ICONS[type] || '⚠'}</span>
            <span style={styles.label}>{TYPE_LABELS[type] || type}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

const styles = {
  container: {
    position: 'absolute',
    bottom: 20,
    left: 20,
    background: 'var(--bg-panel)',
    backdropFilter: 'blur(20px) saturate(1.4)',
    borderRadius: 'var(--radius-md)',
    padding: '12px 16px',
    border: '1px solid var(--border-subtle)',
    boxShadow: 'var(--shadow-panel)',
    zIndex: 10,
    animation: 'fadeSlideUp 0.5s ease-out 0.2s both',
  },
  title: {
    display: 'flex',
    alignItems: 'center',
    gap: 6,
    fontSize: 9,
    fontWeight: 700,
    fontFamily: 'var(--font-mono)',
    textTransform: 'uppercase',
    letterSpacing: '0.14em',
    color: 'rgba(255,255,255,0.35)',
    marginBottom: 10,
  },
  titleIcon: {
    color: 'var(--amber-dim)',
    fontSize: 8,
  },
  grid: {
    display: 'flex',
    flexDirection: 'column',
    gap: 5,
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: 7,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: '50%',
    flexShrink: 0,
  },
  icon: {
    fontSize: 11,
    width: 16,
    textAlign: 'center',
  },
  label: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.6)',
    fontFamily: 'var(--font-display)',
    fontWeight: 500,
  },
};
