import { useEffect, useState } from 'react';
import { ThemeProvider, useTheme } from './hooks/useTheme';
import useWebSocket from './hooks/useWebSocket';
import StatsBar from './components/StatsBar';
import Map from './components/Map';
import ReportList from './components/ReportList';
import DirectiveList from './components/DirectiveList';
import DirectivePanel from './components/DirectivePanel';
import Legend from './components/Legend';
import './App.css';

function Dashboard() {
  const { reports, directives, connected, refetchDirectives } = useWebSocket();
  const { theme } = useTheme();
  const [tab, setTab] = useState('reports'); // 'reports' | 'directives'

  useEffect(() => {
    document.body.setAttribute('data-theme', theme);
  }, [theme]);

  return (
    <div className="app">
      <div className="app-toolbar">
        <StatsBar reports={reports} directives={directives} connected={connected} />
      </div>
      <div className="app-body">
        <div className="app-map">
          <Map reports={reports} />
        </div>
        <div className="app-sidebar">
          {/* Tab bar */}
          <div style={s.tabBar}>
            <button
              style={{ ...s.tab, ...(tab === 'reports' ? s.tabActive : {}) }}
              onClick={() => setTab('reports')}
            >
              Incidents
              {reports.length > 0 && (
                <span style={s.tabBadge}>{reports.length}</span>
              )}
            </button>
            <button
              style={{ ...s.tab, ...(tab === 'directives' ? s.tabActive : {}) }}
              onClick={() => setTab('directives')}
            >
              Directives
              {directives.length > 0 && (
                <span style={{ ...s.tabBadge, background: 'var(--tint)' }}>{directives.length}</span>
              )}
            </button>
          </div>

          {/* Tab content */}
          <div style={s.tabContent}>
            {tab === 'reports' ? (
              <ReportList reports={reports} />
            ) : (
              <DirectiveList directives={directives} />
            )}
          </div>

          {/* Directive panel always visible at bottom when on directives tab */}
          {tab === 'directives' && (
            <DirectivePanel onSent={refetchDirectives} />
          )}

          {tab === 'reports' && <Legend />}
        </div>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <Dashboard />
    </ThemeProvider>
  );
}

const s = {
  tabBar: {
    display: 'flex',
    padding: '8px 8px 0',
    gap: 2,
    flexShrink: 0,
  },
  tab: {
    flex: 1,
    padding: '8px 12px',
    fontSize: 11,
    fontWeight: 600,
    fontFamily: 'var(--system-font)',
    textTransform: 'uppercase',
    letterSpacing: '0.03em',
    color: 'var(--text-tertiary)',
    background: 'transparent',
    border: 'none',
    borderBottom: '2px solid transparent',
    cursor: 'pointer',
    transition: 'all 0.15s',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    borderRadius: '6px 6px 0 0',
    outline: 'none',
  },
  tabActive: {
    color: 'var(--text-primary)',
    borderBottomColor: 'var(--tint)',
    background: 'var(--chip-bg)',
  },
  tabBadge: {
    fontSize: 9,
    fontWeight: 700,
    fontFamily: 'var(--mono)',
    padding: '1px 5px',
    borderRadius: 8,
    background: 'var(--text-tertiary)',
    color: 'var(--bg-window)',
  },
  tabContent: {
    flex: 1,
    overflow: 'hidden',
  },
};
