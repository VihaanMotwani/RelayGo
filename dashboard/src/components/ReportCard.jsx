import { getMarkerColor, TYPE_LABELS } from '../utils/mapStyles';

const urgencyLevel = (u) => {
  if (u >= 4) return { label: 'Critical', bg: 'rgba(255,68,68,0.15)', color: '#FF4444' };
  if (u >= 3) return { label: 'High', bg: 'rgba(255,136,0,0.15)', color: '#FF8800' };
  if (u >= 2) return { label: 'Medium', bg: 'rgba(255,200,0,0.15)', color: '#FFC800' };
  return { label: 'Low', bg: 'rgba(0,204,204,0.15)', color: '#00CCCC' };
};

const styles = {
  card: {
    background: 'rgba(255,255,255,0.03)',
    border: '1px solid rgba(255,255,255,0.06)',
    borderRadius: 10,
    padding: '14px 16px',
    marginBottom: 8,
    transition: 'background 0.15s, border-color 0.15s',
    cursor: 'default',
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
    gap: 8,
  },
  dot: (color) => ({
    width: 8,
    height: 8,
    borderRadius: '50%',
    backgroundColor: color,
    boxShadow: `0 0 6px ${color}66`,
    flexShrink: 0,
  }),
  typeLabel: {
    fontSize: 12,
    fontWeight: 600,
    textTransform: 'uppercase',
    letterSpacing: '0.05em',
    color: 'rgba(255,255,255,0.6)',
  },
  urgencyBadge: (u) => {
    const level = urgencyLevel(u);
    return {
      fontSize: 10,
      fontWeight: 700,
      padding: '3px 8px',
      borderRadius: 6,
      background: level.bg,
      color: level.color,
      letterSpacing: '0.03em',
    };
  },
  description: {
    fontSize: 13,
    lineHeight: 1.5,
    color: 'rgba(255,255,255,0.82)',
    marginBottom: 10,
    wordBreak: 'break-word',
  },
  footer: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    fontSize: 11,
    color: 'rgba(255,255,255,0.35)',
  },
  hops: {
    display: 'flex',
    alignItems: 'center',
    gap: 4,
    fontSize: 11,
    color: 'rgba(255,255,255,0.35)',
  },
};

function formatTime(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  if (isNaN(d.getTime())) return ts;
  const now = new Date();
  const diff = Math.floor((now - d) / 1000);
  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return d.toLocaleDateString();
}

export default function ReportCard({ report }) {
  const type = report.type?.toLowerCase() || 'other';
  const color = getMarkerColor(type);
  const urgency = report.urgency ?? 1;

  return (
    <div
      style={styles.card}
      onMouseEnter={(e) => {
        e.currentTarget.style.background = 'rgba(255,255,255,0.06)';
        e.currentTarget.style.borderColor = 'rgba(255,255,255,0.12)';
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.background = 'rgba(255,255,255,0.03)';
        e.currentTarget.style.borderColor = 'rgba(255,255,255,0.06)';
      }}
    >
      <div style={styles.header}>
        <div style={styles.typeRow}>
          <div style={styles.dot(color)} />
          <span style={styles.typeLabel}>{TYPE_LABELS[type] || type}</span>
        </div>
        <span style={styles.urgencyBadge(urgency)}>
          {urgencyLevel(urgency).label} ({urgency})
        </span>
      </div>
      <div style={styles.description}>
        {report.description || 'No description provided'}
      </div>
      <div style={styles.footer}>
        <span>{formatTime(report.timestamp)}</span>
        <span style={styles.hops}>
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M8 7l4-4 4 4M12 3v13M4 17h16" />
          </svg>
          {report.hop_count ?? report.hops ?? 0} hops
        </span>
      </div>
    </div>
  );
}
