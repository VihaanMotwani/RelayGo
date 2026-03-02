import { TYPE_COLORS, TYPE_LABELS, TYPE_ICONS } from '../utils/mapStyles';

export default function StatsBar({ reports, connected }) {
  const typeCounts = {};
  let totalHops = 0;
  let hopsCount = 0;
  let maxUrg = 0;

  reports.forEach((r) => {
    const t = r.type?.toLowerCase() || 'other';
    typeCounts[t] = (typeCounts[t] || 0) + 1;
    const h = r.hop_count ?? r.hops;
    if (h != null) { totalHops += h; hopsCount++; }
    const u = r.urgency ?? r.urg ?? 0;
    if (u > maxUrg) maxUrg = u;
  });

  const avgHops = hopsCount > 0 ? (totalHops / hopsCount).toFixed(1) : '—';
  const threatLevel = maxUrg >= 4 ? 'CRITICAL' : maxUrg >= 3 ? 'ELEVATED' : maxUrg >= 2 ? 'GUARDED' : 'NOMINAL';
  const threatColor = maxUrg >= 4 ? 'var(--red-alert)' : maxUrg >= 3 ? 'var(--amber)' : maxUrg >= 2 ? '#FFA843' : 'var(--green-ok)';

  return (
    <div style={styles.bar}>
      {/* Brand */}
      <div style={styles.left}>
        <div style={styles.brand}>
          <div style={styles.sigil}>◇</div>
          <div>
            <span style={styles.logo}>RELAY</span>
            <span style={styles.logoAccent}>GO</span>
          </div>
        </div>

        <div style={styles.divider} />

        {/* Stats */}
        <div style={styles.statsGroup}>
          <Stat value={reports.length} label="INCIDENTS" />
          <Stat value={avgHops} label="AVG HOPS" />
          <Stat value={Object.keys(typeCounts).length} label="TYPES" />
        </div>
      </div>

      {/* Right */}
      <div style={styles.right}>
        {/* Active type pills */}
        <div style={styles.pills}>
          {Object.entries(typeCounts).map(([type, count]) => {
            const color = TYPE_COLORS[type] || TYPE_COLORS.other;
            const icon = TYPE_ICONS[type] || '⚠';
            return (
              <span key={type} style={pill(color)}>
                <span style={{ fontSize: 10 }}>{icon}</span>
                {TYPE_LABELS[type] || type}
                <span style={pillCount(color)}>{count}</span>
              </span>
            );
          })}
        </div>

        <div style={styles.divider} />

        {/* Threat level */}
        <div style={{ ...styles.threatBadge, borderColor: `${threatColor}30`, background: `${threatColor}10` }}>
          <span style={{ ...styles.threatDot, backgroundColor: threatColor, boxShadow: `0 0 8px ${threatColor}66` }} />
          <span style={{ color: threatColor, fontWeight: 700, fontSize: 10, letterSpacing: '0.1em' }}>{threatLevel}</span>
        </div>

        <div style={styles.divider} />

        {/* Connection */}
        <div style={styles.connection}>
          <div style={{
            ...styles.statusDot,
            backgroundColor: connected ? 'var(--green-ok)' : 'var(--red-alert)',
            boxShadow: connected ? '0 0 8px var(--green-glow)' : '0 0 8px var(--red-glow)',
            animation: connected ? 'pulseGlow 2s infinite ease-in-out' : 'none',
          }} />
          <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: connected ? 'var(--green-ok)' : 'var(--red-alert)' }}>
            {connected ? 'ONLINE' : 'OFFLINE'}
          </span>
        </div>
      </div>
    </div>
  );
}

function Stat({ value, label }) {
  return (
    <div style={styles.stat}>
      <span style={styles.statValue}>{value}</span>
      <span style={styles.statLabel}>{label}</span>
    </div>
  );
}

const pill = (color) => ({
  display: 'inline-flex',
  alignItems: 'center',
  gap: 5,
  padding: '4px 10px',
  borderRadius: 6,
  background: `${color}0D`,
  border: `1px solid ${color}22`,
  fontSize: 11,
  fontWeight: 600,
  fontFamily: 'var(--font-display)',
  color: `${color}CC`,
  letterSpacing: '0.02em',
  transition: 'all 0.2s',
});

const pillCount = (color) => ({
  fontFamily: 'var(--font-mono)',
  fontSize: 10,
  fontWeight: 700,
  color,
  marginLeft: 2,
});

const styles = {
  bar: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '0 20px',
    height: 52,
    background: 'var(--bg-panel)',
    backdropFilter: 'blur(20px) saturate(1.4)',
    borderBottom: '1px solid var(--border-subtle)',
    flexShrink: 0,
    zIndex: 20,
    position: 'relative',
  },
  left: {
    display: 'flex',
    alignItems: 'center',
    gap: 20,
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
  },
  sigil: {
    fontSize: 18,
    color: 'var(--amber)',
    fontWeight: 300,
    opacity: 0.8,
  },
  logo: {
    fontSize: 16,
    fontWeight: 800,
    color: '#fff',
    letterSpacing: '0.06em',
    fontFamily: 'var(--font-display)',
  },
  logoAccent: {
    color: 'var(--amber)',
    fontWeight: 800,
  },
  divider: {
    width: 1,
    height: 22,
    background: 'var(--border-subtle)',
  },
  statsGroup: {
    display: 'flex',
    alignItems: 'center',
    gap: 20,
  },
  stat: {
    display: 'flex',
    alignItems: 'baseline',
    gap: 6,
  },
  statValue: {
    fontSize: 16,
    fontWeight: 700,
    fontFamily: 'var(--font-mono)',
    color: '#fff',
  },
  statLabel: {
    fontSize: 9,
    fontWeight: 600,
    color: 'rgba(255,255,255,0.3)',
    textTransform: 'uppercase',
    letterSpacing: '0.1em',
    fontFamily: 'var(--font-mono)',
  },
  right: {
    display: 'flex',
    alignItems: 'center',
    gap: 16,
  },
  pills: {
    display: 'flex',
    gap: 6,
    flexWrap: 'wrap',
  },
  threatBadge: {
    display: 'flex',
    alignItems: 'center',
    gap: 6,
    padding: '4px 10px',
    borderRadius: 6,
    border: '1px solid',
    fontFamily: 'var(--font-mono)',
  },
  threatDot: {
    width: 6,
    height: 6,
    borderRadius: '50%',
  },
  connection: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
  },
  statusDot: {
    width: 7,
    height: 7,
    borderRadius: '50%',
    transition: 'all 0.3s',
  },
};
