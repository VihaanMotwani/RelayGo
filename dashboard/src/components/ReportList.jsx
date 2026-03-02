import ReportCard from './ReportCard';

export default function ReportList({ reports }) {
  const sorted = [...reports].sort((a, b) => {
    const ta = new Date(a.timestamp || a.ts || 0).getTime();
    const tb = new Date(b.timestamp || b.ts || 0).getTime();
    return tb - ta;
  });

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <div style={styles.titleRow}>
          <div style={styles.titleLeft}>
            <span style={styles.titleIcon}>◉</span>
            <h2 style={styles.title}>LIVE FEED</h2>
          </div>
          <span style={styles.count}>{reports.length}</span>
        </div>
        <div style={styles.scanLine} />
      </div>
      <div style={styles.list} className="report-list-scroll">
        {sorted.length === 0 ? (
          <div style={styles.empty}>
            <div style={styles.emptyIcon}>◇</div>
            <div style={styles.emptyText}>Awaiting incoming signals...</div>
            <div style={styles.emptyHint}>Reports from the mesh network will appear here</div>
          </div>
        ) : (
          sorted.map((report, idx) => (
            <ReportCard
              key={report.id || idx}
              report={report}
              style={{ animationDelay: `${idx * 60}ms` }}
            />
          ))
        )}
      </div>
    </div>
  );
}

const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    overflow: 'hidden',
  },
  header: {
    padding: '16px 18px 0',
    flexShrink: 0,
  },
  titleRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  titleLeft: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
  },
  titleIcon: {
    color: 'var(--amber)',
    fontSize: 10,
  },
  title: {
    fontSize: 11,
    fontWeight: 700,
    fontFamily: 'var(--font-mono)',
    color: 'rgba(255,255,255,0.5)',
    letterSpacing: '0.12em',
    margin: 0,
  },
  count: {
    fontFamily: 'var(--font-mono)',
    fontSize: 12,
    fontWeight: 700,
    color: 'var(--amber)',
    background: 'var(--amber-glow)',
    padding: '2px 8px',
    borderRadius: 4,
  },
  scanLine: {
    height: 1,
    background: 'linear-gradient(90deg, transparent, var(--amber-dim), transparent)',
    opacity: 0.2,
  },
  list: {
    flex: 1,
    overflowY: 'auto',
    padding: '10px 14px',
  },
  empty: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '48px 24px',
    gap: 8,
  },
  emptyIcon: {
    fontSize: 28,
    color: 'var(--amber-dim)',
    opacity: 0.3,
    marginBottom: 4,
  },
  emptyText: {
    fontFamily: 'var(--font-mono)',
    fontSize: 12,
    color: 'rgba(255,255,255,0.3)',
    letterSpacing: '0.04em',
  },
  emptyHint: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.15)',
  },
};
