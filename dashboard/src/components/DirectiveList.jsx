const PRIO_COLORS = {
  high: 'var(--red)',
  medium: 'var(--orange)',
  low: 'var(--green)',
};

const PRIO_BG = {
  high: 'rgba(200, 50, 40, 0.04)',
  medium: 'rgba(200, 120, 0, 0.035)',
  low: 'transparent',
};

function formatTime(ts) {
  if (!ts) return '';
  const val = typeof ts === 'number' && ts < 1e12 ? ts * 1000 : ts;
  const d = new Date(val);
  if (isNaN(d.getTime())) return String(ts);
  const diff = Math.floor((Date.now() - d) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export default function DirectiveList({ directives }) {
  const sorted = [...directives].sort((a, b) => {
    const ta = a.ts || 0;
    const tb = b.ts || 0;
    return tb - ta;
  });

  return (
    <div style={s.container}>
      <div style={s.header}>
        <div style={s.headerTop}>
          <span style={s.headerLabel}>Directives Sent</span>
          <span style={s.headerCount}>{directives.length}</span>
        </div>
      </div>

      <div style={s.list}>
        {sorted.length === 0 ? (
          <div style={s.empty}>
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.2 }}>
              <path d="M22 2L11 13" />
              <path d="M22 2L15 22L11 13L2 9L22 2Z" />
            </svg>
            <span style={s.emptyText}>No Directives Sent</span>
            <span style={s.emptyHint}>Use the panel below to send instructions to people in the disaster zone via the mesh network.</span>
          </div>
        ) : (
          sorted.map((d, idx) => (
            <DirectiveCard key={d.id || idx} directive={d} />
          ))
        )}
      </div>
    </div>
  );
}

function DirectiveCard({ directive }) {
  const prio = directive.priority || 'medium';
  const prioColor = PRIO_COLORS[prio] || PRIO_COLORS.medium;

  return (
    <div style={{ ...s.card, background: PRIO_BG[prio] }}>
      {/* Left accent bar */}
      <div style={{ ...s.accent, background: prioColor }} />

      <div style={s.cardContent}>
        <div style={s.cardTop}>
          <div style={s.badge}>
            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor" style={{ color: prioColor }}>
              <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z" />
            </svg>
            <span style={{ ...s.badgeText, color: prioColor }}>
              {prio.toUpperCase()}
            </span>
          </div>
          <span style={s.cardTime}>{formatTime(directive.ts)}</span>
        </div>

        <div style={s.cardName}>{directive.name}</div>
        <div style={s.cardBody}>{directive.body}</div>

        <div style={s.cardMeta}>
          <span>TTL {directive.ttl || 15}</span>
          <span>·</span>
          <span>{directive.hops || 0} hops</span>
        </div>
      </div>
    </div>
  );
}

const s = {
  container: {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    overflow: 'hidden',
  },
  header: {
    padding: '14px 14px 8px',
    flexShrink: 0,
  },
  headerTop: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  headerLabel: {
    fontSize: 11,
    fontWeight: 700,
    color: 'var(--text-secondary)',
    textTransform: 'uppercase',
    letterSpacing: '0.04em',
  },
  headerCount: {
    fontSize: 11,
    fontWeight: 500,
    fontFamily: 'var(--mono)',
    color: 'var(--text-tertiary)',
  },
  list: {
    flex: 1,
    overflowY: 'auto',
    padding: '0 8px 8px',
  },
  empty: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '40px 20px',
    gap: 6,
  },
  emptyText: {
    fontSize: 13,
    fontWeight: 600,
    color: 'var(--text-secondary)',
  },
  emptyHint: {
    fontSize: 11,
    color: 'var(--text-tertiary)',
    textAlign: 'center',
    lineHeight: 1.5,
  },
  card: {
    display: 'flex',
    alignItems: 'stretch',
    padding: '8px 6px',
    borderRadius: 6,
    gap: 10,
    marginBottom: 1,
    transition: 'background 0.1s',
  },
  accent: {
    width: 3,
    borderRadius: 1.5,
    flexShrink: 0,
    alignSelf: 'stretch',
  },
  cardContent: {
    flex: 1,
    minWidth: 0,
  },
  cardTop: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 3,
  },
  badge: {
    display: 'flex',
    alignItems: 'center',
    gap: 4,
  },
  badgeText: {
    fontSize: 9,
    fontWeight: 700,
    fontFamily: 'var(--mono)',
    letterSpacing: '0.05em',
  },
  cardTime: {
    fontSize: 10,
    fontFamily: 'var(--mono)',
    color: 'var(--text-tertiary)',
  },
  cardName: {
    fontSize: 12,
    fontWeight: 700,
    color: 'var(--text-primary)',
    marginBottom: 2,
  },
  cardBody: {
    fontSize: 12,
    color: 'var(--text-primary)',
    lineHeight: 1.4,
    marginBottom: 4,
  },
  cardMeta: {
    display: 'flex',
    gap: 4,
    fontSize: 10,
    color: 'var(--text-tertiary)',
    fontFamily: 'var(--mono)',
  },
};
