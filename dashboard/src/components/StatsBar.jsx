import { TYPE_COLORS, TYPE_LABELS } from '../utils/mapStyles';
import { useTheme } from '../hooks/useTheme';

export default function StatsBar({ reports, directives = [], connected, enableBuildingHover, setEnableBuildingHover, showRelayPaths, setShowRelayPaths }) {
  const { theme, toggle } = useTheme();

  const typeCounts = {};
  let totalHops = 0;
  let hopsCount = 0;

  reports.forEach((r) => {
    const t = r.type?.toLowerCase() || 'other';
    typeCounts[t] = (typeCounts[t] || 0) + 1;
    const h = r.hop_count ?? r.hops;
    if (h != null) { totalHops += h; hopsCount++; }
  });

  const avgHops = hopsCount > 0 ? (totalHops / hopsCount).toFixed(1) : '0.0';

  return (
    <div style={s.toolbar}>
      {/* Brand */}
      <span style={s.title}>RelayGo</span>

      {/* <div style={s.center}>
        <ToolbarItem value={reports.length} label="Incidents" />
        <ToolbarSep />
        <ToolbarItem value={avgHops} label="Avg Hops" />
        <ToolbarSep />
        <ToolbarItem value={Object.keys(typeCounts).length} label="Types" />
      </div> */}

      <div style={s.right}>
        {Object.entries(typeCounts).map(([type, count]) => {
          const color = TYPE_COLORS[type] || TYPE_COLORS.other;
          return (
            <div key={type} style={s.typeChip}>
              <div style={{ ...s.chipDot, background: color }} />
              <span style={s.chipText}>{TYPE_LABELS[type] || type}</span>
              <span style={s.chipCount}>{count}</span>
            </div>
          );
        })}

        {directives.length > 0 && (
          <div style={s.typeChip}>
            <svg width="8" height="8" viewBox="0 0 24 24" fill="currentColor" style={{ color: 'var(--tint)' }}>
              <path d="M22 2L11 13M22 2L15 22L11 13L2 9L22 2Z" />
            </svg>
            <span style={s.chipText}>Directives</span>
            <span style={s.chipCount}>{directives.length}</span>
          </div>
        )}

        <div style={s.statusPill}>
          <div style={{
            ...s.statusDot,
            background: connected ? 'var(--green)' : 'var(--red)',
          }} />
          <span style={{
            ...s.statusText,
            color: connected ? 'var(--text-secondary)' : 'var(--red)',
          }}>
            {connected ? 'Connected' : 'Offline'}
          </span>
        </div>

        <ToolbarSep />

        {/* Hop Path toggle */}
        <button
          onClick={() => setShowRelayPaths(prev => !prev)}
          style={{
            ...s.themeToggle,
            color: showRelayPaths ? 'var(--tint)' : 'var(--text-secondary)',
            background: showRelayPaths ? 'var(--tint-dim)' : 'var(--chip-bg)',
            borderColor: showRelayPaths ? 'transparent' : 'var(--separator)',
          }}
          title={showRelayPaths ? 'Hide Relay Paths' : 'Show Relay Paths'}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 12c3-4 5-8 9-8s6 4 9 8" />
            <circle cx="3" cy="12" r="2" />
            <circle cx="12" cy="4" r="2" />
            <circle cx="21" cy="12" r="2" />
          </svg>
        </button>

        {/* Building Hover toggle */}
        <button
          onClick={() => setEnableBuildingHover(prev => !prev)}
          style={{
            ...s.themeToggle,
            color: enableBuildingHover ? 'var(--tint)' : 'var(--text-secondary)',
            background: enableBuildingHover ? 'var(--tint-dim)' : 'var(--chip-bg)',
            borderColor: enableBuildingHover ? 'transparent' : 'var(--separator)',
          }}
          title={enableBuildingHover ? 'Disable 3D Building Insights' : 'Enable 3D Building Insights'}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill={enableBuildingHover ? "currentColor" : "none"} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 21h18" />
            <path d="M9 8h1" />
            <path d="M9 12h1" />
            <path d="M9 16h1" />
            <path d="M14 8h1" />
            <path d="M14 12h1" />
            <path d="M14 16h1" />
            <path d="M5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16" />
          </svg>
        </button>

        {/* Theme toggle */}
        <button onClick={toggle} style={s.themeToggle} title={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}>
          {theme === 'light' ? (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
            </svg>
          ) : (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="5" />
              <line x1="12" y1="1" x2="12" y2="3" />
              <line x1="12" y1="21" x2="12" y2="23" />
              <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
              <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
              <line x1="1" y1="12" x2="3" y2="12" />
              <line x1="21" y1="12" x2="23" y2="12" />
              <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
              <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
            </svg>
          )}
        </button>
      </div>
    </div >
  );
}

