import useWebSocket from './hooks/useWebSocket';
import StatsBar from './components/StatsBar';
import Map from './components/Map';
import ReportList from './components/ReportList';
import './App.css';

export default function App() {
  const { reports, connected } = useWebSocket();

  return (
    <div className="app">
      <StatsBar reports={reports} connected={connected} />
      <div className="app-body">
        <div className="app-map">
          <Map reports={reports} />
        </div>
        <div className="app-sidebar">
          <ReportList reports={reports} />
        </div>
      </div>
    </div>
  );
}
