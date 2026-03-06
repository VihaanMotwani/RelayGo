import { getMarkerColor, TYPE_LABELS } from '../utils/mapStyles';

const urgLabel = (u) => {
  if (u >= 4) return 'Critical';
  if (u >= 3) return 'High';
  if (u >= 2) return 'Medium';
  return 'Low';
};

const urgColor = (u) => {
  if (u >= 4) return 'var(--red)';
  if (u >= 3) return 'var(--orange)';
  if (u >= 2) return 'var(--tint)';
  return 'var(--gray)';
};

const urgBg = (u) => {
  if (u >= 4) return 'rgba(200, 50, 40, 0.04)';
  if (u >= 3) return 'rgba(200, 120, 0, 0.035)';
  return 'transparent';
};

function formatTime(ts) {
  if (!ts) return '';
  const val = typeof ts === 'number' && ts < 1e12 ? ts * 1000 : ts;
  const d = new Date(val);
  if (isNaN(d.getTime())) return String(ts);
  const now = new Date();
  const diff = Math.floor((now - d) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export default function ReportCard({ report, isFocused, onClick }) {
  const type = report.type?.toLowerCase() || 'other';
  const color = getMarkerColor(type);
  const urgency = report.urgency ?? report.urg ?? 1;
  const desc = report.description || report.desc || 'No description';
  const hops = report.hop_count ?? report.hops ?? 0;
  const ts = report.timestamp || (report.ts ? report.ts : null);

  return (
    <div
      style={{
        ...s.row,
        background: isFocused ? 'var(--bg-row-selected)' : urgBg(urgency),
        border: isFocused ? '1px solid var(--tint)' : '1px solid transparent',
        margin: isFocused ? '0 0 1px 0' : '1px 0',
      }}
      onClick={onClick}
      onMouseEnter={(e) => {
        if (!isFocused) {
          e.currentTarget.style.background = urgency >= 3 ? urgBg(urgency) : 'var(--bg-row-hover)';
        }
      }}
      onMouseLeave={(e) => {
        if (!isFocused) {
          e.currentTarget.style.background = urgBg(urgency);
        }
      }}
    >
      {/* Color indicator */}
      <div style={{ ...s.indicator, background: color, width: urgency >= 4 ? 4 : 3 }} />

      {/* Content */}
      <div style={s.content}>
        <div style={s.topRow}>
          <span style={s.type}>{TYPE_LABELS[type] || type}</span>
          <span style={{ ...s.urgency, color: urgColor(urgency) }}>
            {urgLabel(urgency)}
          </span>
        </div>
        <div style={s.desc}>{desc}</div>
        <div style={s.meta}>
          <span>{formatTime(ts)}</span>
          <span>·</span>
          <span>{hops} hop{hops !== 1 ? 's' : ''}</span>
        </div>
      </div>
    </div>
  );
}

const s = {
  row: {
    display: 'flex',
    alignItems: 'stretch',
    padding: '8px 6px',
    borderRadius: 6,
    cursor: 'default',
    transition: 'background 0.1s',
    gap: 10,
    marginBottom: 1,
  },
  indicator: {
    width: 3,
    borderRadius: 1.5,
    flexShrink: 0,
    alignSelf: 'stretch',
  },
  content: {
    flex: 1,
    minWidth: 0,
  },
  topRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 2,
  },
  type: {
    fontSize: 13,
    fontWeight: 700,
    color: 'var(--text-primary)',
  },
  urgency: {
    fontSize: 10,
    fontWeight: 600,
    fontFamily: 'var(--mono)',
  },
  desc: {
    fontSize: 12,
    color: 'var(--text-primary)',
    lineHeight: 1.4,
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  meta: {
    display: 'flex',
    gap: 4,
    fontSize: 10,
    color: 'var(--text-secondary)',
    marginTop: 2,
    fontFamily: 'var(--mono)',
  },
};