function ToolbarItem({ value, label }) {
  return (
    <div style={s.toolbarItem}>
      <span style={s.toolbarValue}>{value}</span>
      <span style={s.toolbarLabel}>{label}</span>
    </div>
  );
}

function ToolbarSep() {
  return <div style={s.toolbarSep} />;
}

const s = {
  toolbar: {
    display: 'flex',
    alignItems: 'center',
    height: 52,
    padding: '0 16px',
    background: 'var(--bg-sidebar)',
    backdropFilter: 'blur(30px) saturate(1.8)',
    WebkitBackdropFilter: 'blur(30px) saturate(1.8)',
    borderBottom: '0.5px solid var(--separator)',
    flexShrink: 0,
    gap: 12,
    transition: 'background 0.25s',
  },
  trafficLights: {
    display: 'flex',
    gap: 8,
    alignItems: 'center',
    paddingRight: 8,
  },
  trafficDot: {
    width: 12,
    height: 12,
    borderRadius: '50%',
    boxShadow: 'inset 0 0 0 0.5px rgba(0,0,0,0.15)',
  },
  titleArea: {
    paddingRight: 16,
  },
  title: {
    fontSize: 15,
    fontWeight: 600,
    color: 'var(--text-primary)',
    letterSpacing: '-0.03em',
  },
  center: {
    display: 'flex',
    alignItems: 'center',
    gap: 0,
    flex: 1,
  },
  toolbarItem: {
    display: 'flex',
    alignItems: 'baseline',
    gap: 4,
    padding: '0 10px',
  },
  toolbarValue: {
    fontSize: 13,
    fontWeight: 600,
    fontFamily: 'var(--mono)',
    color: 'var(--text-primary)',
  },
  toolbarLabel: {
    fontSize: 11,
    color: 'var(--text-tertiary)',
    fontWeight: 400,
  },
  toolbarSep: {
    width: 0.5,
    height: 16,
    background: 'var(--separator)',
  },
  right: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    marginLeft: 'auto',
  },
  typeChip: {
    display: 'flex',
    alignItems: 'center',
    gap: 4,
    padding: '3px 8px',
    borderRadius: 5,
    background: 'var(--chip-bg)',
    border: '0.5px solid var(--chip-border)',
    fontSize: 11,
  },
  chipDot: {
    width: 6,
    height: 6,
    borderRadius: '50%',
  },
  chipText: {
    color: 'var(--text-secondary)',
    fontWeight: 500,
  },
  chipCount: {
    color: 'var(--text-tertiary)',
    fontFamily: 'var(--mono)',
    fontSize: 10,
    fontWeight: 500,
  },
  statusPill: {
    display: 'flex',
    alignItems: 'center',
    gap: 5,
    padding: '3px 8px',
    borderRadius: 5,
  },
  statusDot: {
    width: 6,
    height: 6,
    borderRadius: '50%',
  },
  statusText: {
    fontSize: 11,
    fontWeight: 500,
  },
  themeToggle: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: 28,
    height: 28,
    borderRadius: 6,
    border: '0.5px solid var(--separator)',
    background: 'var(--chip-bg)',
    color: 'var(--text-secondary)',
    cursor: 'pointer',
    transition: 'all 0.15s',
    padding: 0,
    outline: 'none',
    WebkitAppRegion: 'no-drag',
  },
};
