import { TYPE_COLORS, TYPE_LABELS } from '../utils/mapStyles';

export default function Legend() {
  return (
    <div style={s.container}>
      <div style={s.title}>Incident Types</div>
      <div style={s.grid}>
        {Object.entries(TYPE_COLORS).map(([type, color]) => (
          <div key={type} style={s.row}>
            <div style={{ ...s.dot, background: color }} />
            <span style={s.label}>{TYPE_LABELS[type] || type}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

const s = {
  container: {
    padding: '10px 14px 12px',
    borderTop: '0.5px solid var(--separator)',
    flexShrink: 0,
  },
  title: {
    fontSize: 10,
    fontWeight: 600,
    textTransform: 'uppercase',
    letterSpacing: '0.04em',
    color: 'var(--text-tertiary)',
    marginBottom: 6,
  },
  grid: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '3px 14px',
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: 5,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: '50%',
    flexShrink: 0,
  },
  label: {
    fontSize: 11,
    color: 'var(--text-secondary)',
    fontWeight: 400,
  },
};
