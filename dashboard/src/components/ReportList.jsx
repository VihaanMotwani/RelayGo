import { useMemo } from 'react';
import ReportCard from './ReportCard';

function timeAgo(ts) {
  if (!ts) return '';
  const val = typeof ts === 'number' && ts < 1e12 ? ts * 1000 : ts;
  const d = new Date(val);
  if (isNaN(d.getTime())) return '';
  const diff = Math.floor((Date.now() - d) / 1000);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export default function ReportList({ reports, focusedReport, onReportClick }) {
  const sorted = [...reports].sort((a, b) => {
    const ta = new Date(a.timestamp || a.ts || 0).getTime();
    const tb = new Date(b.timestamp || b.ts || 0).getTime();
    return tb - ta;
  });

  const lastUpdated = useMemo(() => {
    if (sorted.length === 0) return null;
    const latest = sorted[0]?.timestamp || sorted[0]?.ts;
    return timeAgo(latest);
  }, [sorted]);

  return (
    <div style={s.container}>
      <div style={s.header}>
        <div style={s.headerTop}>
          <span style={s.headerLabel}>Incidents</span>
          <span style={s.headerCount}>{reports.length}</span>
        </div>
        {lastUpdated && (
          <span style={s.updated}>Updated {lastUpdated}</span>
        )}
      </div>

      <div style={s.list}>
        {sorted.length === 0 ? (
          <div style={s.empty}>
            <span style={s.emptyText}>No Incidents</span>
            <span style={s.emptyHint}>Reports from the mesh network will appear here.</span>
          </div>
        ) : (
          sorted.map((report, idx) => (
            <ReportCard
              key={report.id || idx}
              report={report}
              isFocused={focusedReport?.id === report.id}
              onClick={() => onReportClick(report)}
            />
          ))
        )}
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
    marginBottom: 2,
  },
  updated: {
    fontSize: 10,
    fontFamily: 'var(--mono)',
    color: 'var(--text-tertiary)',
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
    padding: '48px 20px',
    gap: 4,
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
  },
};
