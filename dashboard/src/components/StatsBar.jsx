import { TYPE_COLORS, TYPE_LABELS } from '../utils/mapStyles';

const styles = {
  bar: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '0 24px',
    height: 56,
    background: 'rgba(255,255,255,0.02)',
    borderBottom: '1px solid rgba(255,255,255,0.06)',
    flexShrink: 0,
  },
  left: {
    display: 'flex',
    alignItems: 'center',
    gap: 28,
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
  },
  logo: {
    fontSize: 18,
    fontWeight: 800,
    color: '#fff',
    letterSpacing: '-0.02em',
  },
  logoAccent: {
    color: '#4488FF',
  },
  divider: {
    width: 1,
    height: 24,
    background: 'rgba(255,255,255,0.1)',
  },
  stat: {
    display: 'flex',
    alignItems: 'center',
    gap: 6,
  },
  statValue: {
    fontSize: 18,
    fontWeight: 700,
    color: '#fff',
  },
  statLabel: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.4)',
    textTransform: 'uppercase',
    letterSpacing: '0.06em',
  },
  right: {
    display: 'flex',
    alignItems: 'center',
    gap: 20,
  },
  pills: {
    display: 'flex',
    gap: 6,
    flexWrap: 'wrap',
  },
  pill: (color) => ({
    display: 'inline-flex',
    alignItems: 'center',
    gap: 5,
    padding: '3px 10px',
    borderRadius: 20,
    background: `${color}18`,
    border: `1px solid ${color}30`,
    fontSize: 11,
    fontWeight: 600,
    color: color,
  }),
  pillDot: (color) => ({
    width: 6,
    height: 6,
    borderRadius: '50%',
    backgroundColor: color,
  }),
  connection: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    fontSize: 12,
    color: 'rgba(255,255,255,0.5)',
  },
  statusDot: (connected) => ({
    width: 8,
    height: 8,
    borderRadius: '50%',
    backgroundColor: connected ? '#22c55e' : '#ef4444',
    boxShadow: connected ? '0 0 8px #22c55e66' : '0 0 8px #ef444466',
  }),
};

export default function StatsBar({ reports, connected }) {
  const typeCounts = {};
  let totalHops = 0;
  let hopsCount = 0;

  reports.forEach((r) => {
    const t = r.type?.toLowerCase() || 'other';
    typeCounts[t] = (typeCounts[t] || 0) + 1;
    const h = r.hop_count ?? r.hops;
    if (h != null) {
      totalHops += h;
      hopsCount++;
    }
  });

  const avgHops = hopsCount > 0 ? (totalHops / hopsCount).toFixed(1) : '0';

  return (
    <div style={styles.bar}>
      <div style={styles.left}>
        <div style={styles.brand}>
          <span style={styles.logo}>
            Relay<span style={styles.logoAccent}>Go</span>
          </span>
        </div>
        <div style={styles.divider} />
        <div style={styles.stat}>
          <span style={styles.statValue}>{reports.length}</span>
          <span style={styles.statLabel}>Reports</span>
        </div>
        <div style={styles.stat}>
          <span style={styles.statValue}>{avgHops}</span>
          <span style={styles.statLabel}>Avg Hops</span>
        </div>
      </div>
      <div style={styles.right}>
        <div style={styles.pills}>
          {Object.entries(typeCounts).map(([type, count]) => {
            const color = TYPE_COLORS[type] || TYPE_COLORS.other;
            return (
              <span key={type} style={styles.pill(color)}>
                <span style={styles.pillDot(color)} />
                {TYPE_LABELS[type] || type} {count}
              </span>
            );
          })}
        </div>
        <div style={styles.divider} />
        <div style={styles.connection}>
          <div style={styles.statusDot(connected)} />
          {connected ? 'Connected' : 'Disconnected'}
        </div>
      </div>
    </div>
  );
}
