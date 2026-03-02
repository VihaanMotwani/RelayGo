import { useEffect } from 'react';
import { ThemeProvider, useTheme } from './hooks/useTheme';
import useWebSocket from './hooks/useWebSocket';
import StatsBar from './components/StatsBar';
import Map from './components/Map';
import ReportList from './components/ReportList';
import Legend from './components/Legend';
import './App.css';

function Dashboard() {
  const { reports, connected } = useWebSocket();
  const { theme } = useTheme();

  useEffect(() => {
    document.body.setAttribute('data-theme', theme);
  }, [theme]);

  return (
    <div className="app">
      <div className="app-toolbar">
        <StatsBar reports={reports} connected={connected} />
      </div>
      <div className="app-body">
        <div className="app-map">
          <Map reports={reports} />
        </div>
        <div className="app-sidebar">
          <ReportList reports={reports} />
          <Legend />
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
