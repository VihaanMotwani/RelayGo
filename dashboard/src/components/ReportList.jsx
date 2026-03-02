import ReportCard from './ReportCard';

const styles = {
  container: {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    overflow: 'hidden',
  },
  header: {
    padding: '20px 20px 14px',
    borderBottom: '1px solid rgba(255,255,255,0.06)',
    flexShrink: 0,
  },
  title: {
    fontSize: 15,
    fontWeight: 700,
    color: 'rgba(255,255,255,0.9)',
    margin: 0,
  },
  subtitle: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.35)',
    marginTop: 4,
  },
  list: {
    flex: 1,
    overflowY: 'auto',
    padding: '12px 16px',
  },
  empty: {
    textAlign: 'center',
    color: 'rgba(255,255,255,0.3)',
    fontSize: 13,
    padding: '40px 20px',
  },
};

export default function ReportList({ reports }) {
  const sorted = [...reports].sort((a, b) => {
    const ta = new Date(a.timestamp || 0).getTime();
    const tb = new Date(b.timestamp || 0).getTime();
    return tb - ta;
  });

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h2 style={styles.title}>Live Reports</h2>
        <div style={styles.subtitle}>
          {reports.length} report{reports.length !== 1 ? 's' : ''} received
        </div>
      </div>
      <div style={styles.list} className="report-list-scroll">
        {sorted.length === 0 ? (
          <div style={styles.empty}>
            Waiting for incoming reports...
          </div>
        ) : (
          sorted.map((report, idx) => (
            <ReportCard key={report.id || idx} report={report} />
          ))
        )}
      </div>
    </div>
  );
}
