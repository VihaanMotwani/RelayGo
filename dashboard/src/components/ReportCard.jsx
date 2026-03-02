import { getMarkerColor, TYPE_LABELS, TYPE_ICONS } from '../utils/mapStyles';

const urgencyMeta = (u) => {
  if (u >= 4) return { label: 'CRITICAL', color: '#FF4444', bg: 'rgba(255,68,68,0.12)' };
  if (u >= 3) return { label: 'HIGH', color: '#FFA843', bg: 'rgba(255,168,67,0.12)' };
  if (u >= 2) return { label: 'MEDIUM', color: '#FFB832', bg: 'rgba(255,184,50,0.10)' };
  return { label: 'LOW', color: '#64748B', bg: 'rgba(100,116,139,0.10)' };
};

function formatTime(ts) {
  if (!ts) return '';
  const val = typeof ts === 'number' && ts < 1e12 ? ts * 1000 : ts;
  const d = new Date(val);
  if (isNaN(d.getTime())) return String(ts);
  const now = new Date();
  const diff = Math.floor((now - d) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return d.toLocaleDateString();
}

export default function ReportCard({ report, style: extraStyle }) {
  const type = report.type?.toLowerCase() || 'other';
  const color = getMarkerColor(type);
  const icon = TYPE_ICONS[type] || '⚠';
  const urgency = report.urgency ?? report.urg ?? 1;
  const meta = urgencyMeta(urgency);
  const desc = report.description || report.desc || 'No description provided';
  const hops = report.hop_count ?? report.hops ?? 0;
  const ts = report.timestamp || (report.ts ? report.ts : null);

  return (
    <div
      style={{ ...styles.card, ...extraStyle, animation: 'fadeSlideUp 0.35s ease-out both' }}
      onMouseEnter={(e) => {
        e.currentTarget.style.background = 'var(--bg-card-hover)';
        e.currentTarget.style.borderColor = `${color}25`;
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.background = 'var(--bg-card)';
        e.currentTarget.style.borderColor = 'var(--border-subtle)';
      }}
    >
      {/* Top bar with colored accent */}
      <div style={{ ...styles.accentBar, background: `linear-gradient(90deg, ${color}, transparent)` }} />

      <div style={styles.header}>
        <div style={styles.typeRow}>
          <span style={{ fontSize: 14 }}>{icon}</span>
          <span style={{ ...styles.typeLabel, color }}>{TYPE_LABELS[type] || type}</span>
        </div>
        <span style={{
          ...styles.urgencyBadge,
          background: meta.bg,
          color: meta.color,
          border: `1px solid ${meta.color}20`,
        }}>
          {meta.label}
        </span>
      </div>

      <div style={styles.description}>{desc}</div>

      <div style={styles.footer}>
        <span style={styles.footerItem}>
          {formatTime(ts)}
        </span>
        <div style={styles.footerRight}>
          <span style={styles.footerItem}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
              <path d="M8 7l4-4 4 4M12 3v13M4 17h16" />
            </svg>
            {hops}
          </span>
          <span style={styles.urgencyNum}>U{urgency}</span>
        </div>
      </div>
    </div>
  );
}

const styles = {
  card: {
    position: 'relative',
    background: 'var(--bg-card)',
    border: '1px solid var(--border-subtle)',
    borderRadius: 'var(--radius-md)',
    padding: '12px 14px',
    marginBottom: 8,
    transition: 'all 0.18s ease',
    cursor: 'default',
    overflow: 'hidden',
  },
  accentBar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 2,
    opacity: 0.6,
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  typeRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 7,
  },
  typeLabel: {
    fontSize: 11,
    fontWeight: 700,
    fontFamily: 'var(--font-mono)',
    textTransform: 'uppercase',
    letterSpacing: '0.06em',
  },
  urgencyBadge: {
    fontSize: 9,
    fontWeight: 700,
    fontFamily: 'var(--font-mono)',
    padding: '2px 7px',
    borderRadius: 4,
    letterSpacing: '0.06em',
  },
  description: {
    fontSize: 12.5,
    lineHeight: 1.55,
    color: 'rgba(255,255,255,0.72)',
    marginBottom: 10,
    wordBreak: 'break-word',
    fontFamily: 'var(--font-display)',
  },
  footer: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    fontSize: 10,
    fontFamily: 'var(--font-mono)',
    color: 'rgba(255,255,255,0.28)',
  },
  footerRight: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
  },
  footerItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 4,
  },
  urgencyNum: {
    fontWeight: 700,
    color: 'rgba(255,255,255,0.2)',
    fontSize: 9,
  },
};
